local VisualFrameTime = SandSwep.VisualFrameTime

if not CLIENT then return end

local cvHandScale = CreateClientConVar("cl_sandswep_handscale", "0.86", true, false, "Hand size on Sandstorm viewmodels", 0.7, 1.1)

local ONE = Vector(1, 1, 1)
local ZERO = Vector(0, 0, 0)
local SHOT_BONE_CURVE = { 0, 0, 0, 0, 0.5, 1, 0.843, 0.5, 0.156, 0, 0.061, 0.176, 0.239, 0.176,
    0.061, 0, 0.016, 0.046, 0.063, 0.046, 0.016, 0 }

local HAND_BONES = { L = {}, R = {} }
for side, list in pairs(HAND_BONES) do
    list[#list + 1] = "ValveBiped.Bip01_" .. side .. "_Hand"
    for finger = 0, 4 do
        for _, segment in ipairs({ "", "1", "2" }) do
            list[#list + 1] = "ValveBiped.Bip01_" .. side .. "_Finger" .. finger .. segment
        end
    end
end

local function ClearHandScale(vm)
    local cur = vm.SandSwepHandScale
    if not cur then return end

    for id in pairs(cur.ids) do vm:ManipulateBoneScale(id, ONE) end
    vm.SandSwepHandScale = nil
end
SandSwep.ClearHandScale = ClearHandScale

local WRIST_BONES = { "ValveBiped.Bip01_L_Wrist", "ValveBiped.Bip01_R_Wrist" }

local function UnsquashWrists(hands)
    local ply = LocalPlayer()
    local vm = IsValid(ply) and ply:GetViewModel()
    if not IsValid(vm) or not vm.SandSwepHandScale then return end

    local model = hands:GetModel()
    local ids = hands.SandSwepWrists
    if not ids or ids.model ~= model then
        ids = { model = model }
        for _, name in ipairs(WRIST_BONES) do ids[#ids + 1] = hands:LookupBone(name) end
        hands.SandSwepWrists = ids
    end

    for _, id in ipairs(ids) do
        local mat = hands:GetBoneMatrix(id)
        if mat then
            mat:SetScale(ONE)
            hands:SetBoneMatrix(id, mat)
        end
    end
end

local function HookWrists(ply)
    local hands = IsValid(ply) and ply.GetHands and ply:GetHands()
    if not IsValid(hands) or hands.SandSwepWristHook then return end

    hands.SandSwepWristHook = hands:AddCallback("BuildBonePositions", UnsquashWrists)
end

local forearmRest = {}

local function ForearmRest(model)
    local rest = forearmRest[model]
    if rest ~= nil then return rest or nil end

    rest = false
    local ent = ClientsideModel(model, RENDERGROUP_OTHER)
    if IsValid(ent) then
        ent:SetupBones()
        rest = {}
        for _, side in ipairs({ "L", "R" }) do
            local fore = ent:LookupBone("ValveBiped.Bip01_" .. side .. "_Forearm")
            local hand = ent:LookupBone("ValveBiped.Bip01_" .. side .. "_Hand")
            local a = fore and ent:GetBoneMatrix(fore)
            local b = hand and ent:GetBoneMatrix(hand)
            if a and b then rest[side] = a:GetTranslation():Distance(b:GetTranslation()) end
        end
        ent:Remove()
    end

    forearmRest[model] = rest
    return rest or nil
end

function SWEP:VMForearmFit(vm)
    if self.NoHandScale then return end

    local ply = LocalPlayer()
    local hands = IsValid(ply) and ply:GetHands()
    if not IsValid(hands) or hands:GetParent() ~= vm then return end

    local rest = ForearmRest(hands:GetModel())
    if not rest then return end

    local weights = SandSwep.AnimatedHands and SandSwep.AnimatedHands() or {}

    for side, length in pairs(rest) do
        local w = weights[side] or 1
        local fore = vm:LookupBone("ValveBiped.Bip01_" .. side .. "_Forearm")
        local hand = vm:LookupBone("ValveBiped.Bip01_" .. side .. "_Hand")
        local a = fore and vm:GetBoneMatrix(fore)
        local b = hand and vm:GetBoneMatrix(hand)
        if a and b and length > 0.01 and w > 0 then
            local fit = a:GetTranslation():Distance(b:GetTranslation()) / length
            local stretch = 1 + (fit - 1) * w
            local sc = a:GetScale()
            a:SetScale(Vector(stretch, sc.y, sc.z))
            vm:SetBoneMatrix(fore, a)
        end
    end
end

function SWEP:ApplyHandScale(vm)
    if self.NoHandScale then
        ClearHandScale(vm)
        return
    end

    HookWrists(self:GetOwner())

    local rest = SandSwep.AnimatedHands and SandSwep.AnimatedHands() or {}
    local weight = { L = math.Round(rest.L or 1, 3), R = math.Round(rest.R or 1, 3) }
    local scale = cvHandScale:GetFloat() * (self.HandScaleMul or 1)
    local key = vm:GetModel() .. "|" .. scale .. "|" .. weight.L .. "|" .. weight.R
    if vm.SandSwepHandScale and vm.SandSwepHandScale.key == key then return end

    ClearHandScale(vm)

    local ids = {}
    for side, list in pairs(HAND_BONES) do
        local s = 1 + (scale - 1) * weight[side]
        local uniform = Vector(s, s, s)
        for _, name in ipairs(list) do
            local id = vm:LookupBone(name)
            if id then
                vm:ManipulateBoneScale(id, uniform)
                ids[id] = true
            end
        end
    end

    vm.SandSwepHandScale = { key = key, ids = ids }
end

local function ClearGLRound(vm)
    local cur = vm.SandSwepGLRound
    if not cur then return end

    if cur.id and cur.hidden then vm:ManipulateBoneScale(cur.id, ONE) end
    vm.SandSwepGLRound = nil
end
SandSwep.ClearGLRound = ClearGLRound

local function SeqMatches(seq, list)
    for _, pat in ipairs(list or {}) do
        if string.find(seq, pat) then return true end
    end
    return false
end

local function ScaleBone(vm, cur, id, hide)
    if hide == (cur.hidden[id] == true) then return end

    vm:ManipulateBoneScale(id, hide and ZERO or ONE)
    cur.hidden[id] = hide or nil
end

local function ResetHidden(vm, cur)
    if not cur then return end

    for id in pairs(cur.hidden) do vm:ManipulateBoneScale(id, ONE) end
end

function SWEP:ApplyParkedBones(vm)
    local cfg = self.ParkedBones
    if not cfg then return end

    local model = vm:GetModel()
    local cur = vm.SandSwepParked
    if not cur or cur.model ~= model or cur.cfg ~= cfg then
        ResetHidden(vm, cur)
        cur = { model = model, cfg = cfg, ids = {}, hidden = {} }
        for i, entry in ipairs(cfg) do cur.ids[i] = vm:LookupBone(entry.Bone) end
        vm.SandSwepParked = cur
    end

    local seq = vm:GetSequence()
    if cur.seq ~= seq then
        cur.seq = seq
        cur.name = vm:GetSequenceName(seq) or ""
        cur.windows = {}

        for i, entry in ipairs(cfg) do
            for pattern, window in pairs(entry.Window or {}) do
                if string.find(cur.name, pattern) then cur.windows[i] = window end
            end
        end
    end

    local cycle = vm:GetCycle()
    for i, entry in ipairs(cfg) do
        local id = cur.ids[i]
        if id then
            local hide = (entry.Show and not SeqMatches(cur.name, entry.Show)) or SeqMatches(cur.name, entry.Hide)
            local window = cur.windows[i]
            if window and (cycle < window[1] or cycle > window[2]) then hide = true end
            ScaleBone(vm, cur, id, hide)
        end
    end
end

local selectorLocal, selectorWorld = Matrix(), Matrix()

function SWEP:VMTubeSelector(vm)
    local cfg = self.TubeSelector
    if not cfg then return end

    local bone = vm:LookupBone(cfg.Bone)
    local parent = bone and vm:GetBoneParent(bone)
    local mat = bone and vm:GetBoneMatrix(bone)
    local parentMat = parent and parent >= 0 and vm:GetBoneMatrix(parent)
    if not mat or not parentMat then return end

    selectorLocal:Set(parentMat:GetInverseTR())
    selectorLocal:Mul(mat)

    local second = self:GetTubeSwapped()
    local angle
    if string.find(vm:GetSequenceName(vm:GetSequence()) or "", cfg.Seq) then
        if second then return end
        angle = -math.deg(math.atan2(selectorLocal:GetField(1, 3), selectorLocal:GetField(1, 1)))
    else
        angle = second and cfg.Angle or -cfg.Angle
    end

    local rad = math.rad(angle)
    local c, s = math.cos(rad), math.sin(rad)
    local pos = selectorLocal:GetTranslation()
    selectorLocal:SetUnpacked(c, 0, s, pos.x, 0, 1, 0, pos.y, -s, 0, c, pos.z, 0, 0, 0, 1)

    selectorWorld:Set(parentMat)
    selectorWorld:Mul(selectorLocal)
    vm:SetBoneMatrix(bone, selectorWorld)
end

function SWEP:GetLoadedMagRounds()
    local clip = self:Clip1()
    if self:IsReloading() or not self:IsChambered() then return clip end

    return clip - 1
end

function SWEP:GetLoadedMagCases()
    return #self.MagCaseBones
end

function SWEP:ApplyMagRoundBones(vm)
    local bones = self.MagRoundBones
    if not bones then
        if vm.SandSwepMagRounds then
            ResetHidden(vm, vm.SandSwepMagRounds)
            vm.SandSwepMagRounds = nil
        end
        return
    end

    local cases = self.MagCaseBones
    local model = vm:GetModel()
    local cur = vm.SandSwepMagRounds
    if not cur or cur.model ~= model or cur.cfg ~= bones then
        ResetHidden(vm, cur)
        cur = { model = model, cfg = bones, ids = {}, cids = {}, hidden = {} }
        for i, name in ipairs(bones) do cur.ids[i] = vm:LookupBone(name) end
        for i, name in ipairs(cases or {}) do cur.cids[i] = vm:LookupBone(name) end
        vm.SandSwepMagRounds = cur
    end

    local rounds = self:GetLoadedMagRounds()
    local caseCount = cases and self:GetLoadedMagCases() or 0
    if cur.n == rounds and cur.c == caseCount then return end
    cur.n, cur.c = rounds, caseCount

    for i, id in pairs(cur.ids) do ScaleBone(vm, cur, id, rounds < i or (cases ~= nil and caseCount < i)) end
    for i, id in pairs(cur.cids) do ScaleBone(vm, cur, id, caseCount < i) end
end

local function ClearParked(vm)
    ResetHidden(vm, vm.SandSwepMagRounds)
    vm.SandSwepMagRounds = nil
    ResetHidden(vm, vm.SandSwepParked)
    vm.SandSwepParked = nil
end
SandSwep.ClearParked = ClearParked

function SWEP:GLRoundVisible(vm)
    if not self:GetGLConfig() or self:GetGLLoaded() then return true end
    if not self:IsInAction("glreload") then return false end

    local data = SandSwep.GetSequenceData(self.ViewModel, vm:GetSequenceName(vm:GetSequence()))
    local mark = data and data.marks and data.marks.glround

    return not mark or vm:GetCycle() >= mark
end

function SWEP:ApplyGLRound(vm)
    local model = vm:GetModel()
    local cur = vm.SandSwepGLRound
    if not cur or cur.model ~= model then
        ClearGLRound(vm)
        cur = { model = model, id = vm:LookupBone("b_wpn_gl_round"), hidden = false }
        vm.SandSwepGLRound = cur
    end
    if not cur.id then return end

    local hide = not self:GLRoundVisible(vm)
    if hide ~= cur.hidden then
        vm:ManipulateBoneScale(cur.id, hide and ZERO or ONE)
        cur.hidden = hide
    end
end

local function ShotBoneWeight(cfg, times, now)
    local curve = cfg.Curve or SHOT_BONE_CURVE
    local fps = cfg.FPS or 40

    local weight = 0
    for _, shotTime in ipairs(times) do
        local frame = (now - shotTime) * fps
        if frame >= 0 and frame < #curve - 1 then
            local i = math.floor(frame)
            local value = Lerp(frame - i, curve[i + 1], curve[i + 2])
            if value > weight then weight = value end
        end
    end

    return weight
end

local function LinkCoverBelt(wep, cfg)
    local fed = wep._linkCover and wep._linkCover.fed
    if fed and (wep:IsReloading() or wep:Clip1() <= 0) then fed = false end

    local belt = (wep._beltSim and wep._beltSim.nodes and #wep._beltSim.nodes > 0) or fed
    if not belt and cfg.Loaded == true then
        belt = wep:Clip1() > 0 and not wep:IsReloading() and not wep:IsMagHidden()
    end

    return belt, fed
end

local function OpenKick(cfg)
    return (cfg.OpenKick or 850) * math.Rand(0.95, 1.15)
end

local function KickCover(wep, cover, cfg, belt, rest)
    if belt and not cover.belt and cover.a < rest - 5 then
        cover.v = math.max(cover.v, OpenKick(cfg))
    end

    local shots = wep._shotCount or 0
    if shots > cover.shots then
        local first = cover.a < rest - 5
        cover.v = math.max(cover.v, first and OpenKick(cfg) or (cfg.Kick or 130) * math.Rand(0.75, 1.2))
        cover.shots = shots
    end

    if cover.belt and not belt then cover.v = math.min(cover.v, -(cfg.CloseSpeed or 250)) end
end

local function SimulateCover(cover, cfg, belt, rest, dt)
    local gravity = cfg.Gravity or 3000
    local damping = cfg.Damping or 4
    local maxAngle = cfg.Max or 115

    local steps = math.Clamp(math.ceil(dt / (1 / 120)), 1, 8)
    local stepTime = dt / steps

    for _ = 1, steps do
        cover.v = cover.v - gravity * math.sin(math.rad(cover.a)) * stepTime
        cover.v = cover.v * math.exp(-damping * stepTime)
        cover.a = cover.a + cover.v * stepTime
        if belt and cover.a >= rest then cover.onLink = true end

        local floor = cover.onLink and rest or 0
        if cover.a < floor then
            cover.a = floor
            if cover.v < 0 then cover.v = -cover.v * (cfg.Bounce or 0.35) end
            if cover.v < 15 then cover.v = 0 end
        end

        if cover.a > maxAngle then
            cover.a = maxAngle
            if cover.v > 0 then cover.v = -cover.v * 0.3 end
        end
    end
end

local function LinkCoverStep(wep, cfg, dt)
    local belt, fed = LinkCoverBelt(wep, cfg)
    local rest = cfg.Rest or 70

    local cover = wep._linkCover
    if not cover then
        cover = {
            a = belt and rest or 0,
            v = 0,
            shots = wep._shotCount or 0,
            onLink = belt,
            belt = belt,
        }
        wep._linkCover = cover
    end

    if cover.frame == FrameNumber() then return cover.a end
    cover.frame = FrameNumber()
    cover.fed = fed

    if (wep._shotCount or 0) > cover.shots and not wep:IsReloading() then
        cover.fed = true
        belt = true
    end

    KickCover(wep, cover, cfg, belt, rest)
    cover.belt = belt
    if not belt then cover.onLink = false end
    SimulateCover(cover, cfg, belt, rest, dt)

    return cover.a
end

local function ResetShotBones(vm)
    for id in pairs(vm.SandSwepShotBones) do vm:ManipulateBoneAngles(id, angle_zero) end
    vm.SandSwepShotBones = nil
end

hook.Add("PreDrawViewModel", "SandSwep_ShotBones", function(vm, ply, wep)
    if not IsValid(vm) then return end

    local model = vm:GetModel()
    if vm.SandSwepShotBones and vm.SandSwepShotBonesMdl ~= model then ResetShotBones(vm) end
    vm.SandSwepShotBonesMdl = model

    local sandswep = IsValid(wep) and wep.IsSandSwep
    local cover = sandswep and wep.LinkCover
    if cover then
        local id = SandSwep.BoneId(vm, cover.Bone)
        if id then
            local coverAngle = LinkCoverStep(wep, cover, math.min(VisualFrameTime(), 0.1))
            vm:ManipulateBoneAngles(id, (cover.Ang or Angle(-1, 0, 0)) * coverAngle)
            vm.SandSwepShotBones = vm.SandSwepShotBones or {}
            vm.SandSwepShotBones[id] = true
        end
    end

    local configs = sandswep and wep.ShotBones
    if not configs then
        if vm.SandSwepShotBones and not cover then ResetShotBones(vm) end
        return
    end

    local done = vm.SandSwepShotBones or {}
    vm.SandSwepShotBones = done

    local times = wep._shotTimes or {}
    local now = CurTime()
    for _, cfg in ipairs(configs) do
        local id = SandSwep.BoneId(vm, cfg.Bone)
        if id then
            vm:ManipulateBoneAngles(id, cfg.Ang * ShotBoneWeight(cfg, times, now))
            done[id] = true
        end
    end
end)
