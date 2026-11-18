local Shared = SandSwep.BaseShared
local RELOAD_TACTICAL, RELOAD_INSERT, SinceTime = Shared.RELOAD_TACTICAL, Shared.RELOAD_INSERT, Shared.SinceTime

-- Hold breath

function SWEP:GetBreath()
    local startBreath = self:GetFocusChange() > 0 and self:GetFocusBreath() or 1
    local elapsed = SinceTime(self:GetFocusChange())

    if self:GetFocusing() then
        return math.max(startBreath - elapsed / math.max(self.FocusDuration, 0.1), 0)
    end

    return math.min(startBreath + elapsed / math.max(self.FocusRecoverTime, 0.1), 1)
end

function SWEP:GetFocusProgress()
    local elapsed = SinceTime(self:GetFocusChange())
    local blend = math.Approach(self:GetFocusFrom(), self:GetFocusing() and 1 or 0, elapsed / math.max(self.FocusEaseTime, 0.01))

    return blend * blend * (3 - 2 * blend)
end

function SWEP:SetFocusState(on)
    if on == self:GetFocusing() then return end

    local breath = self:GetBreath()
    local elapsed = SinceTime(self:GetFocusChange())
    local raw = math.Approach(self:GetFocusFrom(), self:GetFocusing() and 1 or 0, elapsed / math.max(self.FocusEaseTime, 0.01))

    self:SetFocusFrom(raw)
    self:SetFocusBreath(breath)
    self:SetFocusChange(CurTime())
    self:SetFocusing(on)
end

function SWEP:UpdateFocus(owner)
    local breath = self:GetBreath()
    if self:GetFocusExhausted() and not self:GetFocusing() and breath >= self.FocusMinBreath then
        self:SetFocusExhausted(false)
    end

    local want = owner:KeyDown(IN_SPEED) and self:GetAiming() and self:GetAimProgress() > 0.6
        and not self:GetFocusExhausted()
    if self:GetFocusing() and breath <= 0 then
        want = false
        self:SetFocusExhausted(true)
    end

    self:SetFocusState(want)
end

-- Sprinting

function SWEP:GetSprintProgress()
    local sprinting = self:GetSprinting()
    local time = sprinting and self.SprintInTime or self.SprintOutTime
    local elapsed = SinceTime(self:GetSprintChangeTime())

    return math.Approach(self:GetSprintFrom(), sprinting and 1 or 0, elapsed / math.max(time, 0.01))
end

function SWEP:WantsSprint(owner)
    if not owner:KeyDown(IN_SPEED) then return false end

    local moving = owner:KeyDown(IN_FORWARD) or owner:KeyDown(IN_BACK)
        or owner:KeyDown(IN_MOVELEFT) or owner:KeyDown(IN_MOVERIGHT)
    if not moving then return false end

    if self:GetBipodDeployed() then return false end
    if self:GetAiming() then return false end      -- Shift while aimed = hold breath
    if not owner:OnGround() or owner:Crouching() or owner:WaterLevel() >= 2 then return false end
    if owner:GetMoveType() ~= MOVETYPE_WALK or owner:InVehicle() then return false end

    return owner:GetVelocity():Length2D() > owner:GetWalkSpeed() * 0.6
end

function SWEP:UsesSprintAnims()
    local owner = self:GetOwner()
    local vm = IsValid(owner) and owner:IsPlayer() and owner:GetViewModel()
    if not IsValid(vm) then return false end

    self:GetActiveAnimSets()
    local key, model = self._animSetKey, vm:GetModel()
    if self._sprintAnimKey ~= key or self._sprintAnimModel ~= model then
        self._sprintAnimKey, self._sprintAnimModel = key, model
        self._sprintAnims = self:HasAnim("sprint") and self:HasAnim("sprint_in") and self:HasAnim("sprint_out")
    end

    return self._sprintAnims
end

function SWEP:IsActionBusy()
    return self:IsReloading() or self:ActionBlocks("sprint")
end

-- Bipod
local function BipodSmooth(t)
    t = math.Clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

function SWEP:HasBipod()
    if not (istable(self.Bipod) and self.Bipod.Feet ~= nil) then return false end

    for slot in pairs(self.Bipod.BlockedBy or {}) do
        if self:GetSlotAttachment(slot) then return false end
    end

    return true
end

function SWEP:GetBipodFovScale(fov)
    local ply = self:GetOwner()
    fov = fov or (IsValid(ply) and ply:IsPlayer() and ply:GetFOV()) or 75
    local vmFov = self.ViewModelFOV or 75

    return math.tan(math.rad(math.Clamp(fov, 1, 170) * 0.5)) / math.tan(math.rad(math.Clamp(vmFov, 1, 170) * 0.5))
end

local function PoseFeet(feet, offset, ang)
    local rot = Angle(0, 0, 0)
    local RIGHT, FWD, UP = Vector(0, -1, 0), Vector(1, 0, 0), Vector(0, 0, 1)
    rot:RotateAroundAxis(RIGHT, ang.p)
    rot:RotateAroundAxis(UP, ang.y)
    rot:RotateAroundAxis(FWD, ang.r)

    local rotated = Vector(feet.y, -feet.x, feet.z)
    rotated:Rotate(rot)

    return Vector(-rotated.y + offset.x, rotated.x + offset.y, rotated.z + offset.z)
end

local cvBipodCentred
if CLIENT then
    cvBipodCentred = CreateClientConVar("cl_sandswep_bipod_centered", "0", true, true,
        "Centred bipod hold")
end
function SWEP:GetBipodPose()
    local cfg = self.Bipod
    if not cfg then return end

    local owner = self:GetOwner()
    local centred
    if CLIENT then
        cvBipodCentred = cvBipodCentred or GetConVar("cl_sandswep_bipod_centered")
        centred = cvBipodCentred and cvBipodCentred:GetBool()
    elseif IsValid(owner) and owner:IsPlayer() then
        centred = owner:GetInfoNum("cl_sandswep_bipod_centered", 0) ~= 0
    end

    if centred then return cfg.Pose end
    return cfg.SidePose
end

function SWEP:GetBipodFeet(aimT)
    local feet = self.Bipod.Feet
    aimT = aimT or 0

    local pose = self:GetBipodPose()
    local rest = pose and PoseFeet(feet, pose.Pos or vector_origin, pose.Ang or angle_zero) or feet
    if aimT <= 0 then return rest end

    local sight = self:GetActiveSight()
    local aimed = PoseFeet(feet, sight.Pos or vector_origin, sight.Ang or angle_zero)

    return LerpVector(aimT, rest, aimed)
end

function SWEP:GetBipodWeight()
    if not self:HasBipod() then return 0 end

    local cfg = self.Bipod
    local change = self:GetBipodChange()

    if self:GetBipodDeployed() then
        local window = cfg.CamIn or { 0, 0.3 }
        return BipodSmooth((SinceTime(change) - window[1]) / math.max(window[2] - window[1], 0.01))
    end

    if change <= 0 then return 0 end

    local window = cfg.CamOut or { 0, 0.3 }
    return 1 - BipodSmooth((SinceTime(change) - window[1]) / math.max(window[2] - window[1], 0.01))
end

function SWEP:IsBipodBusy()
    if not self:HasBipod() then return false end

    local change = self:GetBipodChange()
    if change <= 0 then return false end

    local len = self:GetBipodDeployed() and (self.Bipod.InTime or 0.5) or (self.Bipod.OutTime or 0.5)
    return CurTime() < change + len
end

function SWEP:GetBipodView(eye, ang, fov)
    local weight = self:GetBipodWeight()
    if weight <= 0 then return eye end

    local aim = self:GetAimProgress()
    local feet = self:GetBipodFeet(aim * aim * (3 - 2 * aim))
    local fovScale = self:GetBipodFovScale(fov)
    local cam = self:GetBipodPos()
        - ang:Forward() * feet.y
        - ang:Right() * (feet.x * fovScale)
        - ang:Up() * (feet.z * fovScale)

    return LerpVector(weight, eye, cam)
end

function SWEP:GetBulletSource()
    local owner = self:GetOwner()
    local src = owner:GetShootPos()

    if owner:IsPlayer() and self:GetBipodWeight() > 0 then
        src = self:GetBipodView(src, owner:EyeAngles())
    end

    return src
end

function SWEP:FindBipodRest()
    local ply = self:GetOwner()
    local cfg = self.Bipod
    local eye, ang = ply:GetShootPos(), ply:EyeAngles()

    local offset, fovScale = cfg.Feet, self:GetBipodFovScale()
    local feet = eye
        + ang:Forward() * offset.y
        + ang:Right() * (offset.x * fovScale)
        + ang:Up() * (offset.z * fovScale)

    local up, down = cfg.MaxRise or 6, -(cfg.MinRise or -16)
    local top = feet + Vector(0, 0, up + 2)
    local los = SandSwep.TraceLine(eye, top, ply, MASK_SOLID)
    if los.Hit then return end

    local tr = SandSwep.TraceLine(top, feet - Vector(0, 0, down), ply, MASK_SOLID)
    if not tr.Hit or tr.StartSolid or tr.HitNormal.z < 0.7 then return end

    return tr.HitPos
end

function SWEP:CanDeployBipod()
    if not self:HasBipod() or self:GetBipodDeployed() or self:IsBipodBusy() then return false end

    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsPlayer() or not ply:OnGround() or ply:InVehicle() then return false end
    if ply:GetMoveType() ~= MOVETYPE_WALK or ply:GetVelocity():Length2D() > 30 then return false end
    if self:IsActionBusy() or self:GetSprintProgress() > 0 or self:GetGLMode() or self:ActionBlocks("bipod") then return false end

    return true
end

function SWEP:PlayBipodAnim(name, fallback)
    local ct = CurTime()
    local len = fallback or 0.5
    if self:HasAnim(name) then
        local _
        _, len = self:GetAnimCommit(name)
        self:PlayAnim(name)
    end

    self:BeginAction(name, len)
    self:SetNextPrimaryFire(math.max(self:GetNextPrimaryFire(), ct + len))
    self:StartSoundSet(name, len)
end

function SWEP:DeployBipod()
    if not self:CanDeployBipod() then return false end

    local pos = self:FindBipodRest()
    if not pos then return false end

    local ply = self:GetOwner()
    local ang = ply:EyeAngles()

    self:SetBipodPos(pos)
    self:SetBipodOrigin(ply:GetPos())
    self:SetBipodYaw(ang.y)
    self:SetBipodPitch(ang.p)
    self:SetBipodCrouched(ply:KeyDown(IN_DUCK) or ply:Crouching())
    self:SetBipodDuckUp(not ply:KeyDown(IN_DUCK))
    self:SetBipodDeployed(true)
    self:SetBipodChange(CurTime())

    self:SetBurstLeft(0)
    self:SetFocusState(false)
    self:PlayBipodAnim("bipod_in", self.Bipod.InTime)

    return true
end

function SWEP:StowBipod(animate)
    if not self:GetBipodDeployed() then return end

    if self:IsReloading() then self:InterruptReload() end
    if self:IsMagChecking() then self:StopAction() end
    self:SetBurstLeft(0)
    self:SetBipodDeployed(false)

    if animate then
        self:SetBipodChange(CurTime())
        self:PlayBipodAnim("bipod_out", self.Bipod.OutTime)
    else
        self:SetBipodChange(0)
    end
end

function SWEP:ToggleBipod()
    if not self:HasBipod() or self:IsBipodBusy() then return end

    if self:GetBipodDeployed() then
        self:StowBipod(true)
    else
        self:DeployBipod()
    end
end

function SWEP:ClampBipodAngles(ang)
    local cfg = self.Bipod
    local baseYaw, basePitch = self:GetBipodYaw(), self:GetBipodPitch()
    local limit = cfg.YawLimit or 90

    local yawDiff = math.AngleDifference(ang.y, baseYaw)
    local pitch = math.Clamp(ang.p, math.max(basePitch - (cfg.PitchUp or 30), -89), math.min(basePitch + (cfg.PitchDown or 30), 89))
    if math.abs(yawDiff) <= limit and pitch == ang.p then return end

    return Angle(pitch, baseYaw + math.Clamp(yawDiff, -limit, limit), ang.r)
end

local function DeployedBipodWeapon(ply)
    local wep = IsValid(ply) and ply:GetActiveWeapon()
    if IsValid(wep) and wep.IsSandSwep and wep.HasBipod and wep:HasBipod() and wep:GetBipodDeployed() then return wep end
end

hook.Add("StartCommand", "SandSwep_BipodClamp", function(ply, cmd)
    local wep = DeployedBipodWeapon(ply)
    if not wep then return end

    local clamped = wep:ClampBipodAngles(cmd:GetViewAngles())
    if clamped then cmd:SetViewAngles(clamped) end
end)

if CLIENT then
    hook.Add("CreateMove", "SandSwep_BipodClamp", function(cmd)
        local wep = DeployedBipodWeapon(LocalPlayer())
        if not wep then return end

        local clamped = wep:ClampBipodAngles(cmd:GetViewAngles())
        if clamped then cmd:SetViewAngles(clamped) end
    end)
end

local function BipodSetupMove(wep, mv)
    local moving = mv:KeyDown(IN_FORWARD) or mv:KeyDown(IN_BACK) or mv:KeyDown(IN_MOVELEFT)
        or mv:KeyDown(IN_MOVERIGHT) or mv:KeyDown(IN_JUMP)
    local duck = mv:KeyDown(IN_DUCK)

    local duckChange
    if wep:GetBipodCrouched() then
        if not duck then
            if not wep:GetBipodDuckUp() then wep:SetBipodDuckUp(true) end
        elseif wep:GetBipodDuckUp() then
            duckChange = true                       -- a new press of duck: stow
        end
        mv:SetButtons(bit.bor(mv:GetButtons(), IN_DUCK))   -- stay crouched without holding the key
    else
        duckChange = duck
    end

    if moving or duckChange then
        if not wep:IsBipodBusy() then wep:StowBipod(true) end
        if wep:GetBipodDeployed() then
            mv:SetForwardSpeed(0)
            mv:SetSideSpeed(0)
            mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)))
        end
    else
        mv:SetForwardSpeed(0)
        mv:SetSideSpeed(0)
    end
end

function SWEP:PlaySprintTransition(sprinting, progress)
    if not self:UsesSprintAnims() or self:IsActionBusy() then return end

    if sprinting then
        local len = self:GetAnimLength("sprint_in")
        self:PlayAnim("sprint_in", len / math.max(self.SprintInTime, 0.05), math.Clamp(progress, 0, 0.98))
    else
        local len = self:GetAnimLength("sprint_out")
        self:PlayAnim("sprint_out", len / math.max(self.SprintOutTime, 0.05), math.Clamp(1 - progress, 0, 0.98))
    end
end

function SWEP:SetSprintState(sprinting)
    if sprinting == self:GetSprinting() then return end

    local progress = self:GetSprintProgress()
    self:SetSprintFrom(progress)
    self:SetSprintChangeTime(CurTime())
    self:SetSprinting(sprinting)

    if sprinting then
        self:SetBurstLeft(0)
        self:SetAimToggled(false)
        if self.SprintInterruptsReload and self:IsReloading() then self:InterruptReload() end
    end

    self:PlaySprintTransition(sprinting, progress)
end

function SWEP:ResetSprint()
    self:SetSprinting(false)
    self:SetSprintFrom(0)
    self:SetSprintChangeTime(0)
end

function SWEP:HandleReloadKey(mv)
    local down = mv:KeyDown(IN_RELOAD)
    local wasHeld = self:GetReloadKeyHeld()
    local ct = CurTime()
    local pressTime = self:GetReloadPressTime()

    if down and not wasHeld then
        self:SetReloadKeyHeld(true)
        if self:GetGLMode() then
            self:StartGLReload()
        elseif self:GetReloadState() == RELOAD_TACTICAL then
            self:UpgradeToQuickReload()
        elseif self:GetReloadState() == RELOAD_INSERT then
            self:UpgradeInsertToClip()
        elseif not self:IsReloading() and not self:IsMagChecking() then
            self:SetReloadPressTime(ct)
        end
        return
    end

    if wasHeld and not down then
        self:SetReloadKeyHeld(false)
        if pressTime > 0 then
            self:SetReloadPressTime(0)
            if not self:IsMagChecking() then self:StartReload() end
        end
        return
    end

    if not down or pressTime <= 0 then return end

    if self:IsMagChecking() or self:IsReloading() then
        self:SetReloadPressTime(0)
    elseif ct - pressTime >= self.MagCheckHoldTime then
        self:SetReloadPressTime(0)
        self:StartMagCheck()
    end
end

local function AimSetupMove(ply, wep, mv)
    local aim = wep:GetAimProgress()
    if aim <= 0 then return end

    local mult = Lerp(aim, 1, wep.AimMoveSpeed * (wep.GetStatMult and wep:GetStatMult("AimMoveSpeed") or 1))
    mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mult)
    mv:SetMaxSpeed(mv:GetMaxSpeed() * mult)

    if wep:GetAiming() then
        local cap = ply:GetWalkSpeed() * mult
        mv:SetMaxClientSpeed(math.min(mv:GetMaxClientSpeed(), cap))
        mv:SetMaxSpeed(math.min(mv:GetMaxSpeed(), cap))
    end
end

hook.Remove("SetupMove", "SandSwep_Bipod")         -- the old separate hooks (Lua refresh)
hook.Remove("SetupMove", "SandSwep_ReloadKey")
hook.Remove("SetupMove", "SandSwep_AimMove")
hook.Add("SetupMove", "SandSwep_Move", function(ply, mv)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not wep.IsSandSwep then return end

    if wep.HandleReloadKey then wep:HandleReloadKey(mv) end
    if wep.HasBipod and wep:HasBipod() and wep:GetBipodDeployed() then BipodSetupMove(wep, mv) end
    if wep.GetAimProgress then AimSetupMove(ply, wep, mv) end
end)
