local GLOW = Material("effects/yellowflare")
local BEAM = Material("effects/laser_tracer")

function EFFECT:Init(data)
    local ent, att = data:GetEntity(), data:GetAttachment()
    self.StartPos = self:GetTracerShootPos(data:GetStart(), ent, att)
    self.EndPos = data:GetOrigin()
    self.Dir = self.EndPos - self.StartPos
    self.Len = self.Dir:Length()
    self.Dir:Normalize()
    self.Life = math.Clamp(self.Len / 2500, 0.08, 0.35)
    self.Die = CurTime() + self.Life
    self.Size = math.Rand(5, 9)
    self:SetRenderBoundsWS(self.StartPos, self.EndPos)

    local em = ParticleEmitter(self.StartPos)
    if not em then return end
    local reach = math.min(self.Len, 600)
    for i = 1, 6 do
        local p = em:Add("effects/fire_embers" .. math.random(1, 3), self.StartPos + self.Dir * math.Rand(0, reach))
        if p then
            p:SetVelocity(self.Dir * math.Rand(80, 300) + VectorRand() * 40)
            p:SetGravity(Vector(0, 0, -120))
            p:SetDieTime(math.Rand(0.4, 1.1))
            p:SetStartAlpha(255)
            p:SetEndAlpha(0)
            p:SetStartSize(math.Rand(1.5, 3))
            p:SetEndSize(0)
            p:SetColor(255, math.random(120, 190), 60)
            p:SetAirResistance(60)
        end
    end
    for i = 1, 2 do
        local p = em:Add("effects/fire_cloud" .. math.random(1, 2), self.StartPos + self.Dir * math.Rand(10, math.min(self.Len, 120)))
        if p then
            p:SetVelocity(self.Dir * math.Rand(150, 400))
            p:SetDieTime(math.Rand(0.12, 0.25))
            p:SetStartAlpha(200)
            p:SetEndAlpha(0)
            p:SetStartSize(math.Rand(6, 10))
            p:SetEndSize(math.Rand(16, 24))
            p:SetRoll(math.Rand(0, 360))
            p:SetColor(255, 170, 90)
            p:SetAirResistance(200)
        end
    end
    em:Finish()
end

function EFFECT:Think()
    return CurTime() < self.Die
end

function EFFECT:Render()
    local f = 1 - (self.Die - CurTime()) / self.Life
    local head = self.StartPos + self.Dir * (self.Len * f)
    local tail = self.StartPos + self.Dir * math.max(self.Len * f - 180, 0)
    local a = 255 * (1 - f * 0.6)
    render.SetMaterial(BEAM)
    render.DrawBeam(tail, head, self.Size * 0.6, 0, 1, Color(255, 140, 50, a))
    render.SetMaterial(GLOW)
    render.DrawSprite(head, self.Size * 2, self.Size * 2, Color(255, 150, 60, a))
end
