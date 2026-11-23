if not CLIENT then return end

local matBeam = Material("effects/laser1")
local matGlow = Material("sprites/light_glow02_add")
local beamCol = Color(255, 30, 20, 90)
local LASER_DEFAULT = Color(255, 30, 20)

local function DeviceEntity(wep, def, slotName)
    local found
    for _, ent in pairs(wep._vmAttEnts or {}) do
        local matches = IsValid(ent) and ent.SandSwepDef == def
        if matches and (ent.SandSwepSlot == slotName or not found) then
            found = ent
        end
    end

    return found
end

local function DeviceVMRay(wep, def, slotName)
    local ent = DeviceEntity(wep, def, slotName)
    if not ent then return end

    local entAng = ent:GetAngles()
    local origin = ent:GetPos()
    if def.BeamBone then
        local bone = ent:LookupBone(def.BeamBone)
        local matrix = bone and ent:GetBoneMatrix(bone)
        if matrix then origin, entAng = matrix:GetTranslation(), matrix:GetAngles() end
    end

    local start = origin
    local att
    if def.BeamLocal then
        start = LocalToWorld(def.BeamLocal, angle_zero, origin, entAng)
    else
        local attId = def.Beam and ent:LookupAttachment(def.Beam)
        att = attId and attId > 0 and ent:GetAttachment(attId)
        if att then start = att.Pos end
    end

    if att and not def.BeamDir and not def.Rail then
        local dir = att.Ang:Forward()
        dir:Normalize()
        return start, dir
    end

    local localDir = def.BeamDir or (def.Rail and def.Rail.Front) or Vector(1, 0, 0)
    local dir = LocalToWorld(localDir, angle_zero, vector_origin, entAng)
    dir:Normalize()

    return start, dir
end

local function ToWorldRay(start, dir, eye, eyeAng, scale, out)
    local localPos = WorldToLocal(start, angle_zero, eye, eyeAng)
    localPos.y, localPos.z = localPos.y * scale, localPos.z * scale

    local localDir = WorldToLocal(dir, angle_zero, vector_origin, eyeAng)
    localDir.y, localDir.z = localDir.y * scale, localDir.z * scale
    local worldDir = LocalToWorld(localDir, angle_zero, vector_origin, eyeAng)
    worldDir:Normalize()

    out = out or {}
    out.pos, out.dir = LocalToWorld(localPos, angle_zero, eye, eyeAng), worldDir
    return out
end

local FEATURES = { "Laser", "Light" }

function SWEP:UpdateTacticalBeam()
    local eye, eyeAng = EyePos(), EyeAngles()
    local scale = math.tan(math.rad(LocalPlayer():GetFOV()) * 0.5) / math.tan(math.rad(self.ViewModelFOV or 62) * 0.5)

    SandSwep.TacBeam = SandSwep.TacBeam or {}
    local owner = self:GetOwner()
    local beam = SandSwep.TacBeam[owner] or {}
    beam.time = RealTime()

    local laserStart, laserDir, laserDef
    for _, feature in ipairs(FEATURES) do
        local def, slotName = self:GetFeatureDef(feature)
        local start, dir
        if def then start, dir = DeviceVMRay(self, def, slotName) end

        if start then
            beam[feature] = ToWorldRay(start, dir, eye, eyeAng, scale, beam[feature])
            if feature == "Laser" then laserStart, laserDir, laserDef = start, dir, def end
        else
            beam[feature] = nil
        end
    end

    SandSwep.TacBeam[owner] = beam
    return laserStart, laserDir, laserDef
end

function SWEP:DrawVMLaser(start, dir, def)
    if not start or not def or not def.Laser then return end

    if not self:GetVisLaserOn() then
        if self:GetIRLaserOn() and SandSwep.IR and SandSwep.IR.DrawVMLaser then
            return SandSwep.IR.DrawVMLaser(self, start)
        end
        return
    end

    local len = 120
    local owner = self:GetOwner()
    local beams = SandSwep.TacBeam and SandSwep.TacBeam[owner]
    local ray = beams and beams.Laser
    if ray then
        local tr = util.TraceLine({ start = ray.pos, endpos = ray.pos + ray.dir * 4096, filter = owner, mask = MASK_SHOT })
        if tr.Hit then
            local eye, eyeAng = EyePos(), EyeAngles()
            local scale = math.tan(math.rad(LocalPlayer():GetFOV()) * 0.5) / math.tan(math.rad(self.ViewModelFOV or 62) * 0.5)
            local hit = WorldToLocal(tr.HitPos, angle_zero, eye, eyeAng)
            hit.y, hit.z = hit.y / scale, hit.z / scale
            len = math.Clamp((LocalToWorld(hit, angle_zero, eye, eyeAng) - start):Dot(dir), 0, 120)
        end
    end

    local col = def.LaserColor or LASER_DEFAULT
    render.SetMaterial(matBeam)
    beamCol.r, beamCol.g, beamCol.b = col.r, col.g, col.b
    render.DrawBeam(start, start + dir * len, 0.15, 0, 1, beamCol)

    render.SetMaterial(matGlow)
    render.DrawSprite(start, 0.6, 0.6, col)
end
