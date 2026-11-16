AddCSLuaFile()
DEFINE_BASECLASS("weapon_sand_base")

SWEP.Base           = "weapon_sand_base"
SWEP.PrintName      = "Sandstorm Launcher Base"
SWEP.Category       = "Sandstorm SWEPs"
SWEP.SubCategory    = "Launchers"
SWEP.Spawnable      = false

SWEP.WorldModel     = "models/weapons/w_rocket_launcher.mdl"
SWEP.UseHands       = true
SWEP.ViewModelFOV   = 75
SWEP.HoldType       = "rpg"
SWEP.Slot           = 4

SWEP.Primary.ClipSize       = 1
SWEP.Primary.DefaultClip    = 1
SWEP.Primary.Ammo           = "RPG_Round"
SWEP.Primary.Damage         = 0
SWEP.Primary.NumShots       = 1
SWEP.Primary.Spread         = 0.006
SWEP.Primary.RPM            = 60
SWEP.Primary.Recoil         = 3
SWEP.Primary.DryFireSound   = "SandSwep.Dry.Launcher"

SWEP.ChamberRound           = false
SWEP.ShellModel             = ""
SWEP.FireModes              = { "safe", "semi" }
SWEP.DefaultFireMode        = "semi"
SWEP.AimTime                = 0.5
SWEP.AimMoveSpeed           = 0.6
SWEP.ReloadSpeed            = 1

SWEP.Rocket = {
    Damage = 400,
    Radius = 350,
    ArmDistance = 262,
    DudDamage = 90,
    LaunchSpeed = 2400,
    MaxSpeed = 5800,
    Gravity = 320,
    BackBlast = { Range = 160, Damage = 45 },
}

SWEP.RoundBodygroup = nil
SWEP.TubeModel      = nil
SWEP.TubeLifetime   = 30
SWEP.Disposable     = false
SWEP.TossDelay      = 1.4
SWEP.ReloadCasing   = nil

function SWEP:IsBoltLocked()
    return self:Clip1() <= 0
end

function SWEP:FireShot()
    if self:Clip1() > 0 and not self:IsChambered() then
        if not self:IsReloading() and not self:IsActionBusy() then self:ResumeStagedReload() end
        return
    end

    return BaseClass.FireShot(self)
end

function SWEP:ShootBullet()
    local owner = self:GetOwner()
    self:ShootEffects()
    if self.Disposable then self._tossAt = CurTime() + self.TossDelay end

    if not SERVER or not IsValid(owner) then return end
    if self.Grenade then return self:ShootGrenade(owner) end

    local cfg = self.Rocket
    local shootPos = self:GetBulletSource()
    local aim = self:GetAimDirection()
    local spread = self:GetCurrentSpread()

    if spread > 0 then
        local ang = aim:Angle()
        aim = (aim + ang:Right() * util.SharedRandom("sandswep_rocket_x", -spread, spread)
            + ang:Up() * util.SharedRandom("sandswep_rocket_y", -spread, spread)):GetNormalized()
    end

    local target = util.TraceLine({
        start = shootPos,
        endpos = shootPos + aim * 16384,
        filter = owner,
        mask = MASK_SHOT,
    }).HitPos

    local eyeAng = owner:EyeAngles()
    local launchPos = shootPos + aim * 30 + eyeAng:Right() * 3 - eyeAng:Up() * 2
    local tr = util.TraceLine({
        start = shootPos,
        endpos = launchPos,
        filter = owner,
        mask = MASK_SHOT,
    })
    local start = tr.Hit and (tr.HitPos - aim * 2) or launchPos

    local dir = (target - start):GetNormalized()
    if dir:Dot(aim) < 0.95 then dir = aim end

    local rocket = ents.Create("sandswep_rpg7_rocket")
    if IsValid(rocket) then
        if cfg.Model then rocket.Model = cfg.Model end
        rocket:SetPos(start)
        rocket:SetAngles(dir:Angle())
        rocket:SetOwner(owner)

        rocket.Attacker = owner
        rocket.Damage, rocket.Radius = cfg.Damage, cfg.Radius
        rocket.ArmDistance, rocket.DudDamage = cfg.ArmDistance, cfg.DudDamage
        rocket.LaunchSpeed, rocket.MaxSpeed = cfg.LaunchSpeed, cfg.MaxSpeed
        rocket.Gravity = cfg.Gravity or rocket.Gravity
        rocket.StartPos = shootPos

        rocket:Launch(dir, owner:GetVelocity() * 0.3)
        rocket:Spawn()
    end

    self:BackBlast(shootPos, aim)
end

function SWEP:ShootGrenade(owner)
    local cfg = self.Grenade
    local dir = self:GetAimDirection()
    local spread = self:GetCurrentSpread()

    if spread > 0 then
        local ang = dir:Angle()
        dir = (dir + ang:Right() * util.SharedRandom("sandswep_gl_x", -spread, spread)
            + ang:Up() * util.SharedRandom("sandswep_gl_y", -spread, spread)):GetNormalized()
    end

    local start = owner:GetShootPos()
    local launchPos = start + dir * 18 - owner:EyeAngles():Up() * 3 + owner:EyeAngles():Right() * 2
    local tr = util.TraceLine({
        start = start,
        endpos = launchPos,
        filter = owner,
        mask = MASK_SHOT,
    })

    local nade = ents.Create("sandswep_40mm")
    if not IsValid(nade) then return end

    nade:SetPos(tr.Hit and (tr.HitPos - dir * 2) or launchPos)
    nade:SetAngles(dir:Angle())
    nade:SetOwner(owner)

    nade.Attacker = owner
    nade.Damage, nade.Radius = cfg.Damage, cfg.Radius
    nade.ArmDistance, nade.DudDamage = cfg.ArmDistance, cfg.DudDamage

    nade:Spawn()
    nade.StartPos = start
    nade:Launch(dir * cfg.Velocity + owner:GetVelocity() * 0.5)
end

function SWEP:BackBlast(shootPos, aim)
    local owner = self:GetOwner()
    local blast = self.Rocket.BackBlast
    local rear = shootPos - aim * 30

    local fx = EffectData()
    fx:SetOrigin(rear)
    fx:SetNormal(-aim)
    fx:SetScale(2)
    fx:SetMagnitude(2)
    fx:SetRadius(40)
    util.Effect("ThumperDust", fx, true, true)

    if not blast or blast.Range <= 0 then return end

    for _, ent in ipairs(ents.FindInSphere(rear - aim * blast.Range * 0.5, blast.Range * 0.6)) do
        local isTarget = ent ~= owner and (ent:IsPlayer() or ent:IsNPC())
        local behind = isTarget and (ent:WorldSpaceCenter() - shootPos):GetNormalized():Dot(-aim) > 0.6
        local blocked = behind and util.TraceLine({
            start = shootPos,
            endpos = ent:WorldSpaceCenter(),
            filter = { owner, self, ent },
            mask = MASK_SOLID,
        }).Hit

        if behind and not blocked then
            local dmg = DamageInfo()
            dmg:SetDamage(blast.Damage)
            dmg:SetDamageType(DMG_BURN)
            dmg:SetAttacker(owner)
            dmg:SetInflictor(self)
            dmg:SetDamageForce(-aim * 3000)
            ent:TakeDamageInfo(dmg)
        end
    end
end

function SWEP:IsRoundShown()
    local roundBg = self.RoundBodygroup
    if not roundBg then return true end
    if roundBg.OnlyReloading then return self:IsReloading() end
    if self:Clip1() > 0 then return true end

    if self:IsReloading() then
        local entry = self:GetCurrentReloadEntry()
        return istable(entry) and entry.InsertAt ~= nil and self:GetReloadAnimTime() >= entry.InsertAt
    end

    return false
end

function SWEP:GetDesiredBodygroups()
    local bodygroups = BaseClass.GetDesiredBodygroups(self)
    local roundBg = self.RoundBodygroup
    if roundBg then bodygroups[roundBg.Name] = self:IsRoundShown() and 0 or 1 end

    return bodygroups
end

function SWEP:GetVMBodygroupList(vm)
    local shown = self:IsRoundShown()
    if self._roundShown ~= shown then
        self._roundShown = shown
        self._bgList = nil
    end

    return BaseClass.GetVMBodygroupList(self, vm)
end

function SWEP:ThrowTube()
    if not SERVER or not self.TubeModel then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local eyeAng = owner:EyeAngles()
    local fwd, right = Angle(0, eyeAng.y, 0):Forward(), Angle(0, eyeAng.y, 0):Right()
    local pos = owner:EyePos() + right * 14 - Vector(0, 0, 18) + fwd * 6

    local tr = util.TraceLine({
        start = owner:EyePos(),
        endpos = pos,
        filter = owner,
        mask = MASK_SOLID,
    })
    if tr.Hit then pos = tr.HitPos + tr.HitNormal * 6 end

    local prop = ents.Create("prop_physics")
    if not IsValid(prop) then return end

    prop:SetModel(self.TubeModel)
    prop:SetPos(pos)
    prop:SetAngles(Angle(math.Rand(-15, 15), eyeAng.y + 90 + math.Rand(-20, 20), math.Rand(-20, 20)))
    prop:Spawn()
    prop:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

    local phys = prop:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(owner:GetVelocity() + right * 110 + fwd * 30 + Vector(0, 0, 40))
        phys:AddAngleVelocity(VectorRand() * 180)
    end

    SafeRemoveEntityDelayed(prop, self.TubeLifetime)
end

function SWEP:IsResumedReload()
    return self:GetReloadState() == SandSwep.BaseShared.RELOAD_RESUME
end

function SWEP:UpdateTubeToss()
    if not self.TubeModel then return end

    local key
    if self:IsReloading() then
        local entry = self:GetCurrentReloadEntry()
        local magOut = istable(entry) and entry.MagOut
            and not self:IsResumedReload()
            and self:GetReloadAnimTime() >= entry.MagOut

        if magOut then
            key = self:GetActionStart()
        end
    elseif self._lastTossAt and CurTime() >= self._lastTossAt then
        key = self._lastTossAt
    end

    if key and self._tubeKey ~= key then
        self._tubeKey = key
        self:ThrowTube()
    end
end

function SWEP:DropReloadCasing()
    local casing = self.ReloadCasing
    local owner = self:GetOwner()
    if not SERVER or not casing or not IsValid(owner) then return end

    local eyeAng = owner:EyeAngles()
    local fwd, right = Angle(0, eyeAng.y, 0):Forward(), Angle(0, eyeAng.y, 0):Right()
    local pos = owner:EyePos() - fwd * 14 + right * 8 - Vector(0, 0, 10)

    local tr = util.TraceLine({
        start = owner:EyePos(),
        endpos = pos,
        filter = owner,
        mask = MASK_SOLID,
    })
    if tr.Hit then pos = tr.HitPos + tr.HitNormal * 4 end

    local prop = ents.Create("prop_physics")
    if not IsValid(prop) then return end

    prop:SetModel(casing.Model)
    prop:SetPos(pos)
    prop:SetAngles(Angle(math.Rand(-20, 20), eyeAng.y + 90 + math.Rand(-30, 30), math.Rand(-20, 20)))
    prop:Spawn()
    prop:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

    local phys = prop:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(owner:GetVelocity() - fwd * 50 + right * 40 - Vector(0, 0, 20))
        phys:AddAngleVelocity(VectorRand() * 120)
    end

    if casing.Sound then prop:EmitSound(casing.Sound, 65) end
    SafeRemoveEntityDelayed(prop, casing.Lifetime or 30)
end

function SWEP:UpdateReloadCasing()
    local casing = self.ReloadCasing
    if not casing or not self:IsReloading() or self:IsResumedReload() then return end
    if self:GetReloadAnimTime() < casing.Time then return end

    local key = self:GetActionStart()
    if self._casingKey ~= key then
        self._casingKey = key
        self:DropReloadCasing()
    end
end

function SWEP:UpdateDisposable()
    if not self.Disposable or not self._tossAt or CurTime() < self._tossAt then return end
    if self:Clip1() > 0 or self:IsReloading() or self:GetSprinting() or self:IsHolstering() then return end

    self._tossAt = nil

    if #self:GetMags() > 0 then
        self:StartReload()
        return
    end

    local len = self:GetAnimLength("toss")
    if len and len > 0 and self:PlayAnim("toss") then
        local entry = self:GetAnimEntry("toss")
        self._lastTossAt = CurTime() + ((istable(entry) and entry.MagOut) or len)
        self:BeginAction("ready", len)
        self:SetNextPrimaryFire(CurTime() + len)
        self._stripAt = CurTime() + len
    else
        self._stripAt = CurTime()
    end
end

function SWEP:Think()
    self:UpdateDisposable()
    self:UpdateTubeToss()
    self:UpdateReloadCasing()

    if SERVER and self._stripAt and CurTime() >= self._stripAt then
        self._stripAt = nil
        local owner = self:GetOwner()
        if IsValid(owner) and owner:IsPlayer() and self:Clip1() <= 0 and #self:GetMags() == 0 then
            owner:StripWeapon(self:GetClass())
            return
        end
    end

    return BaseClass.Think(self)
end

function SWEP:Deploy()
    local result = BaseClass.Deploy(self)

    if self.Disposable and self:Clip1() <= 0 then
        self._tossAt = CurTime() + math.max(self:GetAnimLength("draw") or 0, self.DeployTime or 0.4)
    end

    return result
end
