AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "40mm Grenade"
ENT.Spawnable   = false
ENT.Model       = "models/items/ar2_grenade.mdl"

ENT.Damage      = 150
ENT.Radius      = 312.5
ENT.ArmDistance = 262       -- 5 m (1 m = 52.49 units)
ENT.DudDamage   = 35
ENT.LifeTime    = 12

if CLIENT then
    function ENT:Draw() self:DrawModel() end
    return
end

function ENT:Initialize()
    self:SetModel(self.Model)
    self:PhysicsInitSphere(2, "metal")
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetMass(1)
        phys:EnableDrag(false)
        phys:SetBuoyancyRatio(0)
        phys:Wake()
    end
    self.StartPos = self:GetPos()
    self.DieTime = CurTime() + self.LifeTime
    util.SpriteTrail(self, 0, Color(200, 200, 200, 90), false, 3, 0, 0.35, 1 / 3 * 0.5, "trails/smoke")
end

function ENT:Launch(vel)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:SetVelocity(vel) end
end

function ENT:Think()
    if CurTime() > self.DieTime then self:Remove() end
    self:NextThink(CurTime() + 0.25)
    return true
end

function ENT:Explode(pos, normal)
    if self.Done then return end
    self.Done = true
    local attacker = IsValid(self.Attacker) and self.Attacker or self
    local ed = EffectData()
    ed:SetOrigin(pos)
    ed:SetNormal(normal or vector_up)
    ed:SetMagnitude(1) ed:SetScale(1) ed:SetRadius(self.Radius)
    util.Effect("Explosion", ed, true, true)
    util.Decal("Scorch", pos + (normal or vector_up) * 4, pos - (normal or vector_up) * 8, self)
    util.BlastDamage(self, attacker, pos + (normal or vector_up) * 2, self.Radius, self.Damage)
    util.ScreenShake(pos, 6, 140, 0.8, self.Radius * 2.5)
    self:Remove()
end

function ENT:PhysicsCollide(data, phys)
    if self.Done then return end
    local travelled = data.HitPos:Distance(self.StartPos or data.HitPos)
    if not self.Dud and travelled >= self.ArmDistance then
        local pos, normal = data.HitPos, -data.HitNormal
        timer.Simple(0, function() if IsValid(self) then self:Explode(pos, normal) end end)
        return
    end
    if not self.Dud then
        self.Dud = true
        local ent = data.HitEntity
        if IsValid(ent) and data.Speed > 200 then
            local pos, force = data.HitPos, data.OurOldVelocity * 2
            timer.Simple(0, function()
                if not IsValid(self) or not IsValid(ent) then return end
                local dmg = DamageInfo()
                dmg:SetDamage(self.DudDamage)
                dmg:SetDamageType(DMG_CLUB)
                dmg:SetAttacker(IsValid(self.Attacker) and self.Attacker or self)
                dmg:SetInflictor(self)
                dmg:SetDamagePosition(pos)
                dmg:SetDamageForce(force)
                ent:TakeDamageInfo(dmg)
            end)
        end
        self.DieTime = math.min(self.DieTime, CurTime() + 4)
    end
    if data.Speed > 60 then
        self:EmitSound("physics/metal/metal_grenade_impact_hard" .. math.random(1, 3) .. ".wav", 70, math.random(110, 125))
    end
    phys:SetVelocity(data.OurOldVelocity * 0.3)
end
