local cvReloadSpeed = CreateConVar("sv_sandswep_reload_speed", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY),
    "Reload speed multiplier for all weapons", 0.1, 5)

if CLIENT then
    CreateClientConVar("cl_sandswep_fast_reload", "0", true, true, "Quick reload: 0 = double-tap reload, 1 = always, 2 = when empty", 0, 2)
end

function SWEP:GetReloadSpeed()
    return math.max((self.ReloadSpeed or 1) * self:GetStatMult("ReloadSpeed") * cvReloadSpeed:GetFloat(), 0.01)
end

local Shared = SandSwep.BaseShared
local Developer, SinceTime = Shared.Developer, Shared.SinceTime
local RELOAD_NONE, RELOAD_TACTICAL, RELOAD_QUICK, RELOAD_RESUME, RELOAD_BOLT = Shared.RELOAD_NONE, Shared.RELOAD_TACTICAL, Shared.RELOAD_QUICK, Shared.RELOAD_RESUME, Shared.RELOAD_BOLT
local RELOAD_INSERT = Shared.RELOAD_INSERT
local STAGE_NONE, STAGE_MAGOUT, STAGE_BOLT = Shared.STAGE_NONE, Shared.STAGE_MAGOUT, Shared.STAGE_BOLT

-- Reloading

function SWEP:IsReloading()
    return self:GetReloadState() ~= RELOAD_NONE
end

function SWEP:CanStartReload()
    if self:IsReloading() or self:ActionBlocks("reload") or self:GetGLMode() or self:IsGLReloading() then return false end

    local owner = self:GetOwner()
    if IsValid(owner) and owner.SandSwepMenuOpen then return false end

    if self:GetReloadStage() == STAGE_BOLT then return true end

    if #self:GetMags() == 0 then return false end
    if not self:PoolsAmmo() and not self.Rocket then return true end

    return self:GetRoundsInMag() < self:GetMagSize()
end

function SWEP:NeedsEmptyReload()
    return self:Clip1() <= 0 or (self:IsBoltAction() and self:GetNeedsCycle()) or false
end

function SWEP:StartReload()
    if self:ActionBlocks("reload") then return end
    if not self:CanStartReload() then return end
    if self:UsesInsertReload() then return self:StartInsertReload() end
    if self:GetReloadStage() ~= STAGE_NONE and self:ResumeStagedReload() then return end

    local ct = CurTime()
    local empty = self:NeedsEmptyReload()
    local animName = empty and "reload_empty" or "reload"
    if not self:HasAnim(animName) then return end

    local speed = self:GetReloadSpeed()
    local commit, len = self:GetAnimCommit(animName)
    local duration = commit / speed
    local soundDuration = len / speed
    self:PlayAnim(animName, speed)

    local entry = self:IsBoltAction() and empty and self:GetAnimEntry(animName)
    if entry and entry.Eject then self:SetEjectAt(ct + entry.Eject / speed) end

    self:BeginAction("reload", duration)
    self:SetReloadState(RELOAD_TACTICAL)
    self:SetReloadEmpty(empty)
    self:SetNextPrimaryFire(ct + duration)
    self:StartSoundSet(empty and "reload_empty" or "reload", soundDuration)

    local owner = self:GetOwner()
    owner:SetAnimation(PLAYER_RELOAD)

    local fast = owner:IsPlayer() and owner:GetInfoNum("cl_sandswep_fast_reload", 0) or 0
    if fast == 1 or (fast == 2 and empty) then self:UpgradeToQuickReload() end
end

function SWEP:UpgradeToQuickReload()
    if self:GetBipodDeployed() then return end

    local ct = CurTime()
    local start = self:GetActionStart()
    if ct - start > self.QuickReloadWindow then return end

    local empty = self:GetReloadEmpty()
    local soundSet = empty and "reload_quick_empty" or "reload_quick"
    local animName = empty and "reload_speed_empty" or "reload_speed"

    if not self:HasAnim(animName) then return end

    local speed = self:GetReloadSpeed()
    local commit, len = self:GetAnimCommit(animName)
    local animT = (ct - start) * speed                  -- anim-seconds already played
    local cycle = math.Clamp(animT / math.max(len, 0.01), 0, 0.95)
    local finish = math.max(start + commit / speed, ct + 0.1)

    self:SetReloadState(RELOAD_QUICK)
    self:SetActionUntil(finish)
    self:SetNextPrimaryFire(finish)
    self:PlayAnim(animName, speed, cycle)
    self:SwitchSoundSet(soundSet, len / speed)
end

function SWEP:FinishReload()
    local state = self:GetReloadState()
    if state == RELOAD_INSERT then return self:AdvanceInsertReload() end

    local quick = state == RELOAD_QUICK
    self:SetReloadChainAt(0)
    self:ClearAction("reload")
    self:SetReloadState(RELOAD_NONE)
    self:SetReloadSaveTime(0)

    if state == RELOAD_BOLT then          -- staged: only the bolt release was left
        self:SetReloadStage(STAGE_NONE)
        return
    end
    self:SetReloadStage(STAGE_NONE)

    local mags = table.Copy(self:GetMags())
    if #mags == 0 then return end

    local clip = self:Clip1()
    local chambered = (self.ChamberRound and clip > 0 and not self:GetNeedsCycle()) and 1 or 0
    local oldMag = clip - chambered
    local size = self:GetMagSize()
    local newMag
    if self:PoolsAmmo() then
        local total = self:GetSpareRounds() + ((oldMag > 0 and not quick) and oldMag or 0)
        newMag = math.min(size, total)
        mags = { total - newMag }
    else
        newMag = table.remove(mags, 1) -- fullest
        if newMag > size then
            mags[#mags + 1] = newMag - size
            newMag = size
        end
        if oldMag > 0 and not quick then
            mags[#mags + 1] = oldMag
        end
    end
    self:SetNeedsCycle(false)

    self:SetMags(mags)
    self:SetClip1(newMag + chambered)
    self:OnReloadFinished(quick, oldMag, newMag)
    hook.Run("SandSwep_ReloadFinished", self, quick, oldMag, newMag)
end

function SWEP:CancelReload()
    if not self:IsReloading() then return end

    self:SetEjectAt(0)
    self:SetReloadChainAt(0)
    self:ClearAction("reload")
    self:SetReloadState(RELOAD_NONE)
    self:StopSoundSet()
    self:SetNextPrimaryFire(CurTime())
    self:SetVMPlaybackRate(1)
end

-- Staged reloads

function SWEP:GetCurrentReloadEntry()
    local state = self:GetReloadState()
    local empty = self:GetReloadEmpty()

    local name
    if state == RELOAD_QUICK then
        name = empty and "reload_speed_empty" or "reload_speed"
    else
        name = empty and "reload_empty" or "reload"
    end

    return self:GetAnimEntry(name)
end

function SWEP:GetReloadAnimTime()
    return (CurTime() - self:GetActionStart()) * self:GetReloadSpeed()
end

function SWEP:GetBeltLinks()
    local belt = self.BeltBodygroup
    if not belt then return 0 end

    local max = belt.Max or 12
    if self:IsMagHidden() then return 0 end

    local rounds = self:GetRoundsInMag()
    if self:IsReloading() then
        local entry = self:GetCurrentReloadEntry()
        local fresh = istable(entry) and (entry.ShowMagAt or entry.ResumeAt or entry.MagIn)
        if fresh and self:GetReloadAnimTime() >= fresh then rounds = max end
    end

    return math.Clamp(rounds, 0, max)
end

function SWEP:GetLiveBelt()
    local cfg = self.LiveBelt
    if not cfg then return end

    local cache = self:AttCache()
    if cache.liveBelt == nil then
        cache.liveBelt = false
        for _, _, def in self:IterAttachments() do
            if def.LiveBelt then cache.liveBelt = true break end
        end
    end

    if cache.liveBelt then return cfg end
end

function SWEP:GetLiveBeltRounds()
    if self:IsMagHidden() then return 0 end

    local rounds = self:GetRoundsInMag()
    if self:IsReloading() then
        local entry = self:GetCurrentReloadEntry()
        local fresh = istable(entry) and (entry.ShowMagAt or entry.ResumeAt or entry.MagIn)
        if fresh and self:GetReloadAnimTime() >= fresh then rounds = self:GetMagSize() end
    end

    return math.max(rounds, 0)
end

function SWEP:GetBeltLinksShown()
    if self:GetBeltLinks() <= 0 then return 0 end

    if self:IsReloading() then
        local entry = self:GetCurrentReloadEntry()
        local hideWindow = istable(entry) and entry.HideLinks
        if hideWindow then
            local animTime = self:GetReloadAnimTime()
            if animTime >= hideWindow[1] and animTime < hideWindow[2] then return 0 end
        end
    end

    return 1
end

function SWEP:GetCoverOpenAt(entry, animTime)
    local cover = istable(entry) and entry.Cover
    if not cover then return 0 end

    if animTime <= cover[1] or animTime >= cover[4] then return 0 end
    if animTime < cover[2] then return (animTime - cover[1]) / math.max(cover[2] - cover[1], 0.001) end
    if animTime <= cover[3] then return 1 end

    return 1 - (animTime - cover[3]) / math.max(cover[4] - cover[3], 0.001)
end

function SWEP:GetPlayingCoverOpen()
    if not self:IsReloading() then return 0 end

    local state = self:GetReloadState()
    local entry
    if state == RELOAD_RESUME then
        entry = self:GetAnimEntry(self:GetReloadEmpty() and "reload_empty_resume" or "reload_resume")
    else
        entry = self:GetCurrentReloadEntry()
    end

    return self:GetCoverOpenAt(entry, self:GetReloadAnimTime())
end

function SWEP:StartCoverClose()
    if not self.CoverPose then return end

    local open = self:GetPlayingCoverOpen()
    if open > 0.01 then self:SetCoverClose(Vector(CurTime(), open, 0)) end
end

function SWEP:GetCoverPoseValue()
    local cfg = self.CoverPose
    if not cfg then return 0 end

    local closing = self:GetCoverClose()
    if closing.x <= 0 then return 0 end

    local frac = SinceTime(closing.x) / math.max(cfg.CloseTime or 0.35, 0.01)
    if frac >= 1 then return 0 end

    return closing.y * (1 - frac * frac)
end

function SWEP:ApplyCoverPose(vm)
    local cfg = self.CoverPose
    if not cfg or not IsValid(vm) then return end

    local value = self:GetCoverPoseValue()
    if value <= 0 and not vm.SandSwepCover then return end

    vm:SetPoseParameter(cfg.Param or "cover", value)
    vm.SandSwepCover = value > 0 or nil
    if CLIENT then vm:InvalidateBoneCache() end
end

function SWEP:IsMagHidden()
    local stage = self:GetReloadStage()
    if stage == STAGE_MAGOUT then return true end
    if self:GetReloadState() ~= RELOAD_RESUME then return false end

    local entry = self:GetCurrentReloadEntry()
    return entry ~= nil and entry.ShowMagAt ~= nil and self:GetReloadAnimTime() < entry.ShowMagAt
end

local function ReloadDebug(wep, fmt, ...)
    if not Developer() then return end
    print(string.format("[sandswep %s %s] " .. fmt, SERVER and "SV" or "CL", wep:GetClass(), ...))
end

function SWEP:InterruptReload()
    if not self:IsReloading() then return end
    if self:GetReloadState() == RELOAD_INSERT then return self:InterruptInsertReload() end

    self:StartCoverClose()
    local state = self:GetReloadState()
    local animTime = self:GetReloadAnimTime()

    if state == RELOAD_BOLT then                     -- stopped again during the bolt release
        self:SetReloadSaveTime(animTime)
        return self:CancelReload()
    end

    local entry = self.StagedReloads and self:GetCurrentReloadEntry()
    if not entry or not entry.MagOut or not entry.MagIn then
        ReloadDebug(self, "interrupt: state %d, no MagOut/MagIn marks on this anim -> cancelled", state)
        return self:CancelReload()
    end
    if animTime < entry.MagOut and state ~= RELOAD_RESUME then
        ReloadDebug(self, "interrupt: anim t %.2fs, before mag out (%.2f) -> cancelled", animTime, entry.MagOut)
        return self:CancelReload()
    end

    local saveTime = state == RELOAD_QUICK and 0 or animTime
    ReloadDebug(self, "interrupt: state %d, anim t %.2fs (mag out %.2f, mag in %.2f)", state, animTime, entry.MagOut, entry.MagIn)

    if animTime >= entry.MagIn then
        local empty = self:GetReloadEmpty()
        local boltEntry = empty and self:GetAnimEntry("reload_empty")
        self:FinishReload()
        if empty and boltEntry and (boltEntry.BoltAt or self:HasAnim("reload_boltrelease")) then
            self:SetReloadStage(STAGE_BOLT)
            self:SetReloadSaveTime(saveTime)
        end
        self:StopSoundSet()
        self:SetNextPrimaryFire(CurTime())
        self:SetVMPlaybackRate(1)
        return
    end

    if self:GetBipodDeployed() then
        ReloadDebug(self, "interrupt: bipod deployed -> cancelled, no stage")
        return self:CancelReload()
    end

    local clip = self:Clip1()
    local chambered = (self.ChamberRound and clip > 0 and self:GetReloadStage() ~= STAGE_BOLT and not self:GetNeedsCycle()) and 1 or 0
    local oldMag = clip - chambered
    if oldMag > 0 and state ~= RELOAD_QUICK then
        local mags = table.Copy(self:GetMags())
        mags[#mags + 1] = oldMag
        self:SetMags(mags)
    end

    self:SetClip1(chambered)
    self:SetReloadStage(STAGE_MAGOUT)
    self:SetReloadSaveTime(saveTime)
    self:CancelReload()
end

function SWEP:ResumeFromStageAnim(empty, animName, entry, speed)
    local startName = empty and "reload_empty_start" or "reload_start"
    if not entry.InsertAt or not self:HasAnim(startName) then return false end

    local commit, len = self:GetAnimCommit(animName)
    local insert = math.Clamp(entry.InsertAt, 0, math.max(commit - 0.05, 0))
    local ct = CurTime()
    local chainAt = ct + self:GetAnimLength(startName) / speed
    local start = chainAt - insert / speed

    self:SetReloadSaveTime(0)
    self:SetReloadResumePending(false)
    ReloadDebug(self, "resume: %s, then %s from its insert at %.2fs", startName, animName, insert)

    self:PlayAnim(startName, speed)
    self:BeginAction("reload", (start + commit / speed) - ct)
    self:SetActionStart(start)
    self:SetReloadChainAt(chainAt)
    self:SetReloadState(RELOAD_RESUME)
    self:SetReloadEmpty(empty)
    self:SetNextPrimaryFire(start + commit / speed)
    self:StartSoundSet(empty and "reload_empty" or "reload", len / speed)
    self:SetSoundSetStart(start)
    self:SetSoundSetLast(insert / speed)
    self:SetReloadStage(STAGE_NONE)
    self:GetOwner():SetAnimation(PLAYER_RELOAD)

    return true
end

function SWEP:ResumeBoltRelease(speed)
    if not self:HasAnim("reload_boltrelease") then return false end

    local commit, len = self:GetAnimCommit("reload_boltrelease")
    self:SetReloadSaveTime(0)
    self:SetReloadResumePending(false)
    ReloadDebug(self, "resume: bolt release only")

    self:PlayAnim("reload_boltrelease", speed)
    self:BeginAction("reload", commit / speed)
    self:SetReloadState(RELOAD_BOLT)
    self:SetReloadEmpty(true)
    self:SetNextPrimaryFire(CurTime() + commit / speed)
    self:StartSoundSet("reload_bolt", len / speed)
    self:GetOwner():SetAnimation(PLAYER_RELOAD)

    return true
end

function SWEP:UpdateReloadChain()
    local chainAt = self:GetReloadChainAt()
    if chainAt <= 0 or CurTime() < chainAt then return end

    self:SetReloadChainAt(0)
    if self:GetReloadState() ~= RELOAD_RESUME then return end

    local animName = self:GetReloadEmpty() and "reload_empty" or "reload"
    local entry = self:GetAnimEntry(animName)
    if not entry or not entry.InsertAt then return end

    local speed = self:GetReloadSpeed()
    local len = self:GetAnimLength(animName)
    self:PlayAnim(animName, speed, entry.InsertAt / math.max(len, 0.01))
end

function SWEP:ResumeStagedReload()
    local stage = self:GetReloadStage()
    local bolt = stage == STAGE_BOLT
    local empty = bolt or self:NeedsEmptyReload()
    local animName = empty and "reload_empty" or "reload"
    local speed = self:GetReloadSpeed()

    if bolt and self:ResumeBoltRelease(speed) then return true end
    if not self:HasAnim(animName) then
        if bolt then
            self:SetReloadStage(STAGE_NONE)
            return true
        end
        return false
    end

    local entry = self:GetAnimEntry(animName)
    if not bolt and self:ResumeFromStageAnim(empty, animName, entry, speed) then return true end

    local commit, len = self:GetAnimCommit(animName)
    local from = self:GetReloadSaveTime()
    if bolt then
        if from <= 0 then from = entry.BoltAt or 0 end
    else
        from = math.max(from, entry.ResumeAt or 0)
    end

    local tailName = bolt and "reload_empty_bolt" or (empty and "reload_empty_resume" or "reload_resume")
    local tail = self:HasAnim(tailName) and self:GetAnimEntry(tailName)
    if tail and tail.From then from = tail.From end
    from = math.Clamp(from, 0, math.max(commit - 0.05, 0))

    self:SetReloadSaveTime(0)
    self:SetReloadResumePending(false)
    ReloadDebug(self, "resume: stage %d, %s from %.2fs (%s)", stage, animName, from,
        tail and ("sequence " .. tailName) or string.format("cycle %.2f of %.2fs", from / math.max(len, 0.01), len))

    local ct = CurTime()
    local start = ct - from / speed                -- as if it had started back then
    if tail then
        self:PlayAnim(tailName, speed)
    else
        self:PlayAnim(animName, speed, from / math.max(len, 0.01))
    end

    self:BeginAction("reload", (start + commit / speed) - ct)
    self:SetActionStart(start)
    self:SetReloadState(bolt and RELOAD_BOLT or RELOAD_RESUME)
    self:SetReloadEmpty(empty)
    self:SetNextPrimaryFire(start + commit / speed)
    self:StartSoundSet((tail and tail.Sounds) or (empty and "reload_empty" or "reload"), len / speed)
    self:SetSoundSetStart(start)
    self:SetSoundSetLast(from / speed)
    if not bolt then self:SetReloadStage(STAGE_NONE) end   -- mag visibility now follows IsMagHidden
    self:GetOwner():SetAnimation(PLAYER_RELOAD)

    return true
end

function SWEP:OnReloadFinished(wasQuick, oldMagRounds, newMagRounds) end
