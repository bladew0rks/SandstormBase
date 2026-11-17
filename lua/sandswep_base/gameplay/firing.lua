-- Firing

local SV_FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY)

local cvRecoilMult = CreateConVar("sv_sandswep_recoil_mult", "1", SV_FLAGS,
    "Recoil multiplier for all weapons", 0, 10)
local cvCrouchRecoil = CreateConVar("sv_sandswep_crouch_recoil", "0.75", SV_FLAGS,
    "Recoil multiplier while crouched (1 = no reduction)", 0, 1)
CreateConVar("sv_sandswep_freeaim", "1", SV_FLAGS,
    "Free aim: the gun moves inside an aim cone before the camera follows", 0, 1)
CreateConVar("sv_sandswep_freeaim_scale", "1", SV_FLAGS,
    "Free aim cone size", 0, 3)
local cvDamageMult = CreateConVar("sv_sandswep_damage_mult", "1", SV_FLAGS,
    "Bullet damage multiplier for all weapons", 0, 10)

local INCHES_PER_METER = 39.37

function SWEP:GetDamageMult()
    return cvDamageMult:GetFloat()
end

function SWEP:GetAmmoDef()
    local cache = self:AttCache()

    if cache.ammoDef == nil then
        cache.ammoDef = false
        for _, _, def in self:IterAttachments() do
            if def.AmmoType then cache.ammoDef = def end
        end
    end

    return cache.ammoDef or nil
end

function SWEP:GetPelletCount()
    local baseCount = self.Primary.NumShots or 1
    local ammo = self:GetAmmoDef()

    if not ammo then return baseCount end
    if ammo.Pellets then return ammo.Pellets end

    return math.max(1, math.Round(baseCount * (ammo.PelletMult or 1)))
end

local function AmmoHit(wep, ammo, attacker, tr, dmg)
    local falloff = ammo.Falloff
    if falloff then
        local dist = tr.HitPos:Distance(tr.StartPos)
        local range = math.max(falloff.End - falloff.Start, 1)
        local frac = math.Clamp((dist - falloff.Start) / range, 0, 1)
        dmg:ScaleDamage(Lerp(frac, 1, falloff.Min or 0))
    end

    if not SERVER then return end

    if ammo.ImpactParticle then ParticleEffect(ammo.ImpactParticle, tr.HitPos, tr.HitNormal:Angle()) end

    local ent = tr.Entity
    if ammo.Ignite and IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:GetClass() == "prop_physics") then
        ent:Ignite(ammo.Ignite)
    end

    local explosion = ammo.Explode
    if explosion then
        local pos = tr.HitPos + tr.HitNormal * 2

        if explosion.Particle then
            ParticleEffect(explosion.Particle, tr.HitPos, tr.HitNormal:Angle())
        else
            local fx = EffectData()
            fx:SetOrigin(pos)
            fx:SetNormal(tr.HitNormal)
            fx:SetMagnitude(explosion.Magnitude or 1)
            fx:SetScale(explosion.Scale or 1)
            fx:SetRadius(explosion.Radius)
            util.Effect(explosion.Effect or "HelicopterMegaBomb", fx, true, true)
        end

        local pitch = explosion.SoundPitch or { 110, 125 }
        sound.Play(explosion.Sound or "BaseExplosionEffect.Sound", pos, explosion.SoundLevel or 85, math.random(pitch[1], pitch[2]), explosion.SoundVolume or 0.7)

        local inflictor = IsValid(wep) and wep or attacker
        util.BlastDamage(inflictor, attacker, pos, explosion.Radius, explosion.Damage * wep:GetDamageMult())
        util.Decal("SmallScorch", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)
    end
end

function SWEP:GetCalibre()
    local ballistics = SandSwep.Ballistics
    if not ballistics then return nil end

    local ammo = self:GetAmmoDef()
    local name = ammo and ammo.Calibre or self.Calibre or ballistics.AmmoCalibres[self.Primary.Ammo] or "556x45"

    return ballistics.Calibres[name] or ballistics.Calibres["556x45"]
end

function SWEP:GetMuzzleVelocity()
    local def = self:GetCalibre()
    local ammo = self:GetAmmoDef()
    local speed = self.MuzzleVelocity or def.Velocity

    return speed * (ammo and ammo.VelocityMult or 1) * self:GetStatMult("Velocity")
end

function SWEP:UsesBallistics(numBullets)
    local ballistics = SandSwep.Ballistics
    if not ballistics or not ballistics.Enabled() then return false end
    if numBullets ~= 1 or self.Hitscan then return false end

    local ammo = self:GetAmmoDef()
    return not (ammo and ammo.Hitscan)
end

function SWEP:TryBreach(src, dir, force)
    if not SERVER or not SandSwep.BreachDoor or not SandSwep.ShotgunBreachEnabled() then return end
    if not force and self:GetPelletCount() <= 1 and not self.CanBreach then return end

    local owner = self:GetOwner()
    local tr = util.TraceLine({
        start = src,
        endpos = src + dir * SandSwep.BreachShotgunRange,
        filter = owner,
        mask = MASK_SHOT,
    })

    SandSwep.BreachDoor(tr.Entity, dir, 420, owner)
end

function SWEP:GetRecoilScale()
    local scale = cvRecoilMult:GetFloat()
    local owner = self:GetOwner()

    if IsValid(owner) and owner:IsPlayer() and owner:Crouching() then
        scale = scale * cvCrouchRecoil:GetFloat()
    end

    return scale
end

function SWEP:PrimaryAttack()
    if self:GetGLMode() then
        if self:IsGLReloading() or self:GetSprintProgress() > 0 then return end
        if self:GetTriggerHeld() then return end

        self:SetTriggerHeld(true)
        self:FireGL()
        return
    end

    if self:IsReloading() or self:IsSafe() then return end
    if self:GetSprintProgress() > 0 then return end

    if self.BoltAction and self:GetNeedsCycle() and self:Clip1() > 0 then
        self:SetTriggerHeld(true)
        return
    end

    if self:GetBurstLeft() > 0 then return end

    local mode = self:GetFireMode()
    if mode ~= "auto" and self:GetTriggerHeld() then return end
    self:SetTriggerHeld(true)

    if mode == "burst" and self:IsChambered() then
        self:SetBurstLeft(self.BurstCount)
    end

    self:FireShot()
end

function SWEP:FireShot()
    local owner = self:GetOwner()

    if not self:IsChambered() then
        self:SetBurstLeft(0)
        if self:GetDryClicked() then return end

        self:SetDryClicked(true)
        self:EmitSound(self.Primary.DryFireSound)

        local aimed = self:GetAimProgress() > 0.5
        self:PlayAnim(aimed and self:HasAnim("iron_dryfire") and "iron_dryfire" or "dryfire")
        self:SetNextPrimaryFire(CurTime() + 0.3)
        return
    end

    local delay = 60 / self:GetRPM()
    local burstLeft = self:GetBurstLeft()
    if burstLeft > 0 then
        burstLeft = burstLeft - 1
        self:SetBurstLeft(burstLeft)
        if burstLeft == 0 then delay = delay + self.BurstDelay end
    end

    self:SetNextPrimaryFire(CurTime() + delay)
    self:PlayFireSounds(self:Clip1() - 1)
    self:ArmBurstTail(60 / self:GetRPM())
    self:SetVMPlaybackRate(1)
    self:ShootBullet(self.Primary.Damage, self:GetPelletCount(), self:GetCurrentSpread(), self.Primary.Ammo)
    self:SetClip1(self:Clip1() - 1)

    if not self.BoltAction then self:EjectCasing() end

    if owner:IsPlayer() then
        self:ApplyRecoil(owner)
    end
end

function SWEP:ApplyRecoil(owner)
    local recoil = self.Primary.Recoil
        * Lerp(self:GetAimProgress(), 1, self.AimRecoilMult)
        * self:GetStatMult("Recoil")
        * self:GetRecoilScale()

    if self:GetBipodDeployed() then
        recoil = recoil * (self.Bipod.RecoilMult or 0.1)
    end

    local lateral = recoil * self:GetStatMult("RecoilLateral")
    owner:ViewPunch(Angle(-recoil, util.SharedRandom("sandswep_recoil", -lateral, lateral) * 0.5, 0))

    if (game.SinglePlayer() and SERVER) or (CLIENT and IsFirstTimePredicted()) then
        local ang = owner:EyeAngles()
        ang.p = ang.p - recoil * 0.5
        ang.y = ang.y + util.SharedRandom("sandswep_recoil_y", -lateral, lateral) * 0.25
        owner:SetEyeAngles(ang)
    end
end

function SWEP:GetAimDirection()
    local owner = self:GetOwner()

    if not IsValid(owner) then return self:GetForward() end
    if not owner:IsPlayer() then return owner:GetAimVector() end

    local ang = owner:EyeAngles() + owner:GetViewPunchAngles()
    return ang:Forward()
end

SWEP.BarrelZero = 100

local BARREL_MAX_DIST = 60
local BARREL_MIN_DOT = math.cos(math.rad(80))
local BARREL_STALE = 0.5

local cvBarrel = CreateConVar("sv_sandswep_barrelbullets", "1", SV_FLAGS,
    "Bullets from the barrel", 0, 1)

function SWEP:SetBarrelData(pos, dir, tilt)
    if pos:Length() > BARREL_MAX_DIST then
        pos = pos:GetNormalized() * BARREL_MAX_DIST
    end

    dir:Normalize()
    if dir.x < BARREL_MIN_DOT then
        dir = Vector(1, 0, 0)   -- nonsense / cheating: trust the aim
    end

    local barrel = self._barrel or {}
    self._barrel = barrel

    barrel.pos = pos
    barrel.dir = dir
    barrel.time = CurTime()
    barrel.tilt = math.Clamp(tilt or 0, 0, 90)
end

local barrelTrace = {}

function SWEP:GetBarrelShot()
    local owner = self:GetOwner()
    local shootPos = self:GetBulletSource()
    local aimDir = self:GetAimDirection()
    local barrel = self._barrel

    local usable = cvBarrel:GetBool()
        and IsValid(owner) and owner:IsPlayer()
        and barrel and CurTime() - barrel.time <= BARREL_STALE
        and not (CLIENT and owner:ShouldDrawLocalPlayer())

    if not usable then
        return shootPos, aimDir, shootPos, false
    end

    local aimAng = owner:EyeAngles() + owner:GetViewPunchAngles()
    local muzzle = LocalToWorld(barrel.pos, angle_zero, shootPos, aimAng)
    local barrelDir = LocalToWorld(barrel.dir, angle_zero, vector_origin, aimAng)
    barrelDir:Normalize()

    local zeroDist = (self.BarrelZero or 100) * INCHES_PER_METER
    local zeroDir = shootPos + aimDir * zeroDist - muzzle
    if self:UsesBallistics(self:GetPelletCount()) then
        local def = self:GetCalibre()
        local speed = self:GetMuzzleVelocity() * INCHES_PER_METER
        zeroDir.z = zeroDir.z + SandSwep.Ballistics.DropAt(def, SandSwep.Ballistics.TimeAtSpeed(def, speed), zeroDist)
    end
    zeroDir:Normalize()

    local blend = math.Clamp(self:GetAimProgress(), 0, 1)
    blend = blend * blend * (3 - 2 * blend)
    blend = blend * (1 - math.Clamp(barrel.tilt / 5, 0, 1))

    local dir = LerpVector(blend, barrelDir, zeroDir)
    dir:Normalize()

    local src = muzzle
    local tr = SandSwep.TraceLine(shootPos, muzzle, owner, MASK_SHOT, barrelTrace)
    if tr.Hit then
        src = tr.HitPos - (muzzle - shootPos):GetNormalized()
    end

    return src, dir, muzzle, true
end

if SERVER then
    util.AddNetworkString("sandswep_muzzle")

    net.Receive("sandswep_muzzle", function(_, ply)
        if not IsValid(ply) then return end

        local now = SysTime()
        if now - (ply._sandswepMuzzleT or 0) < 1 / 100 then return end
        ply._sandswepMuzzleT = now

        local pos, dir, tilt = net.ReadVector(), net.ReadNormal(), net.ReadUInt(7)

        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep.IsSandSwep and wep.SetBarrelData then
            wep:SetBarrelData(pos, dir, tilt)
        end
    end)
end

function SWEP:ShootBullet(damage, numBullets, aimcone, ammoType, force, tracer)
    local owner = self:GetOwner()
    local src, dir = self:GetBarrelShot()
    local ammo = self:GetAmmoDef()

    local bullet = {
        Num = numBullets,
        Src = src,
        Dir = dir,
        Spread = Vector(aimcone, aimcone, 0),
        Tracer = tracer or 5,
        Force = force or 1,
        Damage = damage * self:GetDamageMult() * self:GetStatMult("Damage"),
        AmmoType = ammoType or self.Primary.Ammo,
    }

    if ammo then
        if ammo.TracerName then bullet.TracerName = ammo.TracerName end
        if ammo.Tracer then bullet.Tracer = ammo.Tracer end
        if ammo.Force then bullet.Force = bullet.Force * ammo.Force end

        if ammo.Falloff or ammo.Ignite or ammo.Explode then
            local wep = self
            bullet.Callback = function(attacker, tr, dmg)
                AmmoHit(wep, ammo, attacker, tr, dmg)
            end
        end
    end

    hook.Run("SandSwep_PreFireBullets", self, bullet)

    if self:UsesBallistics(bullet.Num) then
        self:FireBallistic(owner, bullet, ammo)
    else
        owner:FireBullets(bullet)
    end
    self:TryBreach(src, dir)
    self:ShootEffects()
end

local spreadRight, spreadUp = Vector(), Vector()

function SWEP:FireBallistic(owner, bullet, ammo)
    local dir = Vector(bullet.Dir)
    local spread = bullet.Spread or vector_origin
    local seed = self:GetShotCount()

    if spread.x > 0 or spread.y > 0 then
        local ang = dir:Angle()
        spreadRight:Set(ang:Right())
        spreadUp:Set(ang:Up())

        local x = util.SharedRandom("SandSwepSpreadX1", -0.5, 0.5, seed) + util.SharedRandom("SandSwepSpreadX2", -0.5, 0.5, seed)
        local y = util.SharedRandom("SandSwepSpreadY1", -0.5, 0.5, seed) + util.SharedRandom("SandSwepSpreadY2", -0.5, 0.5, seed)

        dir:Add(spreadRight * (x * spread.x))
        dir:Add(spreadUp * (y * spread.y))
        dir:Normalize()
    end

    local every = bullet.Tracer or 5

    SandSwep.Ballistics.Fire(owner, self, bullet.Src, dir, bullet, {
        Def = self:GetCalibre(),
        Speed = self:GetMuzzleVelocity() * INCHES_PER_METER,
        PenMult = (ammo and ammo.PenMult or 1) * (self.PenetrationMult or 1),
        Seed = seed,
        Tracer = every > 0 and seed % every == 0,
    })
end

function SWEP:ShootEffects()
    local owner = self:GetOwner()
    local aimed = self:GetAimProgress() > 0.5
    local baseAnim = (aimed and self:HasAnim("iron_fire")) and "iron_fire" or "fire"
    local spare = self.Tubes and self:GetOtherTube() or 0
    local fed = self.BoltAction and self:GetFedShots() + 1 or 0
    local needsCycle = self.BoltAction and self:Clip1() + spare > 1 and fed >= self:GetShotsPerCycle()
    if self.BoltAction then self:SetFedShots((needsCycle or self:Clip1() + spare <= 1) and 0 or fed) end

    local anim = baseAnim
    if self:Clip1() + spare <= 1 and self:HasAnim(baseAnim .. "_last") then
        anim = baseAnim .. "_last"
    elseif needsCycle then
        anim = self:GetBoltAnim("fire")
    end

    self:PlayAnim(anim)
    if needsCycle then self:HoldBoltCycle(anim, CurTime()) end

    if IsValid(owner) then
        owner:SetAnimation(PLAYER_ATTACK1)
    end

    self:SetShotCount((self:GetShotCount() + 1) % 256)

    if SERVER and game.SinglePlayer() then
        self:CallOnClient("PlayMuzzleFX")
    elseif CLIENT and IsFirstTimePredicted() then
        self:PlayMuzzleFX()
    end
end

function SWEP:PlayMuzzleFX()
    if not CLIENT or not SandSwepFX then return end

    local owner = self:GetOwner()
    if not IsValid(owner) or owner ~= LocalPlayer() then return end

    SandSwepFX.WeaponShot(self, owner:ShouldDrawLocalPlayer())
    self._fovKickT = RealTime()
end

function SWEP:SecondaryAttack() end
