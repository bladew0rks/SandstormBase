if not CLIENT then return end

local matBeam = Material("effects/laser1")
local matGlow = Material("sprites/light_glow02_add")
local beamCol = Color(255, 30, 20, 90)
local LASER_DEFAULT = Color(255, 30, 20)
local AXIS_X = Vector(1, 0, 0)
local beamBoneMat = Matrix()
local laserTraceOut = {}
local laserEndScratch, beamEndScratch = Vector(), Vector()

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
        local bone = SandSwep.BoneId(ent, def.BeamBone)
        local matrix = bone and SandSwep.Math.CopyBone(ent, bone, beamBoneMat)
        if matrix then origin, entAng = matrix:GetTranslation(), matrix:GetAngles() end
    end

    local start = origin
    local att
    if def.BeamLocal then
        start = LocalToWorld(def.BeamLocal, angle_zero, origin, entAng)
    else
        local attId = def.Beam and SandSwep.AttachmentId(ent, def.Beam)
        att = attId and ent:GetAttachment(attId)
        if att then start = att.Pos end
    end

    if att and not def.BeamDir and not def.Rail then
        local dir = att.Ang:Forward()
        dir:Normalize()
        return start, dir
    end

    local localDir = def.BeamDir or (def.Rail and def.Rail.Front) or AXIS_X
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
    beam.eye, beam.eyeAng, beam.scale = eye, eyeAng, scale

    local laserStart, laserDir, laserDef
    for i = 1, #FEATURES do
        local feature = FEATURES[i]
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
        local rp, rd = ray.pos, ray.dir
        laserEndScratch:SetUnpacked(rp.x + rd.x * 4096, rp.y + rd.y * 4096, rp.z + rd.z * 4096)
        local tr = SandSwep.TraceLine(rp, laserEndScratch, owner, MASK_SHOT, laserTraceOut)
        if tr.Hit then
            local eye, eyeAng = beams.eye or EyePos(), beams.eyeAng or EyeAngles()
            local scale = beams.scale or (math.tan(math.rad(LocalPlayer():GetFOV()) * 0.5) / math.tan(math.rad(self.ViewModelFOV or 62) * 0.5))
            local hit = WorldToLocal(tr.HitPos, angle_zero, eye, eyeAng)
            hit.y, hit.z = hit.y / scale, hit.z / scale
            local hitPos = LocalToWorld(hit, angle_zero, eye, eyeAng)
            len = math.Clamp((hitPos.x - start.x) * dir.x + (hitPos.y - start.y) * dir.y + (hitPos.z - start.z) * dir.z, 0, 120)
        end
    end

    local col = def.LaserColor or LASER_DEFAULT
    render.SetMaterial(matBeam)
    beamCol.r, beamCol.g, beamCol.b = col.r, col.g, col.b
    beamEndScratch:SetUnpacked(start.x + dir.x * len, start.y + dir.y * len, start.z + dir.z * len)
    render.DrawBeam(start, beamEndScratch, 0.15, 0, 1, beamCol)

    render.SetMaterial(matGlow)
    render.DrawSprite(start, 0.6, 0.6, col)
end
