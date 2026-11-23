local Internal = SandSwep.AttInternal

local DEFAULT_ANCHOR = { optic = "Optic", muzzle = "Suppressor", barrel = "Suppressor",
    underbarrel = "Foregrip", tactical = "Laser", frontsight = "Suppressor", magazine = "b_wpn_mag" }
local DEFAULT_BACK   = { frontsight = 7 }

local function RemovePreview(preview)
    if not preview then return end

    if IsValid(preview.gun) then preview.gun:Remove() end
    for _, ent in pairs(preview.atts or {}) do
        if IsValid(ent) then ent:Remove() end
    end

    preview.gun, preview.atts = nil, {}
end

local function CreatePreviewGun(wep)
    local mdl = wep.ViewModel
    if not mdl or mdl == "" then return end

    local gun = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
    if not IsValid(gun) then return end

    gun:SetNoDraw(true)
    gun:SetPos(vector_origin)
    gun:SetAngles(angle_zero)

    local idle = wep.GetAnimEntry and wep:GetAnimEntry("idle")
    local seqName = istable(idle) and (idle.Seq or idle[1]) or idle
    local seq = seqName and gun:LookupSequence(istable(seqName) and seqName[1] or seqName) or -1
    if seq and seq >= 0 then
        gun:ResetSequence(seq)
        gun:SetCycle(0)
        gun:SetPlaybackRate(0)
    end

    for name, value in pairs(wep.GetDesiredBodygroups and wep:GetDesiredBodygroups() or {}) do
        local id = gun:FindBodygroupByName(name)
        if id and id >= 0 then gun:SetBodygroup(id, value) end
    end
    gun:SetSkin(wep.GetDesiredSkin and wep:GetDesiredSkin() or 0)

    local round = gun:LookupBone("b_wpn_gl_round")
    if round and not (wep.GetGLConfig and wep:GetGLConfig() and wep:GetGLLoaded()) then
        gun:ManipulateBoneScale(round, Vector(0, 0, 0))
    end

    gun:SetupBones()

    return gun
end

local function AddPreviewAttachments(preview, wep, gun)
    local slots = wep:GetAttachmentSlots()
    for slotName, id in wep:IterAttachments() do
        local mount = slots[slotName] and slots[slotName].Mount
        if mount and mount.Except and mount.Except[id] then mount = nil end

        local ent = mount and wep.GetMountOffset and ClientsideModel(mount.Model, RENDERGROUP_OPAQUE)
        if not IsValid(ent) then continue end

        ent:SetNoDraw(true)
        if mount.Rail then
            ent.SandSwepOffset = wep:GetMountOffset(slots[slotName])
        else
            ent:SetPos(vector_origin)
            ent:SetAngles(angle_zero)
            ent:SetParent(gun)
            ent:AddEffects(EF_BONEMERGE)
        end
        preview.atts[slotName .. "#mount"] = ent
    end

    for slotName, id, def in wep:IterAttachments() do
        if not def.Model then continue end

        local ent = ClientsideModel(def.Model, RENDERGROUP_OPAQUE)
        if not IsValid(ent) then continue end

        ent:SetNoDraw(true)
        ent.SandSwepDef = def
        ent.SandSwepOffset = wep.GetAttachmentOffset and wep:GetAttachmentOffset(slotName, id, def)
        if wep.GetAttachmentSkin then ent:SetSkin(wep:GetAttachmentSkin(slotName, def)) end
        SandSwep.ApplyAttScale(ent, def)

        if not ent.SandSwepOffset then
            ent:SetPos(vector_origin)
            ent:SetAngles(angle_zero)
            ent:SetParent(gun)
            ent:AddEffects(EF_BONEMERGE)
        end

        if def.FlipSequence then
            local flipSeq = ent:LookupSequence(def.FlipSequence)
            if flipSeq and flipSeq >= 0 then
                ent:ResetSequence(flipSeq)
                ent:SetPlaybackRate(0)
                ent:SetCycle(wep.GetSightFlip and wep:GetSightFlip(slotName, def.FlipTime) or 0)
            end
        end

        preview.atts[slotName] = ent
    end
end

local function FramePreview(preview, gun)
    local points = {}
    for bone = 0, gun:GetBoneCount() - 1 do
        local name = gun:GetBoneName(bone) or ""
        if string.StartWith(name, "b_wpn") or string.StartWith(name, "a_") or string.StartWith(name, "tag_") then
            local matrix = gun:GetBoneMatrix(bone)
            if matrix then points[#points + 1] = { bone = bone, pos = matrix:GetTranslation() } end
        end
    end

    local rootBone = gun:LookupBone("b_wpn") or gun:LookupBone("J_Gun")
    local rootMatrix = rootBone and gun:GetBoneMatrix(rootBone)
    local refPos = rootMatrix and rootMatrix:GetTranslation()
    if not refPos and #points > 0 then
        refPos = Vector(0, 0, 0)
        for _, point in ipairs(points) do refPos = refPos + point.pos end
        refPos = refPos / #points
    end

    local dists = {}
    for _, point in ipairs(points) do
        point.dist = point.pos:Distance(refPos)
        dists[#dists + 1] = point.dist
    end
    table.sort(dists)

    local limit = math.max((dists[math.ceil(#dists * 0.75)] or 20) * 2.2, 12)
    local mins, maxs = Vector(1e9, 1e9, 1e9), Vector(-1e9, -1e9, -1e9)
    for _, point in ipairs(points) do
        if point.dist > limit then
            gun:ManipulateBoneScale(point.bone, Vector(0, 0, 0))
        else
            local pos = point.pos
            mins.x, mins.y, mins.z = math.min(mins.x, pos.x), math.min(mins.y, pos.y), math.min(mins.z, pos.z)
            maxs.x, maxs.y, maxs.z = math.max(maxs.x, pos.x), math.max(maxs.y, pos.y), math.max(maxs.z, pos.z)
        end
    end
    if mins.x > maxs.x then mins, maxs = gun:GetRenderBounds() end

    preview.center = (mins + maxs) * 0.5
    preview.mins, preview.maxs = mins, maxs

    local fwd
    local muzzleId = gun:LookupAttachment("muzzle")
    local muzzleAtt = muzzleId and muzzleId > 0 and gun:GetAttachment(muzzleId)
    if muzzleAtt then
        fwd = muzzleAtt.Pos - preview.center
        fwd.z = 0
        if fwd:LengthSqr() < 1 then fwd = nil else fwd:Normalize() end
    end
    preview.fwd = fwd or Vector(1, 0, 0)

    local origin = refPos or preview.center
    local front = muzzleAtt and muzzleAtt.Pos or (origin + preview.fwd * 20)
    local frontLen = math.max((front - origin):Dot(preview.fwd), 4)
    local backT = -0.6 * frontLen
    for _, point in ipairs(points) do
        local along = (point.pos - origin):Dot(preview.fwd)
        if along < backT and along > -1.2 * frontLen then
            local side = (point.pos - origin) - preview.fwd * along
            if side:Length() < frontLen * 0.5 then backT = along end
        end
    end

    local back = origin + preview.fwd * backT
    preview.front, preview.back = front, back
    preview.center = (front + back) * 0.5
    preview.length = (front - back):Length() * 1.05
end

local function BuildPreview(preview, wep)
    RemovePreview(preview)

    local gun = CreatePreviewGun(wep)
    if not gun then return end
    preview.gun = gun

    AddPreviewAttachments(preview, wep, gun)
    FramePreview(preview, gun)
end

local meshCenters = {}

local function MeshCenter(mdl)
    local center = meshCenters[mdl]
    if center ~= nil then return center end

    center = false
    local meshes = util.GetModelMeshes(mdl)
    if meshes then
        local mins, maxs = Vector(math.huge, math.huge, math.huge), Vector(-math.huge, -math.huge, -math.huge)
        for _, part in ipairs(meshes) do
            for _, vert in ipairs(part.verticies or part.triangles or {}) do
                local pos = vert.pos
                mins.x, mins.y, mins.z = math.min(mins.x, pos.x), math.min(mins.y, pos.y), math.min(mins.z, pos.z)
                maxs.x, maxs.y, maxs.z = math.max(maxs.x, pos.x), math.max(maxs.y, pos.y), math.max(maxs.z, pos.z)
            end
        end
        if mins.x <= maxs.x then center = (mins + maxs) * 0.5 end
    end

    meshCenters[mdl] = center
    return center
end

local function AnchorPos(preview, slotName, slot)
    local gun = preview.gun
    if not IsValid(gun) then return end

    local ent = preview.atts[slotName]
    local name = slot.MenuAnchor or DEFAULT_ANCHOR[slotName]
    local pos
    if not slot.MenuAnchor and IsValid(ent) then
        ent:SetupBones()
        local matrix = ent:GetBoneMatrix(0)
        if matrix then
            local center = MeshCenter(ent:GetModel()) or ent:OBBCenter()
            pos = LocalToWorld(center, angle_zero, matrix:GetTranslation(), matrix:GetAngles())
        end
    end

    if not pos and not slot.MenuAnchor and slot.Rail then
        local bone = gun:LookupBone(slot.Rail.Bone or "b_wpn")
        local matrix = bone and gun:GetBoneMatrix(bone)
        if matrix then pos = LocalToWorld(slot.Rail.Pos, angle_zero, matrix:GetTranslation(), matrix:GetAngles()) end
    end

    if not pos and name then
        local attId = gun:LookupAttachment(name)
        local att = attId and attId > 0 and gun:GetAttachment(attId)
        if att then pos = att.Pos end

        if not pos then
            local bone = gun:LookupBone(name)
            local matrix = bone and gun:GetBoneMatrix(bone)
            if matrix then pos = matrix:GetTranslation() end
        end
    end

    pos = pos or preview.center
    local back = slot.MenuAnchorBack or (not slot.MenuAnchor and DEFAULT_BACK[slotName]) or 0
    if back ~= 0 then pos = pos - preview.fwd * back + Vector(0, 0, 1) end

    return pos
end

Internal.RemovePreview = RemovePreview
Internal.BuildPreview = BuildPreview
Internal.AnchorPos = AnchorPos
