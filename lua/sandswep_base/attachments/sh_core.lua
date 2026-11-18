SandSwep = SandSwep or {}
SandSwep.Attachments = SandSwep.Attachments or {}

local boneIds = {}
function SandSwep.BoneId(ent, name)
    local model = ent:GetModel()
    if not model then return ent:LookupBone(name) end

    local ids = boneIds[model]
    if not ids then
        ids = {}
        boneIds[model] = ids
    end

    local id = ids[name]
    if id == nil then
        id = ent:LookupBone(name) or false
        ids[name] = id
    end

    return id or nil
end

local seqIds = {}
function SandSwep.SeqId(ent, name)
    local model = ent:GetModel()
    if not model then return ent:LookupSequence(name) or -1 end

    local ids = seqIds[model]
    if not ids then
        ids = {}
        seqIds[model] = ids
    end

    local id = ids[name]
    if id == nil then
        id = ent:LookupSequence(name) or -1
        if id >= 0 or ent:GetSequenceCount() > 0 then ids[name] = id end
    end

    return id
end

local poseIds = {}
function SandSwep.PoseParamId(ent, name)
    local model = ent:GetModel()
    if not model then return ent:LookupPoseParameter(name) end

    local ids = poseIds[model]
    if not ids then
        ids = {}
        poseIds[model] = ids
    end

    local id = ids[name]
    if id == nil then
        id = ent:LookupPoseParameter(name)
        if id >= 0 or ent:GetSequenceCount() > 0 then ids[name] = id end
    end

    return id
end

local traceIn = {}
function SandSwep.TraceLine(start, endpos, filter, mask, out)
    traceIn.start = start
    traceIn.endpos = endpos
    traceIn.filter = filter
    traceIn.mask = mask
    traceIn.output = out

    local tr = util.TraceLine(traceIn)
    traceIn.filter, traceIn.output = nil, nil

    return out or tr
end

function SandSwep.RegisterAttachment(id, def)
    def.ID = id
    SandSwep.Attachments[id] = def
    SandSwep.AttRev = (SandSwep.AttRev or 0) + 1

    if def.Model then util.PrecacheModel(def.Model) end

    return def
end

if CLIENT then
    function SandSwep.OffsetFrame(ent, offset)
        if offset.Attachment then
            local id = ent:LookupAttachment(offset.Attachment)
            local att = id and id > 0 and ent:GetAttachment(id)
            if att then return att.Pos, att.Ang end
        end

        local bone = SandSwep.BoneId and SandSwep.BoneId(ent, offset.Bone or "") or ent:LookupBone(offset.Bone or "")
        local matrix = bone and ent:GetBoneMatrix(bone)
        if matrix then return matrix:GetTranslation(), matrix:GetAngles() end
    end

    function SandSwep.ApplyAttScale(ent, def)
        if not def or not def.Scale or def.Scale == 1 then return end

        local scale = Matrix()
        scale:Scale(Vector(def.Scale, def.Scale, def.Scale))
        ent:EnableMatrix("RenderMultiply", scale)
    end
end

function SandSwep.GetAttachmentDef(id)
    return id and SandSwep.Attachments[id]
end
