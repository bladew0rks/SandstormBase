local Shared = SandSwep.BaseShared
local RELOAD_NONE, RELOAD_INSERT = Shared.RELOAD_NONE, Shared.RELOAD_INSERT
local INSERT_START, INSERT_LOOP, INSERT_END, INSERT_CLIP, INSERT_SWAP = 1, 2, 3, 4, 5

-- Bolt action

function SWEP:GetBoltAnim(base)
    if self:GetAimProgress() > 0.5 then
        if not self:GetBipodDeployed() and self:GetSlotAttachment("optic") and self:HasAnim("iron_" .. base .. "_optic") then
            return "iron_" .. base .. "_optic"
        end
        if self:HasAnim("iron_" .. base) then return "iron_" .. base end
    end

    return base
end

function SWEP:HoldBoltCycle(name, ct)
    local commit = self:GetAnimCommit(name)

    self:SetNeedsCycle(true)
    self:SetCycleAt(0)
    self:SetEjectAt(0)
    self:SetNextPrimaryFire(ct + math.min(commit, self.CycleDelay or 0.35))
end

function SWEP:ArmBoltCycle(name, ct, speed)
    speed = speed or 1
    local entry = self:GetAnimEntry(name)
    local commit, len = self:GetAnimCommit(name)

    self:SetNeedsCycle(true)
    self:SetCycleAt(ct + ((entry and entry.Cycled) or commit) / speed)
    self:SetEjectAt(entry and entry.Eject and ct + entry.Eject / speed or 0)
    self:SetNextPrimaryFire(math.max(self:GetNextPrimaryFire(), ct + commit / speed))
    self:StartSoundSet("cycle", len / speed)
end

function SWEP:GetShotsPerCycle()
    for _, _, def in self:IterAttachments() do
        if def.ShotsPerCycle then return def.ShotsPerCycle end
    end

    return self.ShotsPerCycle or 1
end

function SWEP:IsBoltAction()
    local manual = self.ManualFireModes
    if not manual then return self.BoltAction == true end

    local mode = self:GetFireMode()
    if mode == "safe" then mode = self:GetFireModes()[self:GetLastFireModeIndex()] or mode end
    return manual[mode] == true
end

function SWEP:CanCycleBolt()
    if not self:IsBoltAction() or not self:GetNeedsCycle() or self:GetCycleAt() > 0 then return false end
    if self:Clip1() <= 0 and not (self.Tubes and self:GetOtherTube() > 0) then return false end
    if self:IsReloading() or self:GetCurrentAction() or self:IsHolstering() or self:GetGLMode() then return false end
    if self:GetSprinting() or self:GetSprintProgress() > 0 or self:GetBurstLeft() > 0 then return false end

    local owner = self:GetOwner()
    if IsValid(owner) and owner:IsPlayer() and owner:KeyDown(IN_ATTACK) then return false end

    return CurTime() >= self:GetNextPrimaryFire()
end


function SWEP:SwapTubes()
    local active = self:Clip1()
    self:SetClip1(self:GetOtherTube())
    self:SetOtherTube(active)
    self:SetTubeSwapped(not self:GetTubeSwapped())
end

function SWEP:PlayTubeSwap()
    if not self:PlayAnim("tubeswap") then return false end

    local len = self:GetAnimLength("tubeswap")
    self:SwapTubes()
    self:SetCycleAt(0)
    self:BeginAction("tubeswap", len)
    self:SetNextPrimaryFire(CurTime() + len)
    self:StartSoundSet("tubeswap", len)

    return true
end

function SWEP:StartTubeSwap()
    if not self.Tubes or self:Clip1() > 0 or self:GetOtherTube() <= 0 then return false end

    return self:PlayTubeSwap()
end

function SWEP:CanSwitchTube()
    if not self.Tubes or self:IsReloading() or self:GetCurrentAction() or self:IsHolstering() then return false end
    if self:GetSprinting() or self:GetCycleAt() > 0 then return false end

    return CurTime() >= self:GetNextPrimaryFire()
end

function SWEP:SwitchTube()
    if not self:CanSwitchTube() then return false end

    return self:PlayTubeSwap()
end

function SWEP:StartBoltCycle()
    if self:StartTubeSwap() then return end

    local name = self:GetBoltAnim("cycle")
    local speed = math.max(self:GetStatMult("CycleSpeed"), 0.1)
    if not self:PlayAnim(name, speed) then
        self:SetNeedsCycle(false)
        return
    end

    self:ArmBoltCycle(name, CurTime(), speed)
end

function SWEP:CancelBoltCycle()
    if self:GetCycleAt() <= 0 then return end

    self:SetCycleAt(0)
    self:SetEjectAt(0)
    if self:GetSoundSet() == self:GetSoundSetIds().ids.cycle then self:StopSoundSet() end
end

function SWEP:UpdateBoltCycle(owner, ct)
    if self:GetReloadState() == RELOAD_INSERT and owner:KeyPressed(IN_ATTACK) then self:SetInsertStop(true) end

    local ejectAt = self:GetEjectAt()
    if ejectAt > 0 and ct >= ejectAt then
        self:SetEjectAt(0)
        if self:GetEjectLive() then self:EjectLiveRound() else self:EjectCasing() end
        self:SetEjectLive(false)
    end

    local cycleAt = self:GetCycleAt()
    if cycleAt > 0 and ct >= cycleAt then
        self:SetCycleAt(0)
        self:SetNeedsCycle(false)
    end

    if self:CanCycleBolt() then self:StartBoltCycle() end
end

-- Round-by-round reloads

function SWEP:UsesInsertReload()
    return self.InsertReload and self:HasAnim("insert") or false
end

function SWEP:ChamberBonus()
    return (self.TubeFed and not self.Tubes and self:IsChambered()) and 1 or 0
end

function SWEP:CanInsertRound()
    if #self:GetMags() == 0 then return false end

    local size = self:GetMagSize()
    return self:Clip1() < size + self:ChamberBonus() or (self.Tubes ~= nil and self:GetOtherTube() < size)
end

function SWEP:TubeFull()
    return self.Tubes ~= nil and self:Clip1() >= self:GetMagSize() and self:GetOtherTube() < self:GetMagSize()
end

function SWEP:PocketRound()
    local mags = table.Copy(self:GetMags())
    local size = self:GetMagSize()
    table.sort(mags, function(a, b) return a > b end)

    for i = #mags, 1, -1 do
        if mags[i] < size then
            mags[i] = mags[i] + 1
            self:SetMags(mags)
            return
        end
    end

    mags[#mags + 1] = 1
    self:SetMags(mags)
end

function SWEP:InsertRound()
    local mags = table.Copy(self:GetMags())
    local count = #mags
    if count == 0 or self:Clip1() >= self:GetMagSize() + self:ChamberBonus() then return false end

    mags[count] = mags[count] - 1
    self:SetMags(mags)
    self:SetClip1(self:Clip1() + 1)

    return true
end

function SWEP:PlayInsertPhase(name, phase, mark, eject)
    local speed = self:GetReloadSpeed()
    if self.InsertAnimVariant then name = self:InsertAnimVariant(name) end
    if not self:PlayAnim(name, speed) then return false end

    local entry = self:GetAnimEntry(name)
    local len = self:GetAnimLength(name) / speed
    local lockTime = len
    if phase == INSERT_END or phase == INSERT_CLIP then
        lockTime = math.min(((entry and entry.Commit) or len) / speed, len)
    end

    local eventTime = entry and entry[mark]
    self:BeginAction("reload", lockTime, eventTime and eventTime / speed or nil)
    if eject and entry and entry.Eject then self:SetEjectAt(CurTime() + entry.Eject / speed) end

    self:SetInsertPhase(phase)
    self:SetNextPrimaryFire(CurTime() + lockTime)
    self:StartSoundSet(string.match(name, "^(insert_start)_%d$") or string.match(name, "^(.-)_cyl%d$") or name, len)

    return true
end

function SWEP:UsesClipLoad()
    return self:Clip1() <= 0 and self:HasAnim("insert_clip") and (not self.CanClipLoad or self:CanClipLoad())
end

function SWEP:StartInsertReload()
    local pending = self.TubeFed and self:GetNeedsCycle() and self:Clip1() > 0
    local empty = self:Clip1() <= 0 or (self:IsBoltAction() and self:GetNeedsCycle() and not pending)
    local clip = self:UsesClipLoad()
    local name = clip and "insert_clip"
        or ((empty and self:HasAnim("insert_start_empty")) and "insert_start_empty" or "insert_start")

    local spent = self:GetMagSize() + self:ChamberBonus() - self:Clip1()
    if not clip and not empty and self:HasAnim("insert_start_" .. spent) then name = "insert_start_" .. spent end

    self:CancelBoltCycle()
    if self:TubeFull() then self:SwapTubes() end

    local live = self:IsBoltAction() and not empty and self:IsChambered() and not self.TubeFed
    local mark = clip and "MagIn" or ((self.TubeFed and empty) and "RoundIn" or nil)

    self:SetInsertStop(false)
    self:SetReloadState(RELOAD_INSERT)
    self:SetReloadEmpty(empty)
    if not self:PlayInsertPhase(name, clip and INSERT_CLIP or INSERT_START, mark, empty or live) then
        self:SetReloadState(RELOAD_NONE)
        return
    end

    if live then
        self:SetClip1(self:Clip1() - 1)
        self:PocketRound()
        self:SetEjectLive(true)
    end

    self:SetNeedsCycle(pending)
    self:GetOwner():SetAnimation(PLAYER_RELOAD)
end

function SWEP:UpgradeInsertToClip()
    if not self.QuickClipLoad or self:GetInsertPhase() ~= INSERT_START then return end
    if CurTime() - self:GetActionStart() > self.QuickReloadWindow then return end
    if not self:HasAnim("insert_clip") or #self:GetMags() == 0 then return end
    if self.CanClipLoad and not self:CanClipLoad() then return end

    local clip = self:Clip1()
    self:SetClip1(0)
    if self.SetInsertBase then self:SetInsertBase(0) end

    if not self:PlayInsertPhase("insert_clip", INSERT_CLIP, "MagIn", true) then
        self:SetClip1(clip)
        return
    end

    self:SetReloadEmpty(true)
end

function SWEP:InsertReloadEvent()
    local phase = self:GetInsertPhase()
    if phase == INSERT_LOOP or phase == INSERT_START then
        self:InsertRound()
    elseif phase == INSERT_CLIP then
        for _ = 1, self.ClipRounds or 5 do
            if not self:InsertRound() then break end
        end
    end
end

function SWEP:AdvanceInsertReload()
    local phase = self:GetInsertPhase()
    if phase == INSERT_END or phase == INSERT_CLIP then
        self:SetReloadState(RELOAD_NONE)
        self:SetInsertPhase(0)
        self:SetReloadChainAt(0)
        return
    end

    if not self:GetInsertStop() and self:CanInsertRound() then
        if self:TubeFull() and self:HasAnim("insert_tubeswap") and self:PlayInsertPhase("insert_tubeswap", INSERT_SWAP) then
            self:SwapTubes()
            return
        end

        if self:PlayInsertPhase("insert", INSERT_LOOP, "RoundIn") then return end
    end

    if self:PlayInsertPhase("insert_end", INSERT_END) then return end

    self:SetReloadState(RELOAD_NONE)
    self:SetInsertPhase(0)
end

function SWEP:InterruptInsertReload()
    local phase = self:GetInsertPhase()

    self:SetInsertPhase(0)
    self:SetEjectAt(0)
    self:SetEjectLive(false)
    if self.TubeFed then
        self:SetNeedsCycle(self:GetNeedsCycle() and self:Clip1() > 0)
    else
        self:SetNeedsCycle(self:IsBoltAction() and phase ~= 0 and self:Clip1() > 0 or false)
    end
    self:CancelReload()
end
