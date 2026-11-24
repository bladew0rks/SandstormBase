local VisualFrameTime = SandSwep.VisualFrameTime

SANDTPIK = SANDTPIK or {}

local cv = SANDTPIK.CVars

local ENTITY = FindMetaTable("Entity")
local entityGetBoneMatrix = ENTITY.GetBoneMatrix
local entitySetBoneMatrix = ENTITY.SetBoneMatrix
local copyBone = SandSwep.Math.CopyBone

local MATH = SandSwep.Math
local Unit, QuatMul, QuatRotate, QuatAxisAngle, QuatFromMatrix = MATH.Unit, MATH.QuatMul, MATH.QuatRotate, MATH.QuatAxisAngle, MATH.QuatFromMatrix

local FrameNumber, RealTime, CurTime, IsValid = FrameNumber, RealTime, CurTime, IsValid
local mathClamp, mathMax, mathAbs, mathSqrt = math.Clamp, math.max, math.abs, math.sqrt

local function handBones(side)
    local list = { "ValveBiped.Bip01_" .. side .. "_Hand" }

    for finger = 0, 4 do
        for _, seg in ipairs({ "", "1", "2" }) do
            list[#list + 1] = "ValveBiped.Bip01_" .. side .. "_Finger" .. finger .. seg
        end
    end

    return list
end

SANDTPIK.LeftHandBones = handBones("L")
SANDTPIK.RightHandBones = handBones("R")
SANDTPIK.HandBones = {}
for _, bone in ipairs(SANDTPIK.LeftHandBones) do table.insert(SANDTPIK.HandBones, bone) end
for _, bone in ipairs(SANDTPIK.RightHandBones) do table.insert(SANDTPIK.HandBones, bone) end

SANDTPIK.ArmBones = {
    Left = {
        UpperArm = "ValveBiped.Bip01_L_UpperArm",
        Forearm = "ValveBiped.Bip01_L_Forearm",
        Ulna = "ValveBiped.Bip01_L_Ulna",
        Hand = "ValveBiped.Bip01_L_Hand",
    },
    Right = {
        UpperArm = "ValveBiped.Bip01_R_UpperArm",
        Forearm = "ValveBiped.Bip01_R_Forearm",
        Ulna = "ValveBiped.Bip01_R_Ulna",
        Hand = "ValveBiped.Bip01_R_Hand",
    },
}

SANDTPIK.SpineBone = "ValveBiped.Bip01_Spine4"
SANDTPIK.HeadBone = "ValveBiped.Bip01_Head1"
SANDTPIK.BoneClamp = 38
SANDTPIK.DefaultLimbLength = 12
SANDTPIK.ArmStretch = 1.35
SANDTPIK.BlockGrace = 0.12
SANDTPIK.PitchLimit = 55
SANDTPIK.SafePitchLimit = 1
SANDTPIK.DefaultOffset = {
    Pos = Vector(-3.25, 1, -2),
    Ang = Angle(0, 0, 0),
    AimPos = Vector(0, 2.5, -1.5),
    SafePos = Vector(0.5, 3, -1.5),
    SafeAng = Angle(-25, 10, -10),
}

SANDTPIK.PistolOffset = {
    Pos = Vector(-0.25, 1, -2),
    Ang = Angle(0, 0, 0),
    AimPos = Vector(3, 2.5, -1.5),
    SafePos = Vector(0.5, 3, -1.5),
    SafeAng = Angle(-25, 10, -10),
}

local PISTOL_HOLDTYPES = { pistol = true, revolver = true }

local cfg = {}

local function readConvars()
    cfg.enabled = cv.Enabled:GetBool()
    cfg.others = cv.Others:GetBool()
    cfg.distance = cv.DistanceOthers:GetFloat()
    cfg.lod = cv.LodDistance:GetFloat()
    cfg.mesh1 = cv.MeshLod1:GetFloat()
    cfg.mesh2 = cv.MeshLod2:GetFloat()
end

readConvars()
for _, convar in pairs(cv) do
    cvars.AddChangeCallback(convar:GetName(), readConvars, "SandTPIK.Cache")
end

local boneIndexCache = setmetatable({}, { __mode = "k" })

local function getBone(ent, name)
    if not IsValid(ent) or not isstring(name) then return nil end

    local mdl = ent:GetModel() or ""
    local cache = boneIndexCache[ent]

    if not cache or cache.mdl ~= mdl then
        cache = { mdl = mdl, bones = {} }
        boneIndexCache[ent] = cache
    end

    local cached = cache.bones[name]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local idx = ent:LookupBone(name)
    if idx == -1 then idx = nil end

    if idx or ent:GetBoneCount() > 0 then
        cache.bones[name] = idx or false
    end

    return idx
end

SANDTPIK.GetBone = getBone

local childBoneCache = {}

local function collectChildren(ent, bone, out, stopBone)
    for _, id in ipairs(ent:GetChildBones(bone) or {}) do
        if id ~= stopBone then
            collectChildren(ent, id, out, stopBone)
            table.insert(out, id)
        end
    end
end

local function getChildren(ent, bone, stopBone)
    local mdl = ent:GetModel() or ""
    local modelCache = childBoneCache[mdl]

    if not modelCache then
        modelCache = {}
        childBoneCache[mdl] = modelCache
    end

    local byStop = modelCache[bone]
    if not byStop then
        byStop = {}
        modelCache[bone] = byStop
    end

    local key = stopBone or -1
    local cached = byStop[key]
    if cached then return cached end

    local bones = {}
    collectChildren(ent, bone, bones, stopBone)
    byStop[key] = bones

    return bones
end

local applyInverse, applyTranslate, applyChild, applyOut = Matrix(), Matrix(), Matrix(), Matrix()

local function applyBoneMatrix(ent, bone, newMatrix, stopBone)
    if not copyBone(ent, bone, applyInverse) then return end
    if not applyInverse:Invert() then return end

    applyTranslate:Set(newMatrix)
    applyTranslate:Mul(applyInverse)
    local children = getChildren(ent, bone, stopBone)

    for i = 1, #children do
        local id = children[i]
        if copyBone(ent, id, applyChild) then
            applyOut:Set(applyTranslate)
            applyOut:Mul(applyChild)
            entitySetBoneMatrix(ent, id, applyOut)
        end
    end

    entitySetBoneMatrix(ent, bone, newMatrix)
end

local smooth = SandSwep.Math.Smoothstep

local function noop() end

local SHIMS = {
    RenderOverride = noop,
    DrawWorldModel = noop,
    DrawWorldModelTranslucent = noop,
}

local shimmed = {}

local function setShimmed(wep, enabled)
    if not IsValid(wep) then return end

    if enabled then
        if wep.SandTPIK_Shims then
            if not wep:GetNoDraw() then wep:SetNoDraw(true) end
            return
        end

        local tbl = wep:GetTable()
        local saved = {}

        for name, replacement in pairs(SHIMS) do
            saved[name] = rawget(tbl, name)
            tbl[name] = replacement
        end

        tbl.SandTPIK_Shims = saved
        shimmed[wep] = true
        wep:SetNoDraw(true)
        return
    end

    shimmed[wep] = nil

    local saved = wep.SandTPIK_Shims
    if not saved then return end

    local tbl = wep:GetTable()
    for name in pairs(SHIMS) do tbl[name] = saved[name] end
    tbl.SandTPIK_Shims = nil

    wep:SetNoDraw(false)
end

local mirrors = {}

local function removeModel(wep)
    if not wep then return end

    if not IsValid(wep) then
        local orphan = mirrors[wep]
        mirrors[wep] = nil
        if IsValid(orphan) then orphan:Remove() end
        return
    end

    setShimmed(wep, false)
    mirrors[wep] = nil
    wep.SandTPIK_BlockedAt = nil

    if wep.SandTPIK_State then SANDTPIK.ClearAttachments(wep.SandTPIK_State) end

    if IsValid(wep.SandTPIK_Model) then wep.SandTPIK_Model:Remove() end

    wep.SandTPIK_Model = nil
    wep.SandTPIK_State = nil
end

SANDTPIK.RemoveModel = removeModel

hook.Add("Think", "SandTPIK.Housekeeping", function()
    for wep in pairs(shimmed) do
        if not IsValid(wep) then
            shimmed[wep] = nil
        elseif not IsValid(wep.SandTPIK_Model) or not IsValid(wep:GetOwner()) then
            setShimmed(wep, false)
        elseif not wep:GetNoDraw() then
            wep:SetNoDraw(true)
        end
    end

    for wep, mirror in pairs(mirrors) do
        if not IsValid(wep) then
            removeModel(wep)
        elseif IsValid(mirror) and not mirror:GetNoDraw() then
            mirror:SetNoDraw(true)
        end
    end
end)

local blendMatrix = SandSwep.Math.BlendMatrix

local baseMat, toLocalMat, localMat, worldMat, boneMat = Matrix(), Matrix(), Matrix(), Matrix(), Matrix()

local function setFrame(ent)
    baseMat:SetTranslation(ent:GetPos())
    baseMat:SetAngles(ent:GetAngles())
    toLocalMat:Set(baseMat)
    toLocalMat:InvertTR()
end

local function snapshot(ent, state)
    local from, valid = state.blendFrom, state.blendOk
    if not from then
        from, valid = {}, {}
        state.blendFrom, state.blendOk = from, valid
    end

    setFrame(ent)

    for i = 0, ent:GetBoneCount() - 1 do
        local mat = copyBone(ent, i, boneMat)
        if not mat then
            valid[i] = false
            continue
        end

        local keep = from[i]
        if not keep then
            keep = Matrix()
            from[i] = keep
        end

        keep:Set(toLocalMat)
        keep:Mul(mat)
        valid[i] = true
    end
end

local function applyBlend(ent, state, numBones)
    local blend = state.blend
    if not blend then return end

    local weight = (RealTime() - blend.start) / blend.dur
    if weight >= 1 then
        state.blend = nil
        return
    end

    weight = smooth(weight)

    setFrame(ent)
    local from, valid = state.blendFrom, state.blendOk

    for i = 0, numBones - 1 do
        if not valid[i] then continue end

        local mat = copyBone(ent, i, boneMat)
        if not mat then continue end

        localMat:Set(toLocalMat)
        localMat:Mul(mat)
        blendMatrix(from[i], localMat, weight, localMat)

        worldMat:Set(baseMat)
        worldMat:Mul(localMat)
        entitySetBoneMatrix(ent, i, worldMat)
    end
end

SANDTPIK.PropPatterns = { "mag", "round", "casing", "shell", "rocket", "grenade", "belt", "bullet", "clip" }
SANDTPIK.PropIgnore = { "magrelease", "b_ch_", "ik_" }
SANDTPIK.PropBehind = 3

local BONE_HIDDEN, BONE_SHOWN = Vector(0, 0, 0), Vector(1, 1, 1)

local function nameSet(list)
    local out = {}

    if istable(list) then
        for _, name in ipairs(list) do
            if isstring(name) then out[string.lower(name)] = true end
        end
    end

    return out
end

local function getPropBones(wep, tpik, state)
    local mdl = tpik:GetModel()
    if state.propBones and state.propModel == mdl then return state.propBones end

    local forced, kept = nameSet(wep.TPIKHideBones), nameSet(wep.TPIKKeepBones)
    local bones = {}

    for i = 0, tpik:GetBoneCount() - 1 do
        local name = string.lower(tpik:GetBoneName(i) or "")
        local match = forced[name]

        if not match and not kept[name] then
            local ignored = false
            for _, skip in ipairs(SANDTPIK.PropIgnore) do
                if string.find(name, skip, 1, true) then
                    ignored = true
                    break
                end
            end

            if not ignored then
                for _, pattern in ipairs(SANDTPIK.PropPatterns) do
                    if string.find(name, pattern, 1, true) then
                        match = true
                        break
                    end
                end
            end
        end

        if match then
            bones[#bones + 1] = {
                index = i,
                always = forced[name] == true,
                hidden = false,
            }
        end
    end

    state.propBones, state.propModel = bones, mdl

    return bones
end

local propMat = Matrix()

local function hideParkedProps(wep, tpik, state)
    local bones = getPropBones(wep, tpik, state)
    local count = #bones
    if count == 0 then return end

    local origin = tpik:GetPos()
    local fwd = tpik:GetAngles():Forward()
    local originX, originY, originZ = origin.x, origin.y, origin.z
    local fwdX, fwdY, fwdZ = fwd.x, fwd.y, fwd.z
    local limit = wep.TPIKPropBehind or SANDTPIK.PropBehind

    for i = 1, count do
        local bone = bones[i]
        local hide = bone.always

        if not hide then
            local mat = copyBone(tpik, bone.index, propMat)
            if mat then
                local bonePos = mat:GetTranslation()
                local depth = (bonePos.x - originX) * fwdX
                    + (bonePos.y - originY) * fwdY
                    + (bonePos.z - originZ) * fwdZ

                hide = depth < limit
            end
        end

        if hide ~= bone.hidden then
            bone.hidden = hide
            tpik:ManipulateBoneScale(bone.index, hide and BONE_HIDDEN or BONE_SHOWN)
        end
    end
end

local function mirrorBones(ent, numBones)
    local wep = ent.SandTPIK_Weapon
    if not IsValid(wep) then return end

    local state = wep.SandTPIK_State
    local detailed = not state or state.detailed ~= false

    if detailed and wep.VMGrip then pcall(wep.VMGrip, wep, ent) end
    if state then applyBlend(ent, state, numBones) end
    if detailed and wep.VMMagRounds then pcall(wep.VMMagRounds, wep, ent) end
end

local function ensureModel(wep)
    local mdl = wep.ViewModel
    if not isstring(mdl) or mdl == "" then return nil end

    local tpik = wep.SandTPIK_Model
    if IsValid(tpik) and tpik.SandTPIK_Path == mdl then return tpik end
    if IsValid(tpik) then tpik:Remove() end

    tpik = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
    if not IsValid(tpik) then return nil end

    tpik:SetNoDraw(true)
    tpik:SetMoveType(MOVETYPE_NONE)
    tpik:SetSolid(SOLID_NONE)
    tpik:SetNotSolid(true)
    tpik:AddEffects(EF_NOINTERP)
    tpik:DrawShadow(false)
    tpik:SetIK(false)
    tpik.SandTPIK_Weapon = wep
    tpik.SandTPIK_Path = mdl

    tpik:AddCallback("BuildBonePositions", mirrorBones)

    local idle = tpik:LookupSequence("idle")
    if not idle or idle < 0 then idle = tpik:LookupSequence("base_idle") end

    wep.SandTPIK_Model = tpik
    wep.SandTPIK_State = {
        idleSeq = (idle and idle >= 0) and idle or 0,
        loops = {},
        right = {},
        left = {},
    }
    mirrors[wep] = tpik

    return tpik
end

local CYCLE_HIP = {
    iron_cycle = "base_cycle", iron_cycle_optic = "base_cycle",
    deployed_iron_cycle = "deployed_cycle", deployed_iron_cycle_optic = "deployed_cycle",
}

local function hipCycle(wep, tpik, state, seq)
    if not (wep.IsBoltAction and wep:IsBoltAction()) or wep.TubeFed then return seq, false end

    local map = state.cycleMap
    if not map then
        map = {}
        state.cycleMap = map
    end

    local mapped = map[seq]
    if mapped == nil then
        local name = tpik:GetSequenceName(seq) or ""
        local hipName = CYCLE_HIP[name]
        local hipSeq = hipName and tpik:LookupSequence(hipName)

        if hipSeq and hipSeq >= 0 then
            mapped = hipSeq
        elseif name == "base_cycle" or name == "deployed_cycle" then
            mapped = seq
        else
            mapped = false
        end

        map[seq] = mapped
    end

    if mapped then return mapped, true end

    return seq, false
end

local function syncModel(wep, tpik, state)
    local seq, start, startCycle, rate = SANDTPIK.GetAnimState(wep)

    if not seq or seq < 0 or seq >= tpik:GetSequenceCount() then
        seq, start, startCycle, rate = state.idleSeq, CurTime(), 0, 1
    end

    local cycling
    seq, cycling = hipCycle(wep, tpik, state, seq)

    local looping = state.loops[seq]
    if looping == nil then
        looping = SANDTPIK.IsLooping(tpik, seq)
        state.loops[seq] = looping
    end

    local prev = tpik:GetSequence()
    if prev ~= seq then
        local blendIn = state.posed and wep.GetSeqBlendIn and wep:GetSeqBlendIn(tpik, seq, prev)

        if isnumber(blendIn) and blendIn > 0 then
            snapshot(tpik, state)

            local blend = state.blendInfo or {}
            state.blendInfo = blend
            blend.start, blend.dur = RealTime(), blendIn
            state.blend = blend
        else
            state.blend = nil
        end

        tpik:SetSequence(seq)
    end

    tpik:SetCycle(SANDTPIK.CycleAt(tpik, seq, start, startCycle, rate, CurTime(), looping))
    tpik:SetPlaybackRate(0)

    if wep.ApplyVMBodygroups then wep:ApplyVMBodygroups(tpik) end
    if wep.ApplyVMPoseParams then wep:ApplyVMPoseParams(tpik) end
    if wep.ApplyGripWeight then wep:ApplyGripWeight(tpik) end
    if wep.ApplyCoverPose then wep:ApplyCoverPose(tpik) end
    if wep.ApplyGLRound then wep:ApplyGLRound(tpik) end
end

local EMPTY = {}

local function applyPose(pos, ang, right, fwd, up, offset, rot, weight)
    if weight <= 0 or not offset then return pos end
    rot = rot or angle_zero

    ang:RotateAroundAxis(right, rot.p * weight)
    ang:RotateAroundAxis(up, rot.y * weight)
    ang:RotateAroundAxis(fwd, rot.r * weight)

    return pos + right * (offset.x * weight) + fwd * (offset.y * weight) + up * (offset.z * weight)
end

local function animSeqExists(wep, tpik, name)
    local entry = wep.GetAnimEntry and wep:GetAnimEntry(name)
    if not istable(entry) then return false end

    local seq = entry.Seq
    if istable(seq) then seq = seq[1] end
    if not isstring(seq) then return false end

    local id = tpik:LookupSequence(seq)

    return id ~= nil and id >= 0
end

local function usesSprintAnims(wep, tpik, state)
    local att = wep:GetAttData()
    local gl = wep.GetGLMode and wep:GetGLMode() or false
    if state.sprintAtt == att and state.sprintGL == gl then return state.sprintAnims end

    state.sprintAtt, state.sprintGL = att, gl
    state.sprintAnims = animSeqExists(wep, tpik, "sprint")
        and animSeqExists(wep, tpik, "sprint_in")
        and animSeqExists(wep, tpik, "sprint_out")

    return state.sprintAnims
end

local function eyeOrigin(ply)
    local offset = ply.SandTPIK_EyeOffset
    if offset and FrameNumber() - (ply.SandTPIK_EyeFrame or -10) <= 2 then
        return (LocalToWorld(offset, angle_zero, ply:GetPos(), ply:GetRenderAngles()))
    end

    return ply:EyePos()
end

local function limitedEye(ply, safe)
    local eye = ply:EyeAngles()
    local limit = Lerp(safe or 0, SANDTPIK.PitchLimit, SANDTPIK.SafePitchLimit)

    return Angle(mathClamp(math.NormalizeAngle(eye.p), -limit, limit), eye.y, 0)
end

local function computePose(wep, ply, tpik, state)
    local origin = eyeOrigin(ply)
    local ang = limitedEye(ply, smooth(state.safe or 0))
    local right, fwd, up = ang:Right(), ang:Forward(), ang:Up()

    local aimT = smooth(mathClamp(wep.GetAimProgress and wep:GetAimProgress() or 0, 0, 1))
    state.aimT = aimT

    local offsets = istable(wep.TPIKOffset) and wep.TPIKOffset or EMPTY
    local defaults = PISTOL_HOLDTYPES[wep:GetHoldType()] and SANDTPIK.PistolOffset or SANDTPIK.DefaultOffset
    local hipPos = offsets.Pos or defaults.Pos
    local hipAng = offsets.Ang or defaults.Ang
    local aimPos = offsets.AimPos or defaults.AimPos
    local hipWeight = 1 - aimT

    local offsetX = hipPos.x * hipWeight + aimPos.x * aimT
    local offsetY = hipPos.y * hipWeight + aimPos.y * aimT
    local offsetZ = hipPos.z * hipWeight + aimPos.z * aimT
    local pos = origin + fwd * offsetX + right * offsetY + up * offsetZ

    if hipWeight > 0 then
        ang:RotateAroundAxis(right, hipAng.p * hipWeight)
        ang:RotateAroundAxis(up, hipAng.y * hipWeight)
        ang:RotateAroundAxis(fwd, hipAng.r * hipWeight)
    end

    if aimT > 0 then
        local blended = wep.GetBlendedSight and wep:GetBlendedSight()
        local sight = (istable(blended) and blended.Pos) and blended
            or (wep.GetActiveSight and wep:GetActiveSight())

        if istable(sight) then
            pos = applyPose(pos, ang, right, fwd, up, sight.Pos, sight.Ang, aimT)
        end
    end

    local reloading = wep.IsReloading and wep:IsReloading()
    local lowered = wep.IsSafe and wep:IsSafe() and not reloading
    local fadeTime = lowered and (wep.SafeLowerTime or 0.35) or (wep.SafeRaiseTime or 0.3)
    local target = lowered and 1 or 0
    state.safe = SandSwep.Math.Lerp(state.safe or target, target, fadeTime)

    local sprintVis = mathClamp(wep.GetSprintProgress and wep:GetSprintProgress() or 0, 0, 1)
    local sprintPoseT = usesSprintAnims(wep, tpik, state) and 0 or smooth(sprintVis)
    local safeT = smooth(state.safe) * (1 - sprintVis)

    pos = applyPose(pos, ang, right, fwd, up, offsets.SafePos or defaults.SafePos, offsets.SafeAng or defaults.SafeAng, safeT)
    pos = applyPose(pos, ang, right, fwd, up, wep.SprintPos, wep.SprintAng, sprintPoseT)

    return pos, ang
end

local limbCache = {}

local function measureLimbs(ply)
    local mdl = ply:GetModel() or ""
    local cached = limbCache[mdl]
    if cached then return cached end

    local fallback = SANDTPIK.DefaultLimbLength
    local out = { upper = fallback, fore = fallback }
    local ref = ClientsideModel(mdl, RENDERGROUP_OPAQUE)

    if IsValid(ref) then
        ref:SetNoDraw(true)
        ref:SetPos(vector_origin)
        ref:SetAngles(angle_zero)
        ref:ResetSequence(0)
        ref:SetCycle(0)
        ref:SetPlaybackRate(0)
        ref:InvalidateBoneCache()
        ref:SetupBones()

        local bones = SANDTPIK.ArmBones.Left
        local upperIdx = ref:LookupBone(bones.UpperArm)
        local foreIdx = ref:LookupBone(bones.Forearm)
        local handIdx = ref:LookupBone(bones.Hand)
        local upperMat = upperIdx and upperIdx >= 0 and entityGetBoneMatrix(ref, upperIdx)
        local foreMat = foreIdx and foreIdx >= 0 and entityGetBoneMatrix(ref, foreIdx)
        local handMat = handIdx and handIdx >= 0 and entityGetBoneMatrix(ref, handIdx)

        if upperMat and foreMat then
            local len = upperMat:GetTranslation():Distance(foreMat:GetTranslation())
            if len > 0 then out.upper = len end
        end

        if foreMat and handMat then
            local len = foreMat:GetTranslation():Distance(handMat:GetTranslation())
            if len > 0 then out.fore = len end
        end

        local head = ref:LookupBone(SANDTPIK.HeadBone)
        local headMat = head and head >= 0 and entityGetBoneMatrix(ref, head)
        local eyes = ref:LookupAttachment("eyes")
        local att = eyes and eyes > 0 and ref:GetAttachment(eyes)

        if headMat and att then
            out.eyeLocal = WorldToLocal(att.Pos, angle_zero, headMat:GetTranslation(), headMat:GetAngles())
        end

        ref:Remove()
    end

    limbCache[mdl] = out

    return out
end

local ELBOW_OUT = 0.4
local ELBOW_DOWN = 0.9
local LEFT_ELBOW = Vector(0.317, 0.423, -0.849)
local HAND_DROP_START = -2
local HAND_DROP_END = 6
local TWIST_WEIGHT = 0.5
local TWIST_LIMIT = 180
local TWIST_RESET_FRAMES = 5
local cvUlnaWeight = CreateClientConVar("cl_sandswep_tpik_ulna_twist", "0.5", true, false, "Share of the hand roll carried by the forearm twist bone", 0, 1)

local function rotateOnto(x, y, z, w, fx, fy, fz, tx, ty, tz)
    fx, fy, fz = Unit(fx, fy, fz)
    tx, ty, tz = Unit(tx, ty, tz)

    local cos = fx * tx + fy * ty + fz * tz
    local ax, ay, az, sin = Unit(fy * tz - fz * ty, fz * tx - fx * tz, fx * ty - fy * tx)
    if sin < 1e-6 then
        if cos > 0 then return x, y, z, w end
        ax, ay, az = QuatRotate(x, y, z, w, 0, 0, 1)
        sin = 0
    end

    local qx, qy, qz, qw = QuatAxisAngle(ax, ay, az, math.atan2(sin, cos))
    return QuatMul(qx, qy, qz, qw, x, y, z, w)
end

local HINGE_MIN_SIN = 0.05
local HINGE_FULL_SIN = 0.2

local function bendSin(ax, ay, az, bx, by, bz)
    local la, lb = mathSqrt(ax * ax + ay * ay + az * az), mathSqrt(bx * bx + by * by + bz * bz)
    if la < 1e-6 or lb < 1e-6 then return 0 end

    local cx, cy, cz = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
    return mathSqrt(cx * cx + cy * cy + cz * cz) / (la * lb)
end

local function hingeWeight(sin)
    return mathClamp((sin - HINGE_MIN_SIN) / (HINGE_FULL_SIN - HINGE_MIN_SIN), 0, 1)
end

local function alignHinge(x, y, z, w, animX, animY, animZ, animW, auX, auY, auZ, afX, afY, afZ, uX, uY, uZ, fX, fY, fZ)
    local weight = math.min(hingeWeight(bendSin(auX, auY, auZ, afX, afY, afZ)), hingeWeight(bendSin(uX, uY, uZ, fX, fY, fZ)))
    if weight <= 0 then return x, y, z, w end

    local ax, ay, az = Unit(uX, uY, uZ)
    local lx, ly, lz = QuatRotate(-animX, -animY, -animZ, animW, auY * afZ - auZ * afY, auZ * afX - auX * afZ, auX * afY - auY * afX)
    local cx, cy, cz = QuatRotate(x, y, z, w, lx, ly, lz)
    local tx, ty, tz = uY * fZ - uZ * fY, uZ * fX - uX * fZ, uX * fY - uY * fX

    local dot = cx * ax + cy * ay + cz * az
    cx, cy, cz = cx - ax * dot, cy - ay * dot, cz - az * dot
    dot = tx * ax + ty * ay + tz * az
    tx, ty, tz = tx - ax * dot, ty - ay * dot, tz - az * dot
    if cx * cx + cy * cy + cz * cz < 1e-8 or tx * tx + ty * ty + tz * tz < 1e-8 then return x, y, z, w end

    cx, cy, cz = Unit(cx, cy, cz)
    tx, ty, tz = Unit(tx, ty, tz)

    local roll = math.atan2(ax * (cy * tz - cz * ty) + ay * (cz * tx - cx * tz) + az * (cx * ty - cy * tx), cx * tx + cy * ty + cz * tz)
    local qx, qy, qz, qw = QuatAxisAngle(ax, ay, az, roll * weight)
    return QuatMul(qx, qy, qz, qw, x, y, z, w)
end

local function setRotation(mat, x, y, z, w)
    local _, _, _, tx, _, _, _, ty, _, _, _, tz = mat:Unpack()
    MATH.QuatToMatrix(mat, x, y, z, w, tx, ty, tz)
end

local function twistToward(side, x, y, z, w, axisDir, targetUp)
    local ax, ay, az = Unit(axisDir.x, axisDir.y, axisDir.z)
    local cx, cy, cz = QuatRotate(x, y, z, w, 0, 0, 1)
    local tx, ty, tz = targetUp.x, targetUp.y, targetUp.z

    local dot = cx * ax + cy * ay + cz * az
    cx, cy, cz = cx - ax * dot, cy - ay * dot, cz - az * dot
    dot = tx * ax + ty * ay + tz * az
    tx, ty, tz = tx - ax * dot, ty - ay * dot, tz - az * dot
    if cx * cx + cy * cy + cz * cz < 1e-8 or tx * tx + ty * ty + tz * tz < 1e-8 then return x, y, z, w end

    cx, cy, cz = Unit(cx, cy, cz)
    tx, ty, tz = Unit(tx, ty, tz)

    local cross = ax * (cy * tz - cz * ty) + ay * (cz * tx - cx * tz) + az * (cx * ty - cy * tx)
    local twist = math.deg(math.atan2(cross, cx * tx + cy * ty + cz * tz))
    local frame = FrameNumber()
    local last = side.poleTwist

    if last and frame - (side.poleTwistFrame or 0) <= TWIST_RESET_FRAMES then
        twist = twist + 360 * math.Round((last - twist) / 360)
    end

    twist = mathClamp(twist, -TWIST_LIMIT, TWIST_LIMIT)
    side.poleTwist, side.poleTwistFrame = twist, frame
    side.ulnaTwist = twist

    local qx, qy, qz, qw = QuatAxisAngle(ax, ay, az, math.rad(twist * cvUlnaWeight:GetFloat()))
    return QuatMul(qx, qy, qz, qw, x, y, z, w)
end

local dump

local function dumpVec(v)
    return { v.x, v.y, v.z }
end

local function dumpAng(a)
    return { a.p, a.y, a.r }
end

local function recordArm(ply, bones, row)
    if not dump or ply ~= LocalPlayer() then return end

    if RealTime() > dump.until_ then
        local name = "sandswep_tpik_dump_" .. os.date("%H%M%S") .. ".json"
        file.Write(name, util.TableToJSON(dump.data))
        print("[sandswep_tpik] wrote " .. #dump.data.frames .. " frames to data/" .. name)
        dump = nil
        return
    end

    local clavicle = getBone(ply, bones == SANDTPIK.ArmBones.Left and "ValveBiped.Bip01_L_Clavicle" or "ValveBiped.Bip01_R_Clavicle")
    local clavMat = clavicle and entityGetBoneMatrix(ply, clavicle)
    local wep = ply:GetActiveWeapon()
    local tpik = IsValid(wep) and wep.SandTPIK_Model

    row.frame = FrameNumber()
    row.time = RealTime()
    row.seq = IsValid(tpik) and tpik:GetSequenceName(tpik:GetSequence()) or ""
    row.cycle = IsValid(tpik) and tpik:GetCycle() or 0
    row.body = dumpAng(ply:GetRenderAngles())
    row.eye = dumpAng(ply:EyeAngles())
    row.pos = dumpVec(ply:GetPos())
    row.clavicle = clavMat and dumpAng(clavMat:GetAngles()) or nil
    row.arm = bones == SANDTPIK.ArmBones.Left and "left" or "right"

    table.insert(dump.data.frames, row)
end

concommand.Add("sandswep_tpik_dump", function(_, _, args)
    local ply = LocalPlayer()
    local seconds = tonumber(args[1]) or 4
    local bones = {}

    for i = 0, ply:GetBoneCount() - 1 do
        bones[#bones + 1] = { i, ply:GetBoneName(i), ply:GetBoneParent(i) }
    end

    dump = { until_ = RealTime() + seconds, data = { model = ply:GetModel(), bones = bones, frames = {} } }
    print("[sandswep_tpik] recording the left arm for " .. seconds .. " seconds")
end)

local armUpper, armFore, armHand, armUlna = Matrix(), Matrix(), Matrix(), Matrix()

local function solveArmPole(ply, side, bones, outward, limbUpper, limbFore, scale, gunAng)
    local upperIdx = getBone(ply, bones.UpperArm)
    local foreIdx = getBone(ply, bones.Forearm)
    local handIdx = getBone(ply, bones.Hand)
    if not upperIdx or not foreIdx or not handIdx then return false end

    local upperMat = copyBone(ply, upperIdx, armUpper)
    local foreMat = copyBone(ply, foreIdx, armFore)
    local handMat = copyBone(ply, handIdx, armHand)
    if not upperMat or not foreMat or not handMat then return false end

    local rootPos = upperMat:GetTranslation()
    local targetPos = handMat:GetTranslation()
    local gunLocked = bones == SANDTPIK.ArmBones.Left

    local frame = gunLocked and gunAng or ply:GetRenderAngles()
    local frameRight, frameUp = frame:Right(), frame:Up()
    local bodyDir = frameRight * (ELBOW_OUT * outward) - frameUp * ELBOW_DOWN
    local poleDir = gunLocked
        and frame:Forward() * LEFT_ELBOW.x + frameRight * (LEFT_ELBOW.y * outward) + frameUp * LEFT_ELBOW.z
        or foreMat:GetTranslation() - rootPos

    local drop = -(targetPos - rootPos):Dot(frameUp)
    local bodyWeight = smooth(mathClamp((drop - HAND_DROP_START) / (HAND_DROP_END - HAND_DROP_START), 0, 1))

    local elbowPos, handPos = SANDTPIK.SolvePoleIK(rootPos, targetPos, poleDir,
        bodyDir, bodyWeight, limbUpper * scale, limbFore * scale)

    local upperDir, foreDir = elbowPos - rootPos, handPos - elbowPos

    local animX, animY, animZ, animW = QuatFromMatrix(upperMat)
    local auX, auY, auZ = QuatRotate(animX, animY, animZ, animW, 1, 0, 0)
    local foreX, foreY, foreZ, foreW = QuatFromMatrix(foreMat)
    local afX, afY, afZ = QuatRotate(foreX, foreY, foreZ, foreW, 1, 0, 0)
    local x, y, z, w = rotateOnto(animX, animY, animZ, animW, auX, auY, auZ, upperDir.x, upperDir.y, upperDir.z)
    x, y, z, w = alignHinge(x, y, z, w, animX, animY, animZ, animW, auX, auY, auZ, afX, afY, afZ,
        upperDir.x, upperDir.y, upperDir.z, foreDir.x, foreDir.y, foreDir.z)

    local rx, ry, rz, rw = QuatMul(-animX, -animY, -animZ, animW, foreX, foreY, foreZ, foreW)
    local ox, oy, oz, ow = QuatMul(x, y, z, w, rx, ry, rz, rw)
    local ofX, ofY, ofZ = QuatRotate(ox, oy, oz, ow, 1, 0, 0)
    ox, oy, oz, ow = rotateOnto(ox, oy, oz, ow, ofX, ofY, ofZ, foreDir.x, foreDir.y, foreDir.z)

    if dump then
        recordArm(ply, bones, {
            root = dumpVec(rootPos), animElbow = dumpVec(foreMat:GetTranslation()), target = dumpVec(handMat:GetTranslation()),
            elbow = dumpVec(elbowPos), hand = dumpVec(handPos), bodyDir = dumpVec(bodyDir), bodyWeight = bodyWeight,
            upperAnim = dumpAng(upperMat:GetAngles()), upperNew = { MATH.QuatToAngles(x, y, z, w) },
            foreAnim = dumpAng(foreMat:GetAngles()), foreNew = { MATH.QuatToAngles(ox, oy, oz, ow) }, handAng = dumpAng(handMat:GetAngles()),
            twist = side.poleTwist, ulnaTwist = side.ulnaTwist, limbs = { limbUpper * scale, limbFore * scale },
        })
    end

    setRotation(upperMat, x, y, z, w)
    setRotation(foreMat, ox, oy, oz, ow)
    foreMat:SetTranslation(elbowPos)

    applyBoneMatrix(ply, upperIdx, upperMat, foreIdx)
    applyBoneMatrix(ply, foreIdx, foreMat, handIdx)

    local ulnaIdx = bones.Ulna and getBone(ply, bones.Ulna)
    local ulnaMat = ulnaIdx and copyBone(ply, ulnaIdx, armUlna)
    if ulnaMat then
        local x, y, z, w = QuatFromMatrix(ulnaMat)
        setRotation(ulnaMat, twistToward(side, x, y, z, w, foreDir, handMat:GetUp()))
        applyBoneMatrix(ply, ulnaIdx, ulnaMat, handIdx)
    end

    return true
end

local function shouldDropLeftHand(ply, wep)
    if wep.TPIKForceLeftHand then return false end
    if ply:IsTyping() then return true end

    return wep.TPIKNoLeftHand == true
end

local function handMap(ply, tpik, state)
    local plyModel, tpikModel = ply:GetModel(), tpik.SandTPIK_Path
    local map = state.handMap
    if map and map.pm == plyModel and map.tm == tpikModel then return map end

    map = {
        pm = plyModel,
        tm = tpikModel,
        src = {},
        dst = {},
        left = {},
        n = 0,
    }

    local names = SANDTPIK.HandBones
    local leftCount = #SANDTPIK.LeftHandBones

    for i = 1, #names do
        local srcBone, dstBone = getBone(tpik, names[i]), getBone(ply, names[i])
        if srcBone and dstBone then
            map.n = map.n + 1
            map.src[map.n], map.dst[map.n], map.left[map.n] = srcBone, dstBone, i <= leftCount
        end
    end

    state.handMap = map

    return map
end

local handScale = Vector(1, 1, 1)

local spineScratch, headScratch = Matrix(), Matrix()

local function applyToPlayer(ply, numBones)
    local data = ply.SandTPIK_Active
    if not data then return end

    local frame = FrameNumber()
    if frame - data.frame > 1 then return end

    local wep, tpik = data.wep, data.tpik
    if not IsValid(wep) or not IsValid(tpik) then return end
    if ply:GetActiveWeapon() ~= wep then return end

    local state = wep.SandTPIK_State
    if not state then return end

    local map = handMap(ply, tpik, state)
    if map.n == 0 then
        data.copied = 0
        return
    end

    local spineIdx = getBone(ply, SANDTPIK.SpineBone) or getBone(ply, "ValveBiped.Bip01_Spine2")
    local spineMat = spineIdx and copyBone(ply, spineIdx, spineScratch)
    local spinePos = spineMat and spineMat:GetTranslation() or ply:GetPos() + Vector(0, 0, 48)
    local spineX, spineY, spineZ = spinePos.x, spinePos.y, spinePos.z
    local clamp = SANDTPIK.BoneClamp
    local dropLeft = data.dropLeft
    local src, dst, left = map.src, map.dst, map.left

    local modelScale = ply:GetModelScale()
    local scaled = modelScale ~= 1
    if scaled then handScale:SetUnpacked(modelScale, modelScale, modelScale) end

    local copied = 0
    for k = 1, map.n do
        if dropLeft and left[k] then continue end

        local mat = copyBone(tpik, src[k], boneMat)
        if not mat or not copyBone(ply, dst[k], localMat) then continue end

        local bonePos = mat:GetTranslation()
        bonePos.x = mathClamp(bonePos.x, spineX - clamp, spineX + clamp)
        bonePos.y = mathClamp(bonePos.y, spineY - clamp, spineY + clamp)
        bonePos.z = mathClamp(bonePos.z, spineZ - clamp, spineZ + clamp)

        mat:SetTranslation(bonePos)
        if scaled then mat:SetScale(handScale) end
        entitySetBoneMatrix(ply, dst[k], mat)
        copied = copied + 1
    end

    data.copied = copied
    if copied == 0 then return end

    solveArmPole(ply, state.right, SANDTPIK.ArmBones.Right, 1, state.limbUpper, state.limbFore, modelScale, data.eyeAng)
    if not dropLeft then
        solveArmPole(ply, state.left, SANDTPIK.ArmBones.Left, -1, state.limbUpper, state.limbFore, modelScale, data.eyeAng)
    end

    local eyeLocal = state.eyeLocal
    local headIdx = eyeLocal and getBone(ply, SANDTPIK.HeadBone)
    local headMat = headIdx and copyBone(ply, headIdx, headScratch)

    if headMat then
        ply.SandTPIK_EyeOffset = WorldToLocal(headMat * eyeLocal, angle_zero, ply:GetPos(), ply:GetRenderAngles())
        ply.SandTPIK_EyeFrame = frame
    end
end

local function ensurePlayerCallback(ply)
    if ply.SandTPIK_CB and ply.SandTPIK_CBModel == ply:GetModel() then return end

    if ply.SandTPIK_CB then ply:RemoveCallback("BuildBonePositions", ply.SandTPIK_CB) end

    ply.SandTPIK_CBModel = ply:GetModel()
    ply.SandTPIK_CB = ply:AddCallback("BuildBonePositions", function(ent, numBones)
        local ok, err = pcall(applyToPlayer, ent, numBones)
        if not ok then ErrorNoHalt("[sandswep_tpik] " .. tostring(err) .. "\n") end
    end)
end

local function isDetailed(ply, isLocal)
    if isLocal then return true end

    local lod = cfg.lod
    return lod <= 0 or EyePos():DistToSqr(ply:GetPos()) <= lod * lod
end

function SANDTPIK.Solve(ply, wep)
    local tpik = ensureModel(wep)
    if not IsValid(tpik) then return end

    local state = wep.SandTPIK_State
    setShimmed(wep, true)
    ensurePlayerCallback(ply)

    local plyModel = ply:GetModel()
    if not state.limbUpper or state.limbModel ~= plyModel then
        local limbs = measureLimbs(ply)
        state.limbUpper = limbs.upper
        state.limbFore = limbs.fore
        state.eyeLocal = limbs.eyeLocal
        state.limbModel = plyModel
    end

    local isLocal = ply == LocalPlayer()
    state.detailed = isDetailed(ply, isLocal)

    syncModel(wep, tpik, state)

    local pos, ang = computePose(wep, ply, tpik, state)
    tpik:SetPos(pos)
    tpik:SetAngles(ang)
    tpik:InvalidateBoneCache()
    tpik:SetupBones()
    state.posed = true

    hideParkedProps(wep, tpik, state)
    SANDTPIK.SyncAttachments(wep, tpik, state)

    local data = ply.SandTPIK_Active
    if not data then
        data = {}
        ply.SandTPIK_Active = data
    end

    data.wep, data.tpik, data.frame = wep, tpik, FrameNumber()
    data.dropLeft = shouldDropLeftHand(ply, wep)
    data.eyeAng = limitedEye(ply, smooth(state.safe or 0))

    if not wep.SandTPIK_Warned and handMap(ply, tpik, state).n == 0 then
        wep.SandTPIK_Warned = true
        print("[sandswep_tpik] " .. tostring(wep.ViewModel) .. " has no ValveBiped hand bones, arms can't follow it")
    end

    ply:InvalidateBoneCache()
    ply:SetupBones()
end

concommand.Add("sandswep_tpik_debug", function()
    local ply = LocalPlayer()
    local wep = IsValid(ply) and ply:GetActiveWeapon()
    local data = IsValid(ply) and ply.SandTPIK_Active

    print("[sandswep_tpik] weapon:", wep, "mirror:", IsValid(wep) and wep.SandTPIK_Model or nil)
    print("  player model:", IsValid(ply) and ply:GetModel(), "callback:", IsValid(ply) and ply.SandTPIK_CB)
    print("  frames since solve:", data and (FrameNumber() - data.frame) or "never",
        "hand bones copied to player:", data and data.copied or 0)
end)

function SANDTPIK.ShouldRun(ply, wep)
    if not cfg.enabled then return false end
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if not ply:Alive() or ply:InVehicle() then return false end
    if not SANDTPIK.IsSandWeapon(wep) or wep.NoTPIK then return false end
    if wep:IsDormant() then return false end

    if ply ~= LocalPlayer() then
        if not cfg.others then return false end

        local limit = cfg.distance
        if limit > 0 and EyePos():DistToSqr(ply:GetPos()) > limit * limit then return false end
    end

    if wep.GetSprinting and wep:GetSprinting() then return false end

    if hook.Run("SandTPIK_ShouldRun", ply, wep) == false then return false end

    return true
end

hook.Add("DoAnimationEvent", "SandTPIK.Gestures", function(ply, event)
    if event ~= PLAYERANIMEVENT_ATTACK_PRIMARY and event ~= PLAYERANIMEVENT_RELOAD then return end

    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and IsValid(wep.SandTPIK_Model) then return ACT_INVALID end
end)

local PISTOL_TO_REVOLVER = {}
for _, motion in ipairs({ "IDLE", "WALK", "RUN", "IDLE_CROUCH", "WALK_CROUCH", "JUMP", "SWIM", "SWIM_IDLE" }) do
    local pistolAct = _G["ACT_HL2MP_" .. motion .. "_PISTOL"]
    local revolverAct = _G["ACT_HL2MP_" .. motion .. "_REVOLVER"]
    if pistolAct and revolverAct then PISTOL_TO_REVOLVER[pistolAct] = revolverAct end
end

hook.Add("TranslateActivity", "SandTPIK.PistolPose", function(ply, act)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not IsValid(wep.SandTPIK_Model) then return end
    if wep:GetHoldType() ~= "pistol" then return end

    local target = PISTOL_TO_REVOLVER[ply:TranslateWeaponActivity(act)]
    if target then return target end
end)

hook.Add("PrePlayerDraw", "SandTPIK", function(ply, flags)
    if not IsValid(ply) then return end

    local frame = FrameNumber()
    if ply.SandTPIK_Frame == frame then return end
    ply.SandTPIK_Frame = frame

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then
        if IsValid(ply.SandTPIK_Weapon) then removeModel(ply.SandTPIK_Weapon) end
        ply.SandTPIK_Weapon = nil
        return
    end

    if ply.SandTPIK_Weapon ~= wep then
        if IsValid(ply.SandTPIK_Weapon) then removeModel(ply.SandTPIK_Weapon) end
        ply.SandTPIK_Weapon = wep
    end

    if not SANDTPIK.ShouldRun(ply, wep) then
        if not wep.SandTPIK_Model then return end

        local since = wep.SandTPIK_BlockedAt
        if not since then
            since = CurTime()
            wep.SandTPIK_BlockedAt = since
        end

        if not IsValid(wep.SandTPIK_Model) or CurTime() - since >= SANDTPIK.BlockGrace then
            removeModel(wep)
            return
        end
    else
        wep.SandTPIK_BlockedAt = nil
    end

    local ok, err = pcall(SANDTPIK.Solve, ply, wep)
    if not ok then
        ErrorNoHalt("[sandswep_tpik] " .. tostring(err) .. "\n")
        removeModel(wep)
        wep.NoTPIK = true
    end
end)

local REF_TAN = math.tan(math.rad(37.5))

local viewTan, viewTanFrame, viewTanPIP

local function viewTangent()
    local frame, pip = FrameNumber(), SandSwep.RenderingPIP == true
    if viewTanFrame ~= frame or viewTanPIP ~= pip then
        local view = render.GetViewSetup()
        viewTan = math.tan(math.rad((view and view.fov or 75) * 0.5))
        viewTanFrame, viewTanPIP = frame, pip
    end

    return viewTan
end

function SANDTPIK.MeshLOD(ent)
    local mesh1, mesh2 = cfg.mesh1, cfg.mesh2
    if mesh1 <= 0 and mesh2 <= 0 then return 0 end

    local dist = EyePos():Distance(ent:GetPos())
        * viewTangent()
        / REF_TAN

    if mesh2 > 0 and dist > mesh2 then return 2 end
    if mesh1 > 0 and dist > mesh1 then return 1 end

    return 0
end

local DEPTH_PASS = bit.bor(STUDIO_SHADOWDEPTHTEXTURE or 0, STUDIO_SSAODEPTHTEXTURE or 0)

hook.Add("PostPlayerDraw", "SandTPIK", function(ply, flags)
    if not IsValid(ply) then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return end

    local tpik = wep.SandTPIK_Model
    if not IsValid(tpik) then return end

    tpik:SetLOD(SANDTPIK.MeshLOD(tpik))
    tpik:DrawModel(flags)

    local state = wep.SandTPIK_State
    if state then SANDTPIK.DrawAttachments(wep, tpik, state, flags) end

    if render.RenderFlashlights and bit.band(flags or 0, DEPTH_PASS) == 0 then
        render.RenderFlashlights(function()
            tpik:DrawModel(flags)
            if state then SANDTPIK.DrawAttachments(wep, tpik, state, flags) end
        end)
    end
end)

hook.Add("EntityRemoved", "SandTPIK", function(ent)
    if ent.SandTPIK_Model or ent.SandTPIK_Shims then removeModel(ent) end
end)

local function rebuildMirrors()
    for _, ply in player.Iterator() do
        if IsValid(ply.SandTPIK_Weapon) then removeModel(ply.SandTPIK_Weapon) end
    end
end

cvars.AddChangeCallback("sandswep_tpik", rebuildMirrors, "SandTPIK")
