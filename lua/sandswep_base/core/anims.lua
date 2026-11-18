local Developer = SandSwep.BaseShared.Developer
local STAGE_NONE = SandSwep.BaseShared.STAGE_NONE

local CONV_SUFFIX = {
    reload_empty = "reloadempty",
    reload_speed_empty = "reloadempty_speed",
    reload_empty_resume = "reloadempty_resume",
    reload_empty_bolt = "reloadempty_bolt",
    reload_empty_start = "reloadempty_start",
}
local CONV_LETTERS = { "a", "b", "c", "d", "e", "f" }
local MARK_FIELDS = {
    commit = "Commit",
    magout = "MagOut",
    magin = "MagIn",
    bolt = "BoltAt",
    eject = "Eject",
    cycled = "Cycled",
    roundin = "RoundIn",
}
local BOLT_ANIMS = { cycle = true, iron_cycle = true, iron_cycle_optic = true }
local MUZZLE_EVENTS = { [5001] = true, [5011] = true, [5021] = true, [5031] = true }

local function Append(list, value)
    if value then list[#list + 1] = value end
end

local function HasFlag(key, flag)
    return string.find(key, flag, 1, true) ~= nil
end

local function AttachmentSetNames(wep)
    local names = {}
    for _, _, def in wep:IterAttachments() do
        if def.AnimSet then names[#names + 1] = def.AnimSet end
    end

    return names
end

local function LauncherSetName(wep)
    local def = wep:GetGLDef()
    return (def and def.GLAnimSet) or "glsetup"
end

function SWEP:GetActiveAnimSets()
    local sets = self.AnimSets
    local locked = self:IsBoltLocked()
    local deployed = self.GetBipodDeployed and self:GetBipodDeployed() or false
    local launcher = self:GetGLMode()
    local attData = self:GetAttData()

    local last = self._animSetInputs
    if self._animSets and last and last.attData == attData and last.launcher == launcher
        and last.locked == locked and last.deployed == deployed then
        return self._animSets
    end

    last = last or {}
    self._animSetInputs = last
    last.attData, last.launcher, last.locked, last.deployed = attData, launcher, locked, deployed

    local key = attData
        .. (launcher and "|gl" or "")
        .. (locked and "|e" or "")
        .. (deployed and "|d" or "")

    if self._animSetKey == key and self._animSets then return self._animSets end

    local list = {}
    if sets then
        local names = AttachmentSetNames(self)

        if deployed then
            if locked then Append(list, sets["deployed+empty"]) end
            for _, name in ipairs(names) do Append(list, sets["deployed+" .. name]) end
            Append(list, sets.deployed)
        end

        if launcher then
            Append(list, sets[LauncherSetName(self)])
        end

        if locked then
            for _, name in ipairs(names) do Append(list, sets[name .. "+empty"]) end
            Append(list, sets.empty)
        end

        local present = {}
        for _, name in ipairs(names) do
            if sets[name] then present[#present + 1] = name end
        end

        for i = 1, #present do
            for j = i + 1, #present do
                local first, second = present[i], present[j]
                Append(list, sets[first .. "+" .. second] or sets[second .. "+" .. first])
            end
        end

        for _, name in ipairs(present) do Append(list, sets[name]) end
    end

    self._animSetKey, self._animSets = key, list
    return list
end

function SWEP:GetConventionPrefixes()
    self:GetActiveAnimSets()
    local key = self._animSetKey
    if self._convKey == key and self._convPrefixes then return self._convPrefixes end

    local names = AttachmentSetNames(self)
    local locked, deployed = HasFlag(key, "|e"), HasFlag(key, "|d")
    local list = {}

    if self:GetGLMode() then
        Append(list, LauncherSetName(self))
    end

    if deployed then
        if locked then Append(list, "deployed_empty") end
        for _, name in ipairs(names) do Append(list, "deployed_" .. name) end
        Append(list, "deployed")
    end

    if locked then
        for _, name in ipairs(names) do Append(list, "empty_" .. name) end
        Append(list, "empty_base")
    end

    for i = 1, #names do
        for j = 1, #names do
            if i ~= j then Append(list, names[i] .. "_" .. names[j]) end
        end
    end

    for _, name in ipairs(names) do Append(list, name) end
    Append(list, "base")

    self._convKey, self._convPrefixes = key, list
    return list
end

local function SequenceVariants(seqs, stem, fidget)
    local list = {}
    if seqs[stem] then Append(list, stem) end

    for i = 1, 9 do
        if seqs[stem .. "_" .. i] then Append(list, stem .. "_" .. i) end
        if fidget and i > 1 and seqs[stem .. i] then Append(list, stem .. i) end
    end

    for _, letter in ipairs(CONV_LETTERS) do
        if seqs[stem .. "_" .. letter] then Append(list, stem .. "_" .. letter) end
    end

    if #list > 0 then return list end
end

local function IronStem(prefix, suffix)
    if prefix == "base" then return "iron_" .. suffix end
    if prefix == "empty_base" then return "empty_iron_" .. suffix end

    return prefix .. "_iron_" .. suffix
end

function SWEP:GetConventionEntry(name)
    local seqs = SandSwep.GetModelSequences(self.ViewModel)

    if name == "gl_in" or name == "gl_out" then
        local seq = LauncherSetName(self) .. (name == "gl_in" and "_in" or "_out")
        if seqs[seq] then return { Seq = seq } end
        return
    end

    local ironName = string.match(name, "^iron_(.+)$")
    local plain = ironName or name
    local suffix = CONV_SUFFIX[plain] or plain
    local fidget = plain == "fidget"
    local emptyOnly = fidget and HasFlag(self._animSetKey or "", "|e")

    for _, prefix in ipairs(self:GetConventionPrefixes()) do
        if not emptyOnly or string.StartWith(prefix, "empty_") then
            local stem = ironName and IronStem(prefix, suffix) or (prefix .. "_" .. suffix)
            local list = SequenceVariants(seqs, stem, fidget)
            if list then
                return {
                    Seq = #list == 1 and list[1] or list,
                    BlendOut = fidget and 0.25 or nil,
                }
            end
        end
    end
end

function SWEP:MergeModelMarks(entry)
    local seq = isstring(entry.Seq) and entry.Seq or (istable(entry.Seq) and entry.Seq[1])
    local data = SandSwep.GetSequenceData(self.ViewModel, seq)
    if not data or not data.marks or data.len <= 0 then return entry end

    local out = table.Copy(entry)
    for mark, field in pairs(MARK_FIELDS) do
        if data.marks[mark] and out[field] == nil then out[field] = data.marks[mark] * data.len end
    end

    if data.marks.insert then
        local insertAt = data.marks.insert * data.len
        if out.ShowMagAt == nil then out.ShowMagAt = insertAt end
        if out.ResumeAt == nil then out.ResumeAt = insertAt end
        out.InsertAt = insertAt
    end

    return out
end

local function NormalizeEntry(entry)
    if isstring(entry) or entry.Seq == nil then return { Seq = entry } end
    return entry
end

function SWEP:GetAnimEntry(name)
    local sets = self:GetActiveAnimSets()
    local key = self._animSetKey
    if self._entryKey ~= key then self._entryKey, self._entryCache = key, {} end

    local cached = self._entryCache[name]
    if cached ~= nil then return cached or nil end

    local entry
    for _, set in ipairs(sets) do
        entry = set[name]
        if entry == false then
            self._entryCache[name] = false
            return
        end
        if entry then break end
    end

    entry = entry or (self.Anims and self.Anims[name])

    if entry then
        entry = NormalizeEntry(entry)
    else
        entry = self:GetConventionEntry(name)
    end

    if entry then entry = self:MergeModelMarks(entry) end

    self._entryCache[name] = entry or false
    return entry
end

function SWEP:ResolveAnim(name, first)
    local entry = self:GetAnimEntry(name)
    if not entry then return end

    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() then return end

    local vm = owner:GetViewModel()
    if not IsValid(vm) then return end

    local seqName = entry.Seq
    if istable(seqName) then
        local count = #seqName
        if count == 0 then return end

        local pick = 1
        if not first then
            local roll = math.floor(util.SharedRandom("sandswep_anim_" .. name, 1, count + 1))
            pick = math.Clamp(roll, 1, count)
        end

        seqName = seqName[pick]
    end

    local seq = vm:LookupSequence(seqName)
    if not seq or seq < 0 then return end

    return vm, seq, entry
end

function SWEP:HasAnim(name)
    return self:ResolveAnim(name, true) ~= nil
end

function SWEP:GetAnimLength(name)
    local vm, seq = self:ResolveAnim(name, true)
    if not vm then return 0 end

    return vm:SequenceDuration(seq)
end

function SWEP:GetAnimCommit(name)
    local entry = self:GetAnimEntry(name)
    local len = self:GetAnimLength(name)

    return math.min(entry and entry.Commit or len, len), len
end

function SWEP:PlayAnim(name, rate, cycle)
    local vm, seq = self:ResolveAnim(name)
    if not vm then return false end

    if self:GetCycleAt() > 0 and not BOLT_ANIMS[name] then self:CancelBoltCycle() end

    rate = rate or 1
    local offset = cycle and cycle > 0

    self.LastAnim = name
    vm:SendViewModelMatchingSequence(seq)
    if offset then vm:SetCycle(cycle) end
    vm:SetPlaybackRate(rate)

    local len = vm:SequenceDuration(seq)
    if offset then
        self:SetAnimOffStart(CurTime())
        self:SetAnimOffCycle(cycle)
        self:SetAnimOffRate(rate / math.max(len, 0.01))
        self:SetAnimOffSeq(seq)
    else
        self:SetAnimOffStart(0)
    end

    self:SetIdleTime(CurTime() + len * (1 - (cycle or 0)) / math.max(rate, 0.01))
    return true
end

function SWEP:PlayLoopAnim(name)
    if not self:PlayAnim(name) then return false end

    self:SetIdleTime(0)
    return true
end

function SWEP:PlayIdleAnim()
    if self:GetSprinting() and self:UsesSprintAnims() then
        local last = self.LastAnim
        if last ~= "sprint_in" and last ~= "sprint" then
            local len = self:GetAnimLength("sprint_in")
            if self:PlayAnim("sprint_in", len / math.max(self.SprintInTime, 0.05)) then return end
        end

        if self:PlayLoopAnim("sprint") then return end
    end

    local locked = self:IsBoltLocked()
    local staged = locked and self:GetReloadStage() ~= STAGE_NONE

    if staged and self:HasAnim("idle_locked") and self:PlayLoopAnim("idle_locked") then return end
    if locked and self:PlayLoopAnim("idle_empty") then return end
    self:PlayLoopAnim("idle")
end

function SWEP:FireAnimationEvent(pos, ang, event, options)
    if CLIENT and Developer() then
        print(string.format("[sandswep] anim event %d '%s'", event, tostring(options)))
    end

    if self.MuteModelSounds and event == 5004 then return true end

    local muzzle = MUZZLE_EVENTS[event] or (self.MuzzleFlashEvents and self.MuzzleFlashEvents[event])
    if muzzle and (self:IsSuppressed() or (CLIENT and SandSwepFX and SandSwepFX.Uses(self))) then
        return true
    end
end
