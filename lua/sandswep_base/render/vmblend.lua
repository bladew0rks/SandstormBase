if not CLIENT then return end

local BlendMatrix = SandSwep.Math.BlendMatrix
local CopyBone = SandSwep.Math.CopyBone

local function EntrySequences(entry)
    if isstring(entry.Seq) then return { entry.Seq } end
    return istable(entry.Seq) and entry.Seq or {}
end

function SWEP:GetSeqBlends()
    if self._blendSeqs then return self._blendSeqs end

    local blendIn, blendOut = {}, {}
    local function Scan(entries)
        for _, entry in pairs(entries or {}) do
            if not istable(entry) or not (entry.BlendIn or entry.BlendOut) then continue end

            local inTime = entry.BlendIn
            if inTime and entry.From and self.ResumeBlendMax then
                inTime = math.min(inTime, self.ResumeBlendMax)
            end

            for _, name in ipairs(EntrySequences(entry)) do
                if isstring(name) then
                    name = string.lower(name)
                    if inTime then blendIn[name] = inTime end
                    if entry.BlendOut then blendOut[name] = entry.BlendOut end
                end
            end
        end
    end

    Scan(self.Anims)
    for _, set in pairs(self.AnimSets or {}) do
        if istable(set) then Scan(set) end
    end

    self._blendSeqs = { In = blendIn, Out = blendOut }
    return self._blendSeqs
end

local SequenceName = SandSwep.SequenceName

function SWEP:GetSeqBlendIn(vm, seq, prevSeq)
    local blends = self:GetSeqBlends()
    local own = blends.In[SequenceName(vm, seq)]
    if own then return own end
    if not prevSeq then return end

    local prev = SequenceName(vm, prevSeq)
    if blends.Out[prev] then return blends.Out[prev] end
    if string.EndsWith(prev, "_start") then return self.ReloadStageBlend end
    if string.find(prev, "sprint", 1, true) and not string.EndsWith(prev, "_in") then
        return self.SprintExitBlend or 0.2
    end
    if (string.find(prev, "fidget", 1, true) or string.find(prev, "inspect", 1, true)) then
        return 0.25
    end
end

local function Snapshot(wep, vm)
    local snap = wep._vmSnap
    local model = vm:GetModel()
    if not snap or snap.model ~= model then
        snap = { model = model, m = {} }
        wep._vmSnap = snap
        wep._vmBlend = nil
    end

    return snap
end

local loc = Matrix()

local function Localize(mats)
    if not mats.raw then return end
    mats.raw = nil

    local inv = mats.inv
    for i = 0, mats.n - 1 do
        local mat = mats[i]
        if mat then
            loc:Set(inv)
            loc:Mul(mat)
            mat:Set(loc)
        end
    end
end

local function TrackChanges(wep, vm, snap)
    local seq = vm:GetSequence()
    local att = wep:GetAttData()

    if snap.att ~= nil and snap.att ~= att then
        snap.attChanged = RealTime()
        wep._vmBlend = nil
    end
    snap.att = att

    local swapped = snap.attChanged and RealTime() - snap.attChanged < 0.5
    if snap.seq and seq ~= snap.seq then
        local dur = not swapped and snap.valid and wep:GetSeqBlendIn(vm, seq, snap.seq)
        if dur and dur > 0 then
            local old = wep._vmBlend
            Localize(snap.m)
            wep._vmBlend = { start = RealTime(), dur = dur, from = snap.m }
            snap.m = (old and old.from) or snap.spare or {}
            snap.spare = nil
            snap.frame, snap.at = nil, nil
        else
            wep._vmBlend = nil
        end
    end
    snap.seq = seq
end

local function BlendWeight(wep, snap)
    local blend = wep._vmBlend
    if not blend then return end

    local frac = (RealTime() - blend.start) / blend.dur
    if frac >= 1 then
        wep._vmBlend = nil
        if blend.from ~= snap.m then snap.spare = blend.from end
        return
    end

    return blend, SandSwep.Math.Smoothstep(frac)
end

local CAPTURE_INTERVAL = 1 / 120
local base, toLocal, world, boneMat = Matrix(), Matrix(), Matrix(), Matrix()

local function CaptureRaw(vm, mats, numBones)
    local inv = mats.inv
    if not inv then
        inv = Matrix()
        mats.inv = inv
    end
    inv:Set(base)
    inv:InvertTR()

    for i = 0, numBones - 1 do
        local mat = mats[i]
        if not mat then
            mat = Matrix()
            mats[i] = mat
        end
        if not CopyBone(vm, i, mat) then mats[i] = nil end
    end
    mats.raw, mats.n = true, numBones
end

function SWEP:VMBoneBlend(vm, numBones)
    local frame = FrameNumber()
    local snap = self._vmSnap
    if not self._vmBlend and not self._seqStep and snap and snap.checkedFrame == frame and snap.seq == vm:GetSequence() then
        return
    end

    snap = Snapshot(self, vm)
    if self._seqStep then
        self._vmBlend = nil
        snap.seq, snap.valid, snap.checkedFrame = vm:GetSequence(), nil, nil
        return
    end

    TrackChanges(self, vm, snap)
    local blend, weight = BlendWeight(self, snap)

    local now = RealTime()
    local capture = snap.frame ~= frame and (not snap.at or now - snap.at >= CAPTURE_INTERVAL)
    snap.checkedFrame = frame
    if not capture and not blend then return end
    if capture then snap.frame, snap.at = frame, now end

    base:SetTranslation(vm:GetPos())
    base:SetAngles(vm:GetAngles())

    local current = snap.m
    if not blend then
        CaptureRaw(vm, current, numBones)
        snap.valid = true
        return
    end

    toLocal:Set(base)
    toLocal:InvertTR()
    if capture then current.raw = nil end

    for i = 0, numBones - 1 do
        local mat = CopyBone(vm, i, boneMat)
        if not mat then
            if capture then current[i] = nil end
            continue
        end

        loc:Set(toLocal)
        loc:Mul(mat)

        local from = blend and blend.from[i]
        if from then
            BlendMatrix(from, loc, weight, loc)
            world:Set(base)
            world:Mul(loc)
            vm:SetBoneMatrix(i, world)
        end

        if capture then
            local keep = current[i]
            if not keep then
                keep = Matrix()
                current[i] = keep
            end
            keep:Set(loc)
        end
    end

    if capture then snap.valid = true end
end

function SWEP:HookBoneBlend(vm)
    if vm.SandSwepBoneBlend then return end

    vm.SandSwepBoneBlend = vm:AddCallback("BuildBonePositions", function(ent, numBones)
        ent.SandSwepBonePos, ent.SandSwepBoneAng = ent:GetPos(), ent:GetAngles()

        local ply = ent:GetOwner()
        local wep = IsValid(ply) and ply.GetActiveWeapon and ply:GetActiveWeapon()
        if not IsValid(wep) or not wep.IsSandSwep then return end

        if wep.VMGrip then wep:VMGrip(ent) end
        if wep.VMHandPose then wep:VMHandPose(ent) end
        if wep.VMTubeSelector then wep:VMTubeSelector(ent) end
        if wep.VMBoneBlend then wep:VMBoneBlend(ent, numBones) end
        if wep.VMMagRounds then wep:VMMagRounds(ent) end
        if wep.VMVManip then wep:VMVManip(ent) end
        if wep.VMForearmFit then wep:VMForearmFit(ent) end
    end)
end

local function MagShownFull(wep)
    local entry = wep:GetCurrentReloadEntry()
    local fresh = istable(entry) and (entry.ShowMagAt or entry.ResumeAt or entry.MagIn)
    local drop = wep._magDrop

    return (drop and drop.done and drop.key == wep:GetActionStart()) or (fresh and wep:GetReloadAnimTime() >= fresh)
end

function SWEP:GetMagRoundState()
    local spec = self.MagRounds
    if not spec or not SandSwep.MagRoundData or self:IsMagHidden() then return end

    local cache = self:AttCache()
    if cache.magRound == nil then
        cache.magRound = spec[self:GetDesiredBodygroups().mag or 0] or false
    end

    local data = cache.magRound and SandSwep.MagRoundData[cache.magRound]
    if not data then return end

    local size = self:GetMagSize()
    local rounds = self:GetRoundsInMag()
    if self:IsReloading() and MagShownFull(self) then rounds = size end

    return data, math.Clamp(size - rounds, 0, #data.States - 1)
end

function SWEP:VMMagRounds(vm)
    local data, spent = self:GetMagRoundState()
    if data then SandSwep.PoseMagRounds(vm, data, spent) end
end

function SWEP:ApplyAnimOffset(vm)
    local start = self:GetAnimOffStart()
    if start <= 0 or vm:GetSequence() ~= self:GetAnimOffSeq() then return end

    local cycle = self:GetAnimOffCycle() + (CurTime() - start) * self:GetAnimOffRate()
    if cycle >= 1 then return end

    vm:SetCycle(math.max(cycle, 0))
    vm:InvalidateBoneCache()
end
