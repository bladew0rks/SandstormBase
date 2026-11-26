SANDTPIK = SANDTPIK or {}

local NW_SEQ, NW_START, NW_CYCLE, NW_RATE = "SandTPIK_Seq", "SandTPIK_Start", "SandTPIK_Cycle", "SandTPIK_Rate"

function SANDTPIK.IsSandWeapon(wep)
    return IsValid(wep) and wep.IsSandSwep == true
end

local function ownerViewModel(wep)
    local owner = wep:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() then return end

    local vm = owner:GetViewModel(0)
    if not IsValid(vm) then return end

    local want = wep.ViewModel
    if isstring(want) then
        local have = vm:GetModel() or ""

        if have ~= want then
            if vm.SandTPIK_HaveModel ~= have or vm.SandTPIK_WantModel ~= want then
                vm.SandTPIK_HaveModel, vm.SandTPIK_WantModel = have, want
                vm.SandTPIK_ModelMatch = string.lower(have) == string.lower(want)
            end

            if not vm.SandTPIK_ModelMatch then return end
        end
    end

    return vm, owner
end

SANDTPIK.OwnerViewModel = ownerViewModel

function SANDTPIK.IsLooping(ent, seq)
    if not seq or seq < 0 then return false end

    local info = ent:GetSequenceInfo(seq)
    return info ~= nil and bit.band(info.flags or 0, 1) ~= 0
end

local seqDurations = {}

function SANDTPIK.CycleAt(ent, seq, start, cycle, rate, now, looping)
    if not seq or seq < 0 then return 0 end

    local mdl = ent:GetModel() or ""
    local bySeq = seqDurations[mdl]
    if not bySeq then
        bySeq = {}
        seqDurations[mdl] = bySeq
    end

    local duration = bySeq[seq]
    if duration == nil then
        duration = ent:SequenceDuration(seq) or 0
        bySeq[seq] = duration
    end
    if duration <= 0 then return cycle or 0 end

    local progress = (cycle or 0) + (now - (start or now)) * (rate or 1) / duration

    if looping then
        progress = progress % 1
    else
        progress = math.Clamp(progress, 0, 1)
    end

    return progress
end

local function store(wep, track)
    if not SERVER then return end

    wep:SetNW2Int(NW_SEQ, track.seq)
    wep:SetNW2Float(NW_START, track.start)
    wep:SetNW2Float(NW_CYCLE, track.cycle)
    wep:SetNW2Float(NW_RATE, track.rate)
end

function SANDTPIK.Restart(wep, cycle)
    if CLIENT and not IsFirstTimePredicted() then return end
    if not IsValid(wep) then return end

    local vm = ownerViewModel(wep)
    if not vm then return end

    local track = wep.SandTPIK_Track or {}
    wep.SandTPIK_Track = track

    track.seq = vm:GetSequence()
    track.start = CurTime()
    track.cycle = tonumber(cycle) or 0
    track.rate = vm:GetPlaybackRate()

    store(wep, track)
end

local function wrap(tbl, name, after)
    local original = tbl[name]
    if not isfunction(original) then return end

    tbl[name] = function(self, ...)
        local ret1, ret2, ret3, ret4 = original(self, ...)
        after(self, ret1, ...)
        return ret1, ret2, ret3, ret4
    end
end

function SANDTPIK.InstallWrappers(wep)
    if wep.SandTPIK_Wrapped then return end

    local tbl = wep:GetTable()
    tbl.SandTPIK_Wrapped = true

    wrap(tbl, "PlayAnim", function(self, ok, _, _, cycle)
        if ok then SANDTPIK.Restart(self, cycle) end
    end)
end

function SANDTPIK.Poll(wep)
    local vm = ownerViewModel(wep)
    if not vm then return end

    SANDTPIK.InstallWrappers(wep)

    local now = CurTime()
    local seq, rate = vm:GetSequence(), vm:GetPlaybackRate()
    local track = wep.SandTPIK_Track

    if not track or track.seq ~= seq then
        track = track or {}
        wep.SandTPIK_Track = track

        track.seq, track.start, track.cycle, track.rate = seq, now, 0, rate
        store(wep, track)
        return
    end

    if math.abs((track.rate or 1) - rate) > 0.001 then
        track.cycle = SANDTPIK.CycleAt(vm, seq, track.start, track.cycle, track.rate, now, SANDTPIK.IsLooping(vm, seq))
        track.start, track.rate = now, rate
        store(wep, track)
    end
end

function SANDTPIK.GetAnimState(wep)
    if CLIENT and not game.SinglePlayer() and wep:GetOwner() == LocalPlayer() then
        local track = wep.SandTPIK_Track
        if track and track.seq then return track.seq, track.start, track.cycle, track.rate end
    end

    return wep:GetNW2Int(NW_SEQ, -1), wep:GetNW2Float(NW_START, 0),
        wep:GetNW2Float(NW_CYCLE, 0), wep:GetNW2Float(NW_RATE, 1)
end

if SERVER then
    hook.Add("Think", "SandTPIK.Track", function()
        for _, ply in player.Iterator() do
            local wep = ply:GetActiveWeapon()
            if SANDTPIK.IsSandWeapon(wep) then SANDTPIK.Poll(wep) end
        end
    end)
else
    hook.Add("Think", "SandTPIK.TrackLocal", function()
        if game.SinglePlayer() then return end

        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local wep = ply:GetActiveWeapon()
        if SANDTPIK.IsSandWeapon(wep) then SANDTPIK.Poll(wep) end
    end)
end
