local Shared = SandSwep.BaseShared
local RELOAD_NONE, STAGE_NONE, STAGE_MAGOUT = Shared.RELOAD_NONE, Shared.STAGE_NONE, Shared.STAGE_MAGOUT
local cvFirstDraw = CreateConVar("sv_sandswep_first_draw", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY),
    "Play the first draw animation the first time a weapon is equipped (0 = always the normal draw)", 0, 1)

-- Input / think

function SWEP:Reload() end

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() then return end

    local ct = CurTime()
    self:UpdateBurstTail()
    self:UpdateShotTail()

    self:UpdateAction()
    if self:GetHolsterAt() > 0 then
        self:ProcessSoundSet()
        self:UpdateHolster(owner, ct)
        return
    end

    self:UpdateReloadChain()
    self:UpdateBoltCycle(owner, ct)

    if self:GetReloadResumePending() and not self:IsActionBusy() then
        local stage = self:GetReloadStage()
        local cancel = stage == STAGE_NONE or self:GetGLMode() or (stage == STAGE_MAGOUT and #self:GetMags() == 0)

        if cancel then
            self:SetReloadResumePending(false)
        elseif not self:GetSprinting() and self:CanStartReload() then
            self:SetReloadResumePending(false)
            self:StartReload()
        end
    end

    self:UpdateFocus(owner)
    self:SetSprintState(self:WantsSprint(owner))
    self:UpdateAimInput(owner)

    if self:GetTriggerHeld() and not owner:KeyDown(IN_ATTACK) then
        self:SetTriggerHeld(false)
    end
    if self:GetDryClicked() and not owner:KeyDown(IN_ATTACK) then
        self:SetDryClicked(false)
    end

    self:ProcessSoundSet()

    self:UpdateIdleFidget(owner, ct)

    local idleAt = self:GetIdleTime()
    if idleAt > 0 and ct >= idleAt and not self:IsReloading() then
        self:SetIdleTime(0)
        self:PlayIdleAnim()
    end

    if self:GetBurstLeft() > 0 then
        if self:IsReloading() or self:IsSafe() or self:GetSprinting() then
            self:SetBurstLeft(0)
        elseif ct >= self:GetNextPrimaryFire() then
            self:FireShot()
        end
    end

    if SERVER and self.CoverPose then self:ApplyCoverPose(owner:GetViewModel()) end

    if SERVER and self:GetBipodDeployed() then
        if not owner:OnGround() or owner:GetPos():DistToSqr(self:GetBipodOrigin()) > 64 then
            self:StowBipod(true)
        end
    end

    if SERVER then
        self:UpdateGLState()
        self:UpdateMagSize()
        self:UpdateVMPoseParams()
        self:UpdateVMBodygroups()
    end

    if SERVER and (self._nextAbsorb or 0) <= ct then
        self._nextAbsorb = ct + 0.25
        self:AbsorbReserveAmmo()
    end
end

-- Spent casings
function SWEP:EjectCasing()
    if not istable(self.Ejects) and (not isstring(self.ShellModel) or self.ShellModel == "") then return end

    if SERVER then
        if game.SinglePlayer() then self:CallOnClient("EjectCasingClient") end
        return
    end

    if not IsFirstTimePredicted() then return end
    self:EjectCasingClient()
end

if SERVER then function SWEP:EjectCasingClient() end end

function SWEP:EjectLiveRound()
    if not istable(self.LiveEjects) then return end

    if SERVER then
        if game.SinglePlayer() then self:CallOnClient("EjectLiveRoundClient") end
        return
    end

    if not IsFirstTimePredicted() then return end
    self:EjectLiveRoundClient()
end

if SERVER then function SWEP:EjectLiveRoundClient() end end

-- Idle fidgets
function SWEP:IsFidgeting()
    return self:IsInAction("fidget")
end

function SWEP:UpdateIdleFidget(owner, ct)
    if (self.IdleFidgetTime or 0) <= 0 then return end

    local active = owner:KeyDown(IN_ATTACK) or owner:KeyDown(IN_ATTACK2) or owner:KeyDown(IN_RELOAD)
        or owner:KeyDown(IN_USE) or self:GetAiming() or self:GetAimProgress() > 0 or self:GetSprinting()
        or self:IsReloading() or self:ActionBlocks("fidget") or self:IsActionBusy() or self:GetGLMode()
        or self:IsGLReloading() or ct < self:GetNextPrimaryFire()
        or self:GetBurstLeft() > 0
    local fidgeting = self:IsFidgeting()

    if active then
        if self:GetIdleSince() ~= 0 then self:SetIdleSince(0) end
        if fidgeting then
            self:StopAction()
            if self.LastAnim == "fidget" then self:PlayIdleAnim() end
        end
        return
    end

    local idleSince = self:GetIdleSince()
    if idleSince <= 0 then
        self:SetIdleSince(ct)
        return
    end

    if fidgeting or ct - idleSince < self.IdleFidgetTime then return end

    if self:IsBoltLocked() or not self:HasAnim("fidget") then
        self:SetIdleSince(ct)
        return
    end

    self:PlayAnim("fidget")

    local finish = self:GetIdleTime()
    if finish <= ct then finish = ct + 2 end

    self:BeginAction("fidget", finish - ct)
    if self.SoundEvents and self.SoundEvents.fidget then self:StartSoundSet("fidget", finish - ct) end
    self:SetIdleSince(finish)
end

function SWEP:Deploy()
    local ct = CurTime()
    local owner = self:GetOwner()

    self:PrecacheSounds()

    self:SetReloadKeyHeld(IsValid(owner) and owner:IsPlayer() and owner:KeyDown(IN_RELOAD) or false)
    self:SetReloadPressTime(0)
    self:SetReloadState(RELOAD_NONE)
    self:SetHolsterAt(0)
    self:SetHolsterTo(NULL)
    self:StopAction()
    self:SetIdleTime(0)
    self:ResetSprint()
    self:SetBipodDeployed(false)
    self:SetBipodChange(0)
    self:SetCoverClose(Vector(0, 0, 0))

    if SERVER then
        self._svPoseKey, self._svModeKey, self._svBgList = nil, nil, nil
        self:UpdateVMBodygroups()
    end

    if CLIENT and next(self:GetAttachmentSlots()) then
        local vm = IsValid(owner) and owner:IsPlayer() and owner:GetViewModel()
        if IsValid(vm) then self:ApplyVMBodygroups(vm) end
    end

    local first = cvFirstDraw:GetBool() and not self:GetReadied() and self:HasAnim("ready")
    local staged = self:IsBoltLocked() and self:GetReloadStage() ~= STAGE_NONE and self:HasAnim("draw_locked")
    local name = first and "ready" or (staged and "draw_locked")
        or ((self:IsBoltLocked() and self:HasAnim("draw_empty")) and "draw_empty" or "draw")

    if self:HasAnim(name) then
        local commit, len = self:GetAnimCommit(name)
        self:PlayAnim(name)
        self:SetNextPrimaryFire(ct + commit)
        self:BeginAction(first and "ready" or "draw", commit)
        self:StartSoundSet(first and "ready" or "deploy", len)
    else
        self:SetNextPrimaryFire(ct + self.DeployTime)
        self:BeginAction("draw", self.DeployTime)
        self:StartSoundSet("deploy", self.DeployTime)
    end

    self:SetReadied(true)
    self:AbsorbReserveAmmo()

    self:SetIdleSince(ct)

    self:SetReloadResumePending(self.AutoResumeReload and self:GetReloadStage() ~= STAGE_NONE or false)
    return true
end

function SWEP:GetHolsterAnim()
    if self:IsBoltLocked() and self:HasAnim("holster_empty") then return "holster_empty" end
    if self:HasAnim("holster") then return "holster" end
end

function SWEP:WantsHolsterAnim(wep)
    if not self.HolsterAnim then return false end
    if not IsValid(wep) or wep == self then return false end

    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return false end
    if owner:GetActiveWeapon() ~= self then return false end

    return self:GetHolsterAnim() ~= nil
end

function SWEP:ResetHolsterState()
    self:StopSoundSet()
    self:SetAiming(false)
    self:SetAimFrom(0)
    self._aimMemo = nil
    self:SetAimToggled(false)
    self:SetPointAim(false)
    self:SetReloadPressTime(0)
    self:InterruptReload()
    self:StowBipod(false)
    self:SetBipodChange(0)
    self:SetReloadResumePending(false)
    self:StopAction()
    self:SetBurstLeft(0)
    self:ResetSprint()
    self:SetFocusState(false)
end

function SWEP:StartHolster(wep)
    local ct = CurTime()
    self:ResetHolsterState()

    local name = self:GetHolsterAnim()
    local rate = math.max(self.HolsterSpeed or 1, 0.01)
    local len = self:GetAnimLength(name) / rate

    self:PlayAnim(name, rate)
    self:SetIdleTime(0)
    self:BeginAction("holster", len)
    self:SetHolsterAt(ct + len)
    self:SetHolsterTo(wep)
    self:SetNextPrimaryFire(ct + len + 1)
    self:SetNextSecondaryFire(ct + len + 1)
    self:StartSoundSet("holster", len)

    if self:GetSoundSet() == 0 then
        local holsterSound = self.HolsterSound
            or (self.Slot == 1 and "SandSwep.SS.Holster_Sidearm_1p" or "SandSwep.SS.Holster_Rifle_1p")
        self:PlayEventSound({ s = holsterSound })
    end
end

function SWEP:UpdateHolster(owner, ct)
    local holsterAt = self:GetHolsterAt()
    if ct < holsterAt then return end

    local nextWep = self:GetHolsterTo()
    if not IsValid(nextWep) or nextWep:GetOwner() ~= owner then
        self:SetHolsterAt(0)
        self:SetHolsterTo(NULL)
        self:Deploy()
        return
    end

    if CLIENT then
        if not game.SinglePlayer() and owner == LocalPlayer() and IsFirstTimePredicted() then
            input.SelectWeapon(nextWep)
        end
    elseif game.SinglePlayer() or owner:IsBot() or ct >= holsterAt + 0.5 then
        owner:SelectWeapon(nextWep:GetClass())
    end
end

function SWEP:IsHolstering()
    return self:GetHolsterAt() > 0
end

function SWEP:Holster(wep)
    local holsterAt = self:GetHolsterAt()

    if holsterAt > 0 and CurTime() < holsterAt and IsValid(wep) and wep ~= self then
        self:SetHolsterTo(wep)
        return false
    end

    if holsterAt <= 0 and self:WantsHolsterAnim(wep) then
        self:StartHolster(wep)
        return false
    end

    self:SetHolsterAt(0)
    self:SetHolsterTo(NULL)

    if CLIENT then
        self:ReleaseDeadzone()
        self:RemoveVMAttachmentModels()
        self:ResetVMBodygroups()
    end

    self:ResetHolsterState()

    if SERVER then                                         -- the next weapon gets a clean viewmodel
        self:UpdateVMPoseParams(true)
        self:UpdateVMBodygroups(true)
    end

    return true
end

function SWEP:OnRemove()
    self:SetVMPlaybackRate(1)
    if SERVER then self:UpdateVMBodygroups(true) end

    if CLIENT then
        self:RemoveVMAttachmentModels()
        self:ResetVMBodygroups()
    end
end
