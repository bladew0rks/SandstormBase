SANDTPIK = SANDTPIK or {}

local function boneId(ent, name)
    if not isstring(name) or name == "" then return end

    local id = ent:LookupBone(name)
    if id and id >= 0 then return id end
end

function SANDTPIK.ClearAttachments(state)
    if not state or not state.attEnts then return end

    for _, ent in pairs(state.attEnts) do
        if IsValid(ent) then ent:Remove() end
    end

    state.attEnts, state.attData, state.attSkins, state.attModel = nil, nil, nil, nil
end

local function allValid(ents)
    for _, ent in pairs(ents) do
        if not IsValid(ent) then return false end
    end

    return true
end

local function newModel(path)
    local ent = ClientsideModel(path, RENDERGROUP_OPAQUE)
    if not IsValid(ent) then return end

    ent:SetNoDraw(true)
    ent:DrawShadow(false)
    return ent
end

local function build(wep, tpik, state)
    local ents = {}
    local slots = wep:GetAttachmentSlots()

    for slotName in wep:IterAttachments() do
        local mount = slots[slotName] and slots[slotName].Mount
        local ent = mount and mount.Model and newModel(mount.Model)

        if ent then
            ent.SandTPIK_Slot = slotName
            ent.SandTPIK_Offset = wep:GetMountOffset(slots[slotName])
            ents[slotName .. "#mount"] = ent
        end
    end

    for slotName, id, def in wep:IterAttachments() do
        local ent = def.Model and newModel(def.Model)

        if ent then
            ent.SandTPIK_Def = def
            ent.SandTPIK_Slot = slotName
            ent.SandTPIK_Offset = wep:GetAttachmentOffset(slotName, id, def)
            ent:SetSkin(wep:GetAttachmentSkin(slotName, def) or 0)
            if SandSwep.ApplyAttScale then SandSwep.ApplyAttScale(ent, def) end

            if not ent.SandTPIK_Offset then
                ent:SetPos(tpik:GetPos())
                ent:SetAngles(tpik:GetAngles())
                ent:SetParent(tpik)
                ent:AddEffects(EF_BONEMERGE)
            end

            ents[slotName] = ent
        end
    end

    state.attEnts = ents
end

function SANDTPIK.SyncAttachments(wep, tpik, state)
    if not wep.GetAttachmentSlots or not wep.IterAttachments then return end

    local data, skins, model = wep:GetAttData(), wep:GetAttSkins(), tpik.SandTPIK_Path

    local unchanged = state.attEnts
        and state.attData == data and state.attSkins == skins and state.attModel == model
        and allValid(state.attEnts)

    if unchanged then return end

    local ok, slots = pcall(wep.GetAttachmentSlots, wep)
    if not ok or not istable(slots) or not next(slots) then
        SANDTPIK.ClearAttachments(state)
        state.attEnts, state.attData, state.attSkins, state.attModel = {}, data, skins, model
        return
    end

    SANDTPIK.ClearAttachments(state)

    local built = pcall(build, wep, tpik, state)
    if not built then
        SANDTPIK.ClearAttachments(state)
        return
    end

    state.attData, state.attSkins, state.attModel = data, skins, model
end

local function poseFlip(wep, ent, def)
    if not def or not def.FlipSequence or not wep.GetSightFlip then return end

    if ent.SandTPIK_FlipSeq == nil then
        ent.SandTPIK_FlipSeq = ent:LookupSequence(def.FlipSequence)
    end

    local seq = ent.SandTPIK_FlipSeq
    if not seq or seq < 0 then return end

    if ent:GetSequence() ~= seq then ent:ResetSequence(seq) end
    ent:SetPlaybackRate(0)

    local ok, cycle = pcall(wep.GetSightFlip, wep, ent.SandTPIK_Slot, def.FlipTime)
    if ok and isnumber(cycle) then ent:SetCycle(cycle) end
end

function SANDTPIK.DrawAttachments(wep, tpik, state, flags)
    if not state.attEnts or not next(state.attEnts) then return end

    local frame = FrameNumber()
    local fresh = state.attFrame ~= frame
    state.attFrame = frame

    for _, ent in pairs(state.attEnts) do
        if IsValid(ent) then
            poseFlip(wep, ent, ent.SandTPIK_Def)

            local offset = ent.SandTPIK_Offset

            if offset then
                local bone = ent.SandTPIK_BoneId
                if bone == nil then
                    bone = boneId(tpik, offset.Bone or "") or false
                    ent.SandTPIK_BoneId = bone
                end

                if fresh then
                    local framePos, frameAng
                    if offset.Attachment and SandSwep.OffsetFrame then
                        framePos, frameAng = SandSwep.OffsetFrame(tpik, offset)
                    else
                        local mat = bone and tpik:GetBoneMatrix(bone)
                        if mat then framePos, frameAng = mat:GetTranslation(), mat:GetAngles() end
                    end

                    ent.SandTPIK_Placed = framePos ~= nil

                    if framePos then
                        local pos, ang = LocalToWorld(offset.Pos or vector_origin, offset.Ang or angle_zero, framePos, frameAng)
                        ent:SetPos(pos)
                        ent:SetAngles(ang)
                        ent:SetupBones()
                    end
                end

                if ent.SandTPIK_Placed then ent:DrawModel(flags) end
            else
                if fresh then
                    ent:SetRenderOrigin(tpik:GetPos())
                    ent:SetRenderAngles(tpik:GetAngles())
                    ent:SetupBones()
                end

                ent:DrawModel(flags)
            end
        end
    end
end
