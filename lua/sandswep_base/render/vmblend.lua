if not CLIENT then return end

local function EntrySequences(entry)
    if isstring(entry.Seq) then return { entry.Seq } end
    return istable(entry.Seq) and entry.Seq or {}
end

function SWEP:GetSeqBlends()
    if self._blendSeqs then return self._blendSeqs end

    local blendIn, blendOut = {}, {}
    local function Scan(entries)
        for _, entry in pairs(entries or {}) do
            if istable(entry) and (entry.BlendIn or entry.BlendOut) then
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
    end

    Scan(self.Anims)
    for _, set in pairs(self.AnimSets or {}) do
        if istable(set) then Scan(set) end
    end

    self._blendSeqs = { In = blendIn, Out = blendOut }
    return self._blendSeqs
end

local function SequenceName(wep, vm, seq)
    local cache = wep._seqNames
    local model = vm:GetModel()
    if not cache or cache.model ~= model then
        cache = { model = model }
        wep._seqNames = cache
    end

    local name = cache[seq]
    if not name then
        name = string.lower(vm:GetSequenceName(seq) or "")
        cache[seq] = name
    end

    return name
end

function SWEP:GetSeqBlendIn(vm, seq, prevSeq)
    local blends = self:GetSeqBlends()
    local own = blends.In[SequenceName(self, vm, seq)]
    if own then return own end
    if not prevSeq then return end

    local prev = SequenceName(self, vm, prevSeq)
    if blends.Out[prev] then return blends.Out[prev] end
    if string.EndsWith(prev, "_start") then return self.ReloadStageBlend end
    if string.find(prev, "sprint", 1, true) and not string.EndsWith(prev, "_in") then
        return self.SprintExitBlend or 0.2
    end
    if (string.find(prev, "fidget", 1, true) or string.find(prev, "inspect", 1, true)) then
        return 0.25
    end
end

local sqrt = math.sqrt

local function Unit(x, y, z)
    local len = sqrt(x * x + y * y + z * z)
    if len < 1e-12 then return 0, 0, 0 end

    return x / len, y / len, z / len
end

local function BlendMatrix(from, to, w, out)
    local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 = from:Unpack()
    local b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12 = to:Unpack()

    local sx = sqrt(a1 * a1 + a5 * a5 + a9 * a9)
    local sy = sqrt(a2 * a2 + a6 * a6 + a10 * a10)
    local sz = sqrt(a3 * a3 + a7 * a7 + a11 * a11)
    sx = sx + (sqrt(b1 * b1 + b5 * b5 + b9 * b9) - sx) * w
    sy = sy + (sqrt(b2 * b2 + b6 * b6 + b10 * b10) - sy) * w
    sz = sz + (sqrt(b3 * b3 + b7 * b7 + b11 * b11) - sz) * w

    local fx, fy, fz = Unit(a1 + (b1 - a1) * w, a5 + (b5 - a5) * w, a9 + (b9 - a9) * w)
    local ux, uy, uz = a3 + (b3 - a3) * w, a7 + (b7 - a7) * w, a11 + (b11 - a11) * w
    local rx, ry, rz = Unit(fy * uz - fz * uy, fz * ux - fx * uz, fx * uy - fy * ux)
    ux, uy, uz = ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx

    out:SetUnpacked(
        fx * sx, -rx * sy, ux * sz, a4 + (b4 - a4) * w,
        fy * sx, -ry * sy, uy * sz, a8 + (b8 - a8) * w,
        fz * sx, -rz * sy, uz * sz, a12 + (b12 - a12) * w,
        0, 0, 0, 1)
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

    return blend, frac * frac * (3 - 2 * frac)
end

local CAPTURE_INTERVAL = 1 / 120
local base, toLocal, loc, world = Matrix(), Matrix(), Matrix(), Matrix()

function SWEP:VMBoneBlend(vm, numBones)
    local snap = Snapshot(self, vm)
    if self._seqStep then
        self._vmBlend = nil
        snap.seq, snap.valid = vm:GetSequence(), nil
        return
    end

    TrackChanges(self, vm, snap)
    local blend, weight = BlendWeight(self, snap)

    local frame, now = FrameNumber(), RealTime()
    local capture = snap.frame ~= frame and (not snap.at or now - snap.at >= CAPTURE_INTERVAL)
    if not capture and not blend then return end
    if capture then snap.frame, snap.at = frame, now end

    base:SetTranslation(vm:GetPos())
    base:SetAngles(vm:GetAngles())
    toLocal:Set(base)
    toLocal:InvertTR()

    local current = snap.m
    for i = 0, numBones - 1 do
        local mat = vm:GetBoneMatrix(i)
        if mat then
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
    end

    if capture then snap.valid = true end
end

function SWEP:HookBoneBlend(vm)
    if vm.SandSwepBoneBlend then return end

    vm.SandSwepBoneBlend = vm:AddCallback("BuildBonePositions", function(ent, numBones)
        ent.SandSwepBonePos, ent.SandSwepBoneAng = ent:GetPos(), ent:GetAngles()

        local ply = ent:GetOwner()
        local wep = IsValid(ply) and ply.GetActiveWeapon and ply:GetActiveWeapon()

        if IsValid(wep) and wep.VMGrip then wep:VMGrip(ent) end
        if IsValid(wep) and wep.VMHandPose then wep:VMHandPose(ent) end
        if IsValid(wep) and wep.VMTubeSelector then wep:VMTubeSelector(ent) end
        if IsValid(wep) and wep.VMBoneBlend then wep:VMBoneBlend(ent, numBones) end
        if IsValid(wep) and wep.VMMagRounds then wep:VMMagRounds(ent) end
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
