AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "PG-7V Rocket"
ENT.Spawnable   = false
ENT.Model       = "models/weapons/w_missile_launch.mdl"

ENT.Damage      = 380
ENT.Radius      = 340       -- ~6.5 m
ENT.ArmDistance = 262       -- 5 m
ENT.DudDamage   = 90
ENT.LaunchSpeed = 2400      -- ~46 m/s out of the tube
ENT.MaxSpeed    = 5800      -- ~110 m/s with the sustainer
ENT.Accel       = 9000      -- units/s^2 while the sustainer burns
ENT.IgniteTime  = 0.08
ENT.Gravity     = 320
ENT.LifeTime    = 4.5

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "IgniteAt")
end

if CLIENT then
    local matGlow = Material("sprites/light_glow02_add")
    function ENT:Initialize()
        self.Emitter = ParticleEmitter(self:GetPos())
        self.NextPuff = 0
    end
    function ENT:Draw()
        self:DrawModel()
        if CurTime() >= self:GetIgniteAt() then
            local back = self:GetPos() - self:GetForward() * 14
            render.SetMaterial(matGlow)
            render.DrawSprite(back, 48, 48, Color(255, 200, 120, 255))
        end
    end
    function ENT:Think()
        local ct = CurTime()
        if ct >= self:GetIgniteAt() then
            local dl = DynamicLight(self:EntIndex())
            if dl then
                dl.pos = self:GetPos() - self:GetForward() * 16
                dl.r, dl.g, dl.b = 255, 170, 80
                dl.brightness = 3 dl.decay = 1000 dl.size = 220 dl.dietime = ct + 0.1
            end
            if self.Emitter and ct >= self.NextPuff then
                self.NextPuff = ct + 0.012
                local p = self.Emitter:Add("particle/smokesprites_000" .. math.random(1, 9), self:GetPos() - self:GetForward() * 18)
                if p then
                    p:SetVelocity(VectorRand() * 18 - self:GetForward() * 40)
                    p:SetDieTime(math.Rand(1.6, 2.6))
                    p:SetStartAlpha(110) p:SetEndAlpha(0)
                    p:SetStartSize(math.Rand(6, 9)) p:SetEndSize(math.Rand(34, 48))
                    p:SetRoll(math.Rand(0, 360)) p:SetRollDelta(math.Rand(-1, 1))
                    local c = math.random(150, 185)
                    p:SetColor(c, c, c)
                    p:SetAirResistance(60)
                end
            end
        end
        self:SetNextClientThink(ct)
        return true
    end
    function ENT:OnRemove()
        if self.Emitter then self.Emitter:Finish() self.Emitter = nil end
    end
    return
end

function ENT:Initialize()
    self:SetModel(self.Model)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self:DrawShadow(false)
    self.Vel = self.Vel or self:GetForward() * self.LaunchSpeed
    self.StartPos = self.StartPos or self:GetPos()
    self.LastThink = CurTime()
    self.DieTime = CurTime() + self.LifeTime
    self:SetIgniteAt(CurTime() + self.IgniteTime)
    self.Loop = CreateSound(self, "weapons/rpg/rocket1.wav")
    if self.Loop then self.Loop:PlayEx(1, 100) end
    self:NextThink(CurTime())
end

function ENT:Launch(dir, inheritVel)
    self.Vel = dir:GetNormalized() * self.LaunchSpeed + (inheritVel or vector_origin)
    self:SetAngles(self.Vel:Angle())
end

function ENT:Think()
    local ct = CurTime()
    local dt = math.Clamp(ct - (self.LastThink or ct), 0, 0.1)
    self.LastThink = ct
    if dt > 0 and not self.Done then
        local v = self.Vel
        if ct >= self:GetIgniteAt() then
            local speed = v:Length()
            if speed < self.MaxSpeed then
                v = v + v:GetNormalized() * math.min(self.Accel * dt, self.MaxSpeed - speed)
            end
        end
        v = v - Vector(0, 0, self.Gravity * dt)
        self.Vel = v
        local from = self:GetPos()
        local to = from + v * dt
        local tr = util.TraceLine({ start = from, endpos = to, filter = { self, self:GetOwner() }, mask = MASK_SHOT })
        if tr.Hit then
            self:SetPos(tr.HitPos)
            self:Impact(tr)
        else
            self:SetPos(to)
            self:SetAngles(v:Angle())
        end
    end
    if not self.Done and ct >= self.DieTime then self:Explode(self:GetPos(), vector_up) end
    self:NextThink(ct)
    return true
end

function ENT:Impact(tr)
    if tr.HitSky then self.Done = true self:Remove() return end
    local travelled = tr.HitPos:Distance(self.StartPos or tr.HitPos)
    if travelled >= self.ArmDistance then
        self:Explode(tr.HitPos, tr.HitNormal, tr.Entity)
        return
    end
    self.Done = true
    local ent = tr.Entity
    if IsValid(ent) then
        local dmg = DamageInfo()
        dmg:SetDamage(self.DudDamage)
        dmg:SetDamageType(DMG_CLUB)
        dmg:SetAttacker(IsValid(self.Attacker) and self.Attacker or self)
        dmg:SetInflictor(self)
        dmg:SetDamagePosition(tr.HitPos)
        dmg:SetDamageForce(self.Vel * 4)
        ent:TakeDamageInfo(dmg)
    end
    self:EmitSound("physics/metal/metal_solid_impact_hard" .. math.random(1, 5) .. ".wav", 80, 90)
    local ed = EffectData() ed:SetOrigin(tr.HitPos) ed:SetNormal(tr.HitNormal)
    util.Effect("ManhackSparks", ed, true, true)
    self:Remove()
end

function ENT:Explode(pos, normal, hitEnt)
    if self.Done then return end
    self.Done = true
    normal = normal or vector_up
    local attacker = IsValid(self.Attacker) and self.Attacker or self
    local ed = EffectData()
    ed:SetOrigin(pos) ed:SetNormal(normal)
    ed:SetMagnitude(1) ed:SetScale(1) ed:SetRadius(self.Radius)
    util.Effect("Explosion", ed, true, true)
    util.Decal("Scorch", pos + normal * 4, pos - normal * 8, self)
    if IsValid(hitEnt) then
        local dmg = DamageInfo()
        dmg:SetDamage(self.Damage * 0.6)
        dmg:SetDamageType(DMG_BLAST)
        dmg:SetAttacker(attacker) dmg:SetInflictor(self)
        dmg:SetDamagePosition(pos) dmg:SetDamageForce(self.Vel * 20)
        hitEnt:TakeDamageInfo(dmg)
    end
    util.BlastDamage(self, attacker, pos + normal * 4, self.Radius, self.Damage)
    util.ScreenShake(pos, 10, 160, 1.0, self.Radius * 3)
    self:Remove()
end

function ENT:OnRemove()
    if self.Loop then self.Loop:Stop() end
end
