local VisualFrameTime = SandSwep.VisualFrameTime

if not CLIENT then return end

local Developer = SandSwep.BaseShared.Developer
local CopyBone = SandSwep.Math.CopyBone

local JUMP_NONE, JUMP_START, JUMP_AIR, JUMP_LAND = 0, 1, 2, 3
local JUMP_FADE = 0.12
local JUMP_START_SPEED = 60
local JUMP_START_AIRTIME = 0.2
local JUMP_SPRINT_DAMPEN = 0.5
local LAND_MIN, LAND_MAX = 0.4, 1.3
local LAND_FALL_SPEED = 600

local WALK_MIN_SPEED = 5
local WALK_BOB_MAX = 1.25
local WALK_BOB_EASE = 6
local WALK_DIR_EASE = 5
local STRIDE_RATE_MIN, STRIDE_RATE_MAX = 0.4, 1.8

local BREATH_MOVE_FADE = 1.5
local SIGHT_SWITCH_EASE = 3
local MAGCHECK_SWAY_SPEED, MAGCHECK_SWAY_DEG = 3, 1.5
local DEADZONE_SNAP_DEG = 30
local SPRINT_CAM_FADE = 0.25
local CAMERA_ANIM_EASE = 25
local CAMERA_ANIM_MAX = 15
local VM_FOV_MIN, VM_FOV_MAX = 20, 140

local cvSightDev = CreateClientConVar("cl_sandswep_sightdev", "0", false, false, "Sight editor mode")
local cvBob = CreateClientConVar("cl_sandswep_bob", "1", true, false, "Walk bob", 0, 3)
local cvBreath = CreateClientConVar("cl_sandswep_breath", "1", true, false, "Idle breathing", 0, 3)
local cvFreezeVM = CreateClientConVar("cl_sandswep_debug_freezevm", "0", false, false, "Freeze the viewmodel", 0, 1)
local cvDeadzone = GetConVar("sv_sandswep_freeaim")
local cvDZScale = GetConVar("sv_sandswep_freeaim_scale")
local cvRecenter = CreateClientConVar("cl_sandswep_deadzone_recenter", "0", true, false, "Free aim recentre speed", 0, 20)
local cvCrosshair = CreateClientConVar("cl_sandswep_crosshair", "1", true, false, "Aim dot")
local cvHideCrosshair = CreateClientConVar("cl_sandswep_hide_crosshair", "1", true, false, "Hide the default crosshair on SandSwep weapons")
local cvVMFov = CreateClientConVar("cl_sandswep_vmfov", "0", true, false, "Viewmodel FOV offset (hip)", -30, 40)
local cvVMFovAim = CreateClientConVar("cl_sandswep_vmfov_aim", "0", true, false, "Keep the viewmodel FOV offset while aiming", 0, 1)
local cvVMOffX = CreateClientConVar("cl_sandswep_vm_offset_x", "0", true, false, "Viewmodel offset right (hip)", -10, 10)
local cvVMOffY = CreateClientConVar("cl_sandswep_vm_offset_y", "0", true, false, "Viewmodel offset forward (hip)", -10, 10)
local cvVMOffZ = CreateClientConVar("cl_sandswep_vm_offset_z", "0", true, false, "Viewmodel offset up (hip)", -10, 10)
local cvSprintCam = CreateClientConVar("cl_sandswep_sprintcam", "1", true, false, "Sprint sway", 0, 3)
local cvCamAnim = CreateClientConVar("cl_sandswep_cameraanim", "1", true, false, "Animation camera", 0, 3)

local Smoothstep, Damp = SandSwep.Math.Smoothstep, SandSwep.Math.Damp

local function ApplyPose(pos, ang, axes, offset, rot, t)
    local right, fwd, up = axes[1], axes[2], axes[3]
    ang:RotateAroundAxis(right, rot.p * t)
    ang:RotateAroundAxis(up, rot.y * t)
    ang:RotateAroundAxis(fwd, rot.r * t)
    local ox, oy, oz = offset.x * t, offset.y * t, offset.z * t
    pos:SetUnpacked(
        pos.x + right.x * ox + fwd.x * oy + up.x * oz,
        pos.y + right.y * ox + fwd.y * oy + up.y * oz,
        pos.z + right.z * ox + fwd.z * oy + up.z * oz)
    return pos
end

local function RotateLocal(ang, pitch, roll, yaw)
    local right, fwd, up = ang:Right(), ang:Forward(), ang:Up()
    ang:RotateAroundAxis(right, pitch)
    ang:RotateAroundAxis(fwd, roll)
    ang:RotateAroundAxis(up, yaw)
end

local MOTION_CHANNELS = { "right", "fwd", "up", "pitch", "roll", "yaw" }
local CAMERA_CHANNELS = { "pitch", "roll", "yaw" }
local TAU = math.pi * 2

local function WaveValue(wave, angle)
    local value = wave[1]
    for i = 2, #wave, 2 do
        local harmonic = i / 2
        value = value + wave[i] * math.sin(angle * harmonic + wave[i + 1])
    end

    return value
end

local function CurveValue(curve, t)
    local from, to = curve[1], curve[2]
    local value = from + (to - from) * t
    for i = 3, #curve do
        local term = i - 2
        value = value + curve[i] * math.sin(term * math.pi * t)
    end

    return value
end

local function AddWaves(clip, phase, out, weight, channels)
    if not clip or weight == 0 then return end

    local angle = phase * TAU
    local list = channels or MOTION_CHANNELS
    for c = 1, #list do
        out[c] = out[c] + WaveValue(clip[list[c]], angle) * weight
    end
end

local function SampleLoop(clip, time, out)
    out = out or { 0, 0, 0, 0, 0, 0 }
    for c = 1, 6 do out[c] = 0 end
    AddWaves(clip, (time / clip.Length) % 1, out, 1)
    return out
end

local function SampleCurve(clip, time, out)
    local t = math.Clamp(time / clip.Length, 0, 1)

    out = out or {}
    for c = 1, 6 do
        out[c] = CurveValue(clip[MOTION_CHANNELS[c]], t)
    end

    return out
end

local function AddLean(lean, out, weight)
    if not lean or weight == 0 then return end
    for c = 1, 6 do out[c] = out[c] + lean[c] * weight end
end

function SWEP:CustomAmmoDisplay()
    self.AmmoDisplay = self.AmmoDisplay or {}
    self.AmmoDisplay.Draw = true

    if self.HideExactAmmo then
        self.AmmoDisplay.PrimaryClip = self:GetMagCount()
        self.AmmoDisplay.PrimaryAmmo = nil
    else
        self.AmmoDisplay.PrimaryClip = self:Clip1()
        self.AmmoDisplay.PrimaryAmmo = self:PoolsAmmo() and self:GetSpareRounds() or self:GetMagCount()
    end

    return self.AmmoDisplay
end

function SWEP:GetMagCheckWeight()
    if not self:IsMagChecking() or not self:UsesProceduralMagCheck() then return 0 end

    local progress = self:GetActionProgress()
    local blendIn, blendOut = self.MagCheckBlendIn, self.MagCheckBlendOut

    if progress < blendIn then return Smoothstep(progress / blendIn) end
    if progress > 1 - blendOut then return Smoothstep((1 - progress) / blendOut) end

    return 1
end

function SWEP:GetBlendedSight()
    local sight = self:GetActiveSight()
    local targetPos, targetAng = sight.Pos, sight.Ang
    if cvSightDev:GetBool() and self.SightDev then
        targetPos, targetAng = self.SightDev.Pos, self.SightDev.Ang
    end

    local cur = self._sight
    if not cur then
        cur = { Pos = Vector(targetPos), Ang = Angle(targetAng.p, targetAng.y, targetAng.r) }
        self._sight = cur
    end

    local blend = SandSwep.Math.DampFactor(SIGHT_SWITCH_EASE / math.max(self.SightSwitchTime, 0.01))
    local cp, ca = cur.Pos, cur.Ang
    if cp.x ~= targetPos.x or cp.y ~= targetPos.y or cp.z ~= targetPos.z then
        cp:SetUnpacked(
            cp.x + (targetPos.x - cp.x) * blend,
            cp.y + (targetPos.y - cp.y) * blend,
            cp.z + (targetPos.z - cp.z) * blend)
    end
    if ca.p ~= targetAng.p or ca.y ~= targetAng.y or ca.r ~= targetAng.r then
        ca:SetUnpacked(
            ca.p + math.AngleDifference(targetAng.p, ca.p) * blend,
            ca.y + math.AngleDifference(targetAng.y, ca.y) * blend,
            ca.r + math.AngleDifference(targetAng.r, ca.r) * blend)
    end

    return cur, sight
end

local function UpdateWalkState(wep, bob, ply, gait)
    local frameNum = FrameNumber()
    if bob.frame == frameNum then return end
    bob.frame = frameNum

    local dt = VisualFrameTime()
    local vel = ply:GetVelocity()

    local yawRad = math.rad(ply:EyeAngles().y)
    local cosY, sinY = math.cos(yawRad), math.sin(yawRad)
    local velFwd = vel.x * cosY + vel.y * sinY
    local velRight = vel.x * sinY - vel.y * cosY
    local speed = math.sqrt(velFwd * velFwd + velRight * velRight)
    local refSpeed = math.max(wep.WalkBobRefSpeed, 1)
    local grounded = ply:OnGround() and ply:GetMoveType() == MOVETYPE_WALK

    local target = grounded and math.Clamp(speed / refSpeed, 0, WALK_BOB_MAX) or 0
    bob.amt = Damp(bob.amt, target, WALK_BOB_EASE, dt)

    bob.dbgDt, bob.dbgReal, bob.dbgSpeed, bob.dbgRate = dt, RealFrameTime(), speed, 0

    if not grounded or speed <= WALK_MIN_SPEED then return end

    local rate = math.Clamp(speed / refSpeed, STRIDE_RATE_MIN, STRIDE_RATE_MAX) / gait.StrideTime
    bob.dbgRate = rate
    bob.phase = (bob.phase + dt * rate) % 1

    local sum = math.abs(velFwd) + math.abs(velRight)
    local blend = math.min(1, dt * WALK_DIR_EASE)
    bob.n = Lerp(blend, bob.n, math.max(velFwd, 0) / sum)
    bob.s = Lerp(blend, bob.s, math.max(-velFwd, 0) / sum)
    bob.e = Lerp(blend, bob.e, math.max(velRight, 0) / sum)
    bob.w = Lerp(blend, bob.w, math.max(-velRight, 0) / sum)
end

function SWEP:GetWalkBob(aimT, sprintVis, animSprint)
    local motion = SandSwep and SandSwep.MotionData
    local gait = motion and motion.Gait
    local ply = self:GetOwner()
    if not gait or not IsValid(ply) then return end

    local bob = self._bob
    if not bob then
        bob = { amt = 0, phase = 0, n = 1, e = 0, s = 0, w = 0 }
        self._bob = bob
    end

    UpdateWalkState(self, bob, ply, gait)

    local focus = self.GetFocusProgress and self:GetFocusProgress() or 0
    local scale = bob.amt * cvBob:GetFloat() * Lerp(focus, 1, self.FocusSwayScale)
    if scale < 0.001 then return end

    local out = self._bobOut
    if not out then
        out = {}
        self._bobOut = out
    end

    for c = 1, 6 do out[c] = 0 end

    local hip = self.WalkBobScale * (1 - aimT)
    if animSprint then hip = hip * (1 - sprintVis) end

    if hip > 0 then
        local lean = motion.Lean or {}
        local leanScale = self.WalkBobLean

        AddWaves(gait.N, bob.phase, out, hip * bob.n)
        AddWaves(gait.S or gait.N, bob.phase, out, hip * bob.s)
        AddWaves(gait.E or gait.N, bob.phase, out, hip * bob.e)
        AddWaves(gait.W or gait.N, bob.phase, out, hip * bob.w)

        AddLean(lean.S, out, hip * bob.s * leanScale)
        AddLean(lean.E, out, hip * bob.e * leanScale)
        AddLean(lean.W, out, hip * bob.w * leanScale)
    end

    if aimT > 0 then
        AddWaves(gait.Iron or gait.N, bob.phase, out, self.WalkBobAimScale * aimT)
    end

    if not animSprint and sprintVis > 0 then
        AddWaves(gait.N, bob.phase, out, (self.SprintBobScale - 1) * sprintVis * (1 - aimT))
    end

    for c = 1, 6 do out[c] = out[c] * scale end
    return out
end

function SWEP:GetSprintVisual()
    local want = self:GetSprinting() and not self:IsActionBusy()
    local target = want and 1 or 0
    local time = want and self.SprintInTime or self.SprintOutTime
    self._sprintVis = SandSwep.Math.Lerp(self._sprintVis or target, target, time)
    return Smoothstep(self._sprintVis)
end

local function AddBreathing(wep, motion, out, dt, aimT, sprintVis)
    wep._breathPhase = ((wep._breathPhase or 0) + dt / motion.Breath.Length) % 1

    local moving = wep._bob and wep._bob.amt or 0
    local focus = wep.GetFocusProgress and wep:GetFocusProgress() or 0
    local weight = wep.BreathScale * cvBreath:GetFloat() * Lerp(aimT, 1, wep.BreathAimScale)
        * math.Clamp(1 - moving * BREATH_MOVE_FADE, 0, 1) * (1 - sprintVis)
        * Lerp(focus, 1, wep.FocusSwayScale)
    if weight <= 0.001 then return false end

    AddWaves(motion.Breath, wep._breathPhase, out, weight)
    return true
end

local function SwitchJump(jump, state)
    local from, cur = jump.from, jump.cur
    for c = 1, 6 do from[c] = cur[c] end
    jump.state, jump.t, jump.fade = state, 0, 0
end

local function UpdateJumpState(jump, ply, dt)
    local grounded = ply:OnGround() or ply:GetMoveType() ~= MOVETYPE_WALK or ply:WaterLevel() >= 2
    if grounded then
        if jump.state == JUMP_START or jump.state == JUMP_AIR then
            jump.land = math.Clamp(LAND_MIN + (-jump.vz) / LAND_FALL_SPEED, LAND_MIN, LAND_MAX)
            SwitchJump(jump, JUMP_LAND)
        end
        jump.air, jump.vz = 0, 0
        return
    end

    local vz = ply:GetVelocity().z
    jump.air = jump.air + dt
    jump.vz = math.min(jump.vz, vz)

    local settled = jump.state == JUMP_NONE or jump.state == JUMP_LAND
    if settled and (vz > JUMP_START_SPEED or jump.air > JUMP_START_AIRTIME) then
        SwitchJump(jump, JUMP_START)
    end
end

local function SampleJump(jump, motion)
    local cur = jump.cur
    if jump.state == JUMP_START then
        SampleCurve(motion.JumpStart, jump.t, cur)
        if jump.t >= motion.JumpStart.Length then SwitchJump(jump, JUMP_AIR) end
        return cur
    elseif jump.state == JUMP_AIR then
        return SampleLoop(motion.JumpIdle, jump.t, cur)
    elseif jump.state == JUMP_LAND then
        SampleCurve(motion.JumpEnd, jump.t, cur)
        for c = 1, 6 do cur[c] = cur[c] * jump.land end
        if jump.t >= motion.JumpEnd.Length then jump.state = JUMP_NONE end
        return cur
    end

    for c = 1, 6 do cur[c] = 0 end
    return cur
end

local function AddJumpMotion(wep, motion, out, ply, dt, aimT, sprintVis)
    local jump = wep._jump
    if not jump then
        jump = {
            state = JUMP_NONE,
            t = 0,
            air = 0,
            vz = 0,
            fade = 1,
            from = { 0, 0, 0, 0, 0, 0 },
            cur = { 0, 0, 0, 0, 0, 0 },
            land = 1,
        }
        wep._jump = jump
    end

    UpdateJumpState(jump, ply, dt)

    if jump.state == JUMP_NONE and jump.fade >= 1 then
        wep._jumpCam = nil
        return false
    end

    jump.t = jump.t + dt
    jump.fade = math.min(1, jump.fade + dt / JUMP_FADE)

    local cur = SampleJump(jump, motion)
    if jump.fade < 1 then
        local blend = Smoothstep(jump.fade)
        for c = 1, 6 do cur[c] = jump.from[c] + (cur[c] - jump.from[c]) * blend end
    end

    local weight = wep.JumpMotionScale * Lerp(aimT, 1, wep.JumpMotionAimScale) * (1 - sprintVis * JUMP_SPRINT_DAMPEN)
    local added = false
    if weight > 0.001 then
        for c = 1, 6 do out[c] = out[c] + cur[c] * weight end
        added = true
    end

    local camWeight = (wep.JumpCameraScale or 0) * weight
    if camWeight > 0.001 then
        local cam = wep._jumpCamBuf or {}
        wep._jumpCamBuf = cam
        cam[1], cam[2], cam[3] = cur[4] * camWeight, cur[5] * camWeight, cur[6] * camWeight
        wep._jumpCam = cam
    else
        wep._jumpCam = nil
    end
    return added
end

function SWEP:GetBodyMotion(aimT, sprintVis)
    local motion = SandSwep and SandSwep.MotionData
    local ply = self:GetOwner()
    if not motion or not IsValid(ply) then return end

    local frameNum = FrameNumber()
    if self._bodyFrame == frameNum then return self._bodyOut end
    self._bodyFrame = frameNum

    local dt = VisualFrameTime()
    local out = self._bodyBuf
    if not out then
        out = { 0, 0, 0, 0, 0, 0 }
        self._bodyBuf = out
    else
        for c = 1, 6 do out[c] = 0 end
    end

    local any = false
    if motion.Breath and AddBreathing(self, motion, out, dt, aimT, sprintVis) then any = true end

    local hasJump = motion.JumpStart and motion.JumpIdle and motion.JumpEnd
    if hasJump and AddJumpMotion(self, motion, out, ply, dt, aimT, sprintVis) then
        any = true
    end

    self._bodyOut = any and out or nil
    return self._bodyOut
end

concommand.Add("sandswep_freezevm", function()
    RunConsoleCommand("cl_sandswep_debug_freezevm", cvFreezeVM:GetBool() and "0" or "1")
end)

function SWEP:GetViewModelPosition(pos, ang)
    if cvFreezeVM:GetBool() then
        local frozen = self._vmFrozen
        if not frozen then
            local frozenPos, frozenAng = self:ComputeViewModelPosition(pos, ang)
            frozen = { Vector(frozenPos), Angle(frozenAng) }
            self._vmFrozen = frozen
        end
        return Vector(frozen[1]), Angle(frozen[2])
    end

    self._vmFrozen = nil
    return self:ComputeViewModelPosition(pos, ang)
end

local function BipodCameraPos(wep, pos)
    if wep:GetBipodWeight() <= 0 then return pos end
    if wep._bipodCam and wep._bipodCamFrame == FrameNumber() then return wep._bipodCam end

    local owner = wep:GetOwner()
    if IsValid(owner) then return wep:GetBipodView(pos, owner:EyeAngles()) end
    return pos
end

local undoCamAng, followDZAng = Angle(), Angle()

local function UndoCameraAnim(wep, ang)
    local camW = wep._camAnimW
    if not camW or not wep.CameraAnimLockViewModel then return ang end

    local deg = camW:Length()
    if deg <= 0.001 then return ang end

    undoCamAng:SetUnpacked(ang.p, ang.y, ang.r)
    undoCamAng:RotateAroundAxis(camW / deg, -deg)
    return undoCamAng
end

local function FollowDeadzone(wep, ang, inAng, aimT)
    local vmOffset, camAng = wep._dzVM, wep._dzCam
    if not (vmOffset and camAng and wep._dzCamFrame == FrameNumber()) then return ang end

    local scale = wep.DeadzoneViewModelScale * (1 - aimT)
    local _, rel = WorldToLocal(vector_origin, camAng, vector_origin, inAng)
    followDZAng:SetUnpacked(ang.p + vmOffset.p * scale, ang.y + vmOffset.y * scale, ang.r)
    local _, out = LocalToWorld(vector_origin, rel, vector_origin, followDZAng)

    return out
end

local function UpdateSafeProgress(wep)
    local lowered = wep:IsSafe() and not wep:IsReloading() and not wep:IsMagChecking()
    local target = lowered and 1 or 0
    local time = lowered and wep.SafeLowerTime or wep.SafeRaiseTime
    wep._safeProg = SandSwep.Math.Lerp(wep._safeProg or target, target, time)
end

local function CombinedMotion(wep, aimT, sprintVis, animSprint, dev)
    local bob = (not dev) and wep:GetWalkBob(aimT, sprintVis, animSprint) or nil
    local body = (not dev) and wep:GetBodyMotion(aimT, sprintVis) or nil

    if body then
        if bob then
            for c = 1, 6 do bob[c] = bob[c] + body[c] end
        else
            bob = wep._bobMix or {}
            wep._bobMix = bob
            for c = 1, 6 do bob[c] = body[c] end
        end
    end

    local bipodW = wep:GetBipodWeight()
    if bob and bipodW > 0 then
        for c = 1, 6 do bob[c] = bob[c] * (1 - bipodW) end
    end

    return bob, bipodW
end

local function WallResponse(wep, aimT, dev)
    local wall = SandSwepWall
    local back, tilt = 0, 0

    if wall and not dev then
        wep._wall = wep._wall or {}
        local amount = wall.Update(wep._wall, wep._wallPen or 0, RealFrameTime(), FrameNumber())
        back, tilt = wall.Response(amount, wep._wallReach or wall.DefaultReach, aimT)
    end

    wep._wallTilt = tilt
    return wall, back, tilt
end

local function ApplyAimPoses(wep, pos, ang, axes, blended, aimRaw, aimT, dev)
    pos = ApplyPose(pos, ang, axes, blended.Pos, blended.Ang, aimT)

    local bump = math.sin(aimRaw * math.pi)
    if bump > 0.001 and not dev then
        pos = ApplyPose(pos, ang, axes, wep.AimInPos, wep.AimInAng, bump)
    end

    local since = wep:GetZoomBumpAt() > 0 and CurTime() - wep:GetZoomBumpAt()
    if since and since >= 0 and since < wep.ZoomBumpTime and not dev then
        local spring = math.exp(-wep.ZoomBumpDamp * since) * math.sin(since * wep.ZoomBumpFreq * 2 * math.pi)
            * (1 - since / wep.ZoomBumpTime)
        pos = ApplyPose(pos, ang, axes, wep.ZoomBumpPos, wep.ZoomBumpAng, spring * aimT)
    end

    return pos
end

local vmPosScratch, vmAngScratch = Vector(), Angle()
local kickPivot = Vector()
local userOffset = Vector()
local KICK_MAX_PLAYS = 8
local kickSum = { 0, 0, 0, 0, 0, 0 }

local function CatmullRom(p0, p1, p2, p3, t)
    local t2, t3 = t * t, t * t * t
    return 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

local function CurvePeak(curve)
    if curve.peak then return curve.peak end
    local best, peak = -math.huge, 1
    for i, row in ipairs(curve) do
        if row[5] > best then best, peak = row[5], i - 1 end
    end
    curve.peak = peak
    return peak
end

local function SampleCurve(curve, frame, out, scale, rotScale, posScale, bounce)
    if bounce ~= 1 then
        local peak = CurvePeak(curve)
        scale = scale * Lerp(math.Clamp(frame - peak, 0, 1), 1, bounce)
    end
    local n = #curve
    local i = math.floor(frame)
    local f = frame - i
    local a = curve[math.Clamp(i, 1, n)]
    local b = curve[math.Clamp(i + 1, 1, n)]
    local c = curve[math.Clamp(i + 2, 1, n)]
    local d = curve[math.Clamp(i + 3, 1, n)]
    for k = 1, 6 do
        local v = CatmullRom(a[k], b[k], c[k], d[k], f) * scale
        out[k] = out[k] + v * (k <= 3 and rotScale or posScale)
    end
end

local function VMKick(wep, aimT)
    local cfg = wep.VMRecoil
    if not cfg then return false end

    local set = SandSwep.VMRecoilCurves and SandSwep.VMRecoilCurves[cfg.Curve or "pistol"]
    if not set then return false end

    local st = wep._vmk
    if not st then
        st = { plays = {}, heat = 0, heatC = 0, drift = 0, driftC = 0 }
        wep._vmk = st
    end

    local acc = cfg.Accumulate

    local clip = wep:Clip1()
    local lastClip = wep._vmkClip
    wep._vmkClip = clip

    local now = RealTime()
    if lastClip and clip == lastClip - 1 then
        local list = aimT > 0.5 and (set.Aim or set.Hip) or set.Hip
        local mult = (cfg.Scale or 1) * wep:GetStatMult("Recoil") * (aimT > 0.5 and (cfg.AimScale or 1) or 1)
        local plays = st.plays
        if #plays >= KICK_MAX_PLAYS then table.remove(plays, 1) end
        local aiming = aimT > 0.5
        local mirror = cfg.Mirror ~= false and math.random() < 0.5 and -1 or 1
        plays[#plays + 1] = { start = now, curve = list[math.random(#list)], scale = mult, mirror = mirror,
            rot = aiming and cfg.AimRotScale or cfg.RotScale or 1, pos = aiming and cfg.AimPosScale or cfg.PosScale or 1 }

        local shake = cfg.Shake
        if shake then
            local amt = mult * (aiming and (shake.AimMult or 0.5) or 1)
            st.shakeAmp = math.min((st.shakeAmp or 0) + amt, amt * 2)
            st.shakeT = 0
            local ph = st.shakePh
            if not ph then ph = {} st.shakePh = ph end
            ph[1], ph[2], ph[3] = math.Rand(0, 6.283), math.Rand(0, 6.283), math.Rand(0, 6.283)
        end

        if acc then
            st.heat = math.min(st.heat + mult, acc.Max or 5)
            st.drift = math.Clamp(st.drift + math.Rand(-1, 1) * mult, -(acc.Max or 5), acc.Max or 5)
        end
    end

    if acc and st.frame ~= FrameNumber() then
        st.frame = FrameNumber()
        local dt = math.min(RealFrameTime(), 0.1)
        local decay = math.exp(-(acc.Decay or 3) * dt)
        st.heat, st.drift = st.heat * decay, st.drift * decay
        st.heatC = Damp(st.heatC, st.heat, acc.Follow or 14, dt)
        st.driftC = Damp(st.driftC, st.drift, acc.Follow or 14, dt)
        if st.heat < 1e-3 and st.heatC < 1e-3 and math.abs(st.driftC) < 1e-3 then
            st.heat, st.heatC, st.drift, st.driftC = 0, 0, 0, 0
        end
    end

    local plays = st.plays
    local warm = acc and st.heatC > 0
    local shake = cfg.Shake
    local shaking = shake and (st.shakeAmp or 0) > 0.002
    if #plays == 0 and not warm and not shaking then return false end

    for k = 1, 6 do kickSum[k] = 0 end
    local fps = set.FPS or 30
    for i = #plays, 1, -1 do
        local play = plays[i]
        local frame = (now - play.start) * fps * (cfg.Speed or 1)
        if frame >= #play.curve - 1 then
            table.remove(plays, i)
        else
            local y, r, x = kickSum[2], kickSum[3], kickSum[4]
            SampleCurve(play.curve, frame, kickSum, play.scale, play.rot, play.pos, cfg.Bounce or 1)
            if play.mirror < 0 then
                kickSum[2] = y - (kickSum[2] - y)
                kickSum[3] = r - (kickSum[3] - r)
                kickSum[4] = x - (kickSum[4] - x)
            end
        end
    end

    if shaking then
        local dt = math.min(RealFrameTime(), 0.1)
        if st.shakeFrame ~= FrameNumber() then
            st.shakeFrame = FrameNumber()
            st.shakeT = (st.shakeT or 0) + dt
            st.shakeAmp = st.shakeAmp * math.exp(-(shake.Decay or 14) * dt)
        end
        local w = (shake.Freq or 26) * 6.283 * st.shakeT
        local a, ph = st.shakeAmp, st.shakePh
        kickSum[1] = kickSum[1] + a * (shake.Pitch or 0.6) * math.sin(w * 1.07 + ph[1])
        kickSum[2] = kickSum[2] + a * (shake.Yaw or 0.8) * math.sin(w * 0.93 + ph[2])
        kickSum[3] = kickSum[3] + a * (shake.Roll or 2) * math.sin(w + ph[3])
    end

    if warm then
        local aimMul = aimT > 0.5 and (acc.AimScale or 0.5) or 1
        kickSum[1] = kickSum[1] + st.heatC * (acc.Pitch or 1.2) * aimMul
        kickSum[2] = kickSum[2] + st.driftC * (acc.Yaw or 0.4) * aimMul
        kickSum[5] = kickSum[5] + st.heatC * (acc.Back or 0.35) * aimMul
        kickSum[6] = kickSum[6] + st.heatC * (acc.Up or 0.05) * aimMul
    end

    st.c = kickSum
    return st
end

local function ApplyKick(wep, pos, ang, axes, eyePos, st)
    local cfg = wep.VMRecoil
    local right, fwd, up = axes[1], axes[2], axes[3]
    local pv = cfg.Pivot or vector_origin
    kickPivot:SetUnpacked(
        pos.x + right.x * pv.x + fwd.x * pv.y + up.x * pv.z,
        pos.y + right.y * pv.x + fwd.y * pv.y + up.y * pv.z,
        pos.z + right.z * pv.x + fwd.z * pv.y + up.z * pv.z)

    local c = st.c
    local localPos = WorldToLocal(pos, angle_zero, kickPivot, ang)
    ang:RotateAroundAxis(right, c[1])
    ang:RotateAroundAxis(up, c[2])
    ang:RotateAroundAxis(fwd, c[3])
    local p = LocalToWorld(localPos, angle_zero, kickPivot, ang)

    local ox, oy, oz = c[4], -c[5], c[6]
    pos:SetUnpacked(
        p.x + right.x * ox + fwd.x * oy + up.x * oz,
        p.y + right.y * ox + fwd.y * oy + up.y * oz,
        p.z + right.z * ox + fwd.z * oy + up.z * oz)
    return pos
end

function SWEP:ComputeViewModelPosition(pos, ang)
    local inAng = ang
    local eyePos = pos

    pos = BipodCameraPos(self, pos)
    ang = UndoCameraAnim(self, ang)

    local dev = cvSightDev:GetBool()
    local aimRaw = dev and 1 or self:GetAimProgress()
    local aimT = Smoothstep(aimRaw)
    ang = FollowDeadzone(self, ang, inAng, aimT)

    UpdateSafeProgress(self)

    local sprintVis = self:GetSprintVisual()
    local animSprint = self:UsesSprintAnims()
    local sprintPoseT = animSprint and 0 or sprintVis
    local safeT = Smoothstep(self._safeProg) * (1 - sprintVis)
    local checkT = self:GetMagCheckWeight()
    local kick = VMKick(self, aimT)
    userOffset:SetUnpacked(cvVMOffX:GetFloat(), cvVMOffY:GetFloat(), cvVMOffZ:GetFloat())
    local hasOffset = not userOffset:IsZero()

    local blended, sight = self:GetBlendedSight()
    local baseFOV = self.BaseViewModelFOV or self.ViewModelFOV
    local hipFOV = math.Clamp(baseFOV + cvVMFov:GetFloat(), VM_FOV_MIN, VM_FOV_MAX)
    local aimFOV = sight.ViewModelFOV or (cvVMFovAim:GetBool() and hipFOV or baseFOV)
    self.ViewModelFOV = Lerp(aimT, hipFOV, aimFOV)

    local bob, bipodW = CombinedMotion(self, aimT, sprintVis, animSprint, dev)
    local wall, wallBack, wallTilt = WallResponse(self, aimT, dev)

    local untouched = safeT <= 0 and checkT <= 0 and aimT <= 0 and sprintPoseT <= 0
        and not bob
        and wallBack <= 0 and wallTilt <= 0
        and bipodW <= 0
        and not self.HipPos
        and not kick
        and not hasOffset

    if untouched then
        return pos, ang
    end

    vmPosScratch:Set(pos)
    pos = vmPosScratch
    vmAngScratch:SetUnpacked(ang.p, ang.y, ang.r)
    local newAng = vmAngScratch
    local axes = self._vmAxes or {}
    self._vmAxes = axes
    axes[1], axes[2], axes[3] = newAng:Right(), newAng:Forward(), newAng:Up()

    if self.HipPos and aimT < 1 then
        pos = ApplyPose(pos, newAng, axes, self.HipPos, self.HipAng or angle_zero, 1 - aimT)
    end

    if hasOffset and aimT < 1 then
        pos = ApplyPose(pos, newAng, axes, userOffset, angle_zero, 1 - aimT)
    end

    local bipodPose = self.Bipod and self:GetBipodPose()
    local bipodPoseW = bipodPose and self:GetBipodWeight() or 0
    if bipodPoseW > 0 then
        pos = ApplyPose(pos, newAng, axes, bipodPose.Pos or vector_origin, bipodPose.Ang or angle_zero, bipodPoseW * (1 - aimT))
    end

    if aimT > 0 then
        pos = ApplyAimPoses(self, pos, newAng, axes, blended, aimRaw, aimT, dev)

        local pointT = self:UpdatePointAimProgress() * aimT
        if pointT ~= 0 then
            local localPos = WorldToLocal(pos, angle_zero, eyePos, newAng)
            local rot = self.PointAimAng
            newAng:RotateAroundAxis(axes[1], rot.p * pointT)
            newAng:RotateAroundAxis(axes[3], rot.y * pointT)
            newAng:RotateAroundAxis(axes[2], rot.r * pointT)
            local pPos = LocalToWorld(localPos, angle_zero, eyePos, newAng)

            local offset = self.PointAimPos
            local pr, pf, pu = newAng:Right(), newAng:Forward(), newAng:Up()
            local ox, oy, oz = offset.x * pointT, offset.y * pointT, offset.z * pointT
            pos:SetUnpacked(
                pPos.x + pr.x * ox + pf.x * oy + pu.x * oz,
                pPos.y + pr.y * ox + pf.y * oy + pu.y * oz,
                pPos.z + pr.z * ox + pf.z * oy + pu.z * oz)
        end
    end

    if kick then
        pos = ApplyKick(self, pos, newAng, axes, eyePos, kick)
    end

    if safeT > 0 then
        pos = ApplyPose(pos, newAng, axes, self.SafePos, self.SafeAng, safeT)
    end

    if sprintPoseT > 0 then
        pos = ApplyPose(pos, newAng, axes, self.SprintPos, self.SprintAng, sprintPoseT)
    end

    if checkT > 0 then
        local sway = math.sin(CurTime() * MAGCHECK_SWAY_SPEED) * MAGCHECK_SWAY_DEG * checkT
        local checkAng = self.MagCheckAng
        followDZAng:SetUnpacked(checkAng.p, checkAng.y, checkAng.r + sway)
        pos = ApplyPose(pos, newAng, axes, self.MagCheckPos, followDZAng, checkT)
    end

    if wallBack > 0 or wallTilt > 0 then
        pos = wall.Apply(pos, newAng, inAng, wallBack, wallTilt)
        vmPosScratch:Set(pos)
        pos = vmPosScratch
    end

    if bob then
        local right, fwd, up = axes[1], axes[2], axes[3]
        newAng:RotateAroundAxis(right, bob[4])
        newAng:RotateAroundAxis(fwd, bob[5])
        newAng:RotateAroundAxis(up, bob[6])
        local bx, by, bz = bob[1], bob[2], bob[3]
        pos:SetUnpacked(
            pos.x + right.x * bx + fwd.x * by + up.x * bz,
            pos.y + right.y * bx + fwd.y * by + up.y * bz,
            pos.z + right.z * bx + fwd.z * by + up.z * bz)
    end

    return pos, newAng
end

function SWEP:DeadzoneActive()
    local ply = self:GetOwner()
    return cvDeadzone:GetBool() and IsValid(ply) and ply == LocalPlayer()
        and not ply:ShouldDrawLocalPlayer() and not ply:InVehicle()
end

local function MoveDeadzone(wep, offset, deltaPitch, deltaYaw)
    local scale = cvDZScale:GetFloat() * (1 - Smoothstep(wep:GetAimProgress()))
    local limPitch = wep.DeadzonePitch * scale
    local limYaw = wep.DeadzoneYaw * scale

    if limPitch <= 0 or limYaw <= 0 then
        offset.p, offset.y = 0, 0
        return
    end

    local rp, ry = offset.p / limPitch, offset.y / limYaw
    local reach = math.sqrt(rp * rp + ry * ry)
    local share = math.Clamp(wep.DeadzoneLead or 0.6, 0, 1)
    local outward = (offset.p * deltaPitch) / (limPitch * limPitch)
        + (offset.y * deltaYaw) / (limYaw * limYaw) > 0

    if outward then
        share = share * math.max(0, 1 - reach ^ wep.DeadzoneSoftness)
    end
    offset.p = offset.p + deltaPitch * share
    offset.y = offset.y + deltaYaw * share

    rp, ry = offset.p / limPitch, offset.y / limYaw
    reach = math.sqrt(rp * rp + ry * ry)
    if reach > 1 then offset.p, offset.y = offset.p / reach, offset.y / reach end
end

local dzLeadScratch = Angle()

function SWEP:UpdateDeadzone(ply)
    local frameNum = FrameNumber()
    if self._dzFrame == frameNum then return end

    local continuous = self._dzFrame == frameNum - 1
    self._dzFrame = frameNum
    self._dzLeadP, self._dzLeadY = 0, 0

    local eye = ply:EyeAngles()
    local last = self._dzLast
    if not last then
        last = Angle(eye.p, eye.y, 0)
        self._dzLast = last
        self._dzOff = Angle(0, 0, 0)
        self._dzVM = Angle(0, 0, 0)
        return
    end

    local lastP, lastY = last.p, last.y
    last:SetUnpacked(eye.p, eye.y, 0)

    if not continuous or not self._dzOff then
        if self._dzOff then self._dzOff:Zero() else self._dzOff = Angle(0, 0, 0) end
        if self._dzVM then self._dzVM:Zero() else self._dzVM = Angle(0, 0, 0) end
        return
    end

    local offset = self._dzOff
    local deltaPitch = eye.p - lastP
    local deltaYaw = math.AngleDifference(eye.y, lastY)
    local prevPitch, prevYaw = offset.p, offset.y
    local snapped = math.abs(deltaPitch) > DEADZONE_SNAP_DEG or math.abs(deltaYaw) > DEADZONE_SNAP_DEG

    if snapped then
        offset.p, offset.y = 0, 0
    else
        MoveDeadzone(self, offset, deltaPitch, deltaYaw)

        local recenter = cvRecenter:GetFloat()
        if recenter > 0 then
            local decay = 1 - math.min(1, VisualFrameTime() * recenter)
            offset.p, offset.y = offset.p * decay, offset.y * decay
        end
    end
    local leadPitch, leadYaw = offset.p - prevPitch, offset.y - prevYaw

    self._dzLeadP, self._dzLeadY = leadPitch, leadYaw

    if leadPitch ~= 0 or leadYaw ~= 0 then
        local leadP, leadY = math.Clamp(eye.p + leadPitch, -89, 89), eye.y + leadYaw
        dzLeadScratch:SetUnpacked(leadP, leadY, eye.r)
        ply:SetEyeAngles(dzLeadScratch)
        last:SetUnpacked(leadP, leadY, 0)
    end

    local vm = self._dzVM
    local blend = math.min(1, VisualFrameTime() * self.DeadzoneSmoothing)
    vm.p = Lerp(blend, vm.p, offset.p)
    vm.y = Lerp(blend, vm.y, offset.y)
end

function SWEP:GetSprintCamera()
    local motion = SandSwep and SandSwep.MotionData
    local data = motion and motion.SprintCam
    local ply = self:GetOwner()
    if not data or not IsValid(ply) then return end

    local phase
    local target = 0
    if self:UsesSprintAnims() then
        local vm = ply:GetViewModel()
        local _, seq = self:ResolveAnim("sprint", true)
        if IsValid(vm) and seq and vm:GetSequence() == seq then
            phase = vm:GetCycle()
            target = 1
        end
    else
        target = self._sprintVis or 0
    end

    if phase then
        self._camPhase = phase
    else
        self._camPhase = ((self._camPhase or 0) + VisualFrameTime() / data.Length) % 1
        phase = self._camPhase
    end

    local frameNum = FrameNumber()
    if self._camFrame ~= frameNum then
        self._camFrame = frameNum
        self._camW = SandSwep.Math.Lerp(self._camW or 0, target, SPRINT_CAM_FADE)
    end

    local scale = Smoothstep(self._camW) * self.SprintCameraScale * cvSprintCam:GetFloat()
    if scale < 0.001 then return end

    local out = self._sprintCamOut or {}
    self._sprintCamOut = out

    out[1], out[2], out[3] = 0, 0, 0
    AddWaves(data, phase, out, scale, CAMERA_CHANNELS)

    return out
end

local camRot, camRotT, parentT, camDelta = Matrix(), Matrix(), Matrix(), Matrix()

local function CameraBoneIds(vm)
    local model = vm:GetModel()
    local ids = vm.SandSwepCamBoneIds
    if ids and ids.model == model then return ids.cam, ids.parent end

    local cam = SandSwep.BoneId(vm, "b_camera")
    local parent = cam and vm:GetBoneParent(cam)
    if not parent or parent < 0 then cam, parent = false, false end

    vm.SandSwepCamBoneIds = { model = model, cam = cam or false, parent = parent or false }
    return cam, parent
end

local camBoneMat, camParentMat = Matrix(), Matrix()

local function MeasureCameraBone(vm)
    local cam, parent = CameraBoneIds(vm)
    if not cam then return end

    local camMat, parentMat = CopyBone(vm, cam, camBoneMat), CopyBone(vm, parent, camParentMat)
    if not camMat or not parentMat then return end

    camMat:SetTranslation(vector_origin)
    parentMat:SetTranslation(vector_origin)

    camRot:Identity()
    camRot:SetAngles(vm:GetAngles())
    camRotT:Set(camRot)
    camRotT:InvertTR()
    parentT:Set(parentMat)
    parentT:InvertTR()

    camDelta:Set(camRotT)
    camDelta:Mul(camMat)
    camDelta:Mul(parentT)
    camDelta:Mul(camRot)

    local d11, d12, d13, _, d21, d22, d23, _, d31, d32, d33 = camDelta:Unpack()
    local cosine = math.Clamp((d11 + d22 + d33 - 1) * 0.5, -1, 1)
    local theta = math.acos(cosine)
    if theta < 1e-6 then return 0, 0, 0 end

    local scale = math.deg(theta) / (2 * math.sin(theta))
    local aboutForward = (d32 - d23) * scale
    local aboutLeft = (d13 - d31) * scale
    local aboutUp = (d21 - d12) * scale

    return -aboutLeft, aboutForward, aboutUp
end

local camBoneFrame

hook.Add("PostDrawViewModel", "SandSwep_CameraBone", function(vm, ply, wep)
    if ply ~= LocalPlayer() or not IsValid(wep) or not wep.IsSandSwep then return end
    if not IsValid(vm) or vm ~= ply:GetViewModel(0) then return end

    local frame = FrameNumber()
    if camBoneFrame == frame then return end
    camBoneFrame = frame

    if (wep.CameraAnimScale or 0) <= 0 or cvCamAnim:GetFloat() <= 0 then
        wep._camBone = nil
        return
    end

    local right, fwd, up = MeasureCameraBone(vm)
    if not right then
        wep._camBone = nil
        return
    end

    wep._camBone = wep._camBone or {}
    local bone = wep._camBone
    bone[1], bone[2], bone[3], bone.frame = right, fwd, up, frame
    bone.seq = Developer() and SandSwep.SequenceName(vm) or nil
end)

function SWEP:UpdateCameraAnim()
    local frameNum = FrameNumber()
    if self._camAnimFrame == frameNum then return end
    self._camAnimFrame = frameNum
    self._camAnimW = nil

    local scale = (self.CameraAnimScale or 0) * cvCamAnim:GetFloat()
    local ply = self:GetOwner()
    if scale <= 0 or not IsValid(ply) then
        self._camLocal = nil
        return
    end

    local bone = self._camBone
    local live = bone and frameNum - bone.frame <= 2
    local right, fwd, up = live and bone[1], live and bone[2], live and bone[3]
    self._camSeq = live and bone.seq or nil

    local tx, ty, tz = 0, 0, 0
    if right and (right ~= 0 or fwd ~= 0 or up ~= 0) then
        local gain = scale * Lerp(Smoothstep(self:GetAimProgress()), 1, self.CameraAnimAimScale or 1)
        tx, ty, tz = right * gain, fwd * gain, up * gain
    end

    local cur = self._camLocal
    if not cur then
        if tx == 0 and ty == 0 and tz == 0 then
            self._camDebug = 0
            return
        end
        cur = Vector(tx, ty, tz)
        self._camLocal = cur
    elseif tx == 0 and ty == 0 and tz == 0 and cur:LengthSqr() < 1e-8 then
        cur:SetUnpacked(0, 0, 0)
        self._camDebug = 0
        return
    else
        local frac = math.min(1, VisualFrameTime() * CAMERA_ANIM_EASE)
        cur:SetUnpacked(
            cur.x + (tx - cur.x) * frac,
            cur.y + (ty - cur.y) * frac,
            cur.z + (tz - cur.z) * frac)
    end

    local cx, cy, cz = cur.x, cur.y, cur.z
    local lenSqr = cx * cx + cy * cy + cz * cz
    if lenSqr > CAMERA_ANIM_MAX * CAMERA_ANIM_MAX then
        local k = CAMERA_ANIM_MAX / math.sqrt(lenSqr)
        cx, cy, cz = cx * k, cy * k, cz * k
    end

    if lenSqr <= 0.0001 then
        self._camDebug = math.sqrt(lenSqr)
        return
    end

    local eye = ply:EyeAngles()
    local er, ef, eu = eye:Right(), eye:Forward(), eye:Up()
    local world = self._camAnimWBuf
    if not world then
        world = Vector()
        self._camAnimWBuf = world
    end
    world:SetUnpacked(
        er.x * cx + ef.x * cy + eu.x * cz,
        er.y * cx + ef.y * cy + eu.y * cz,
        er.z * cx + ef.z * cy + eu.z * cz)
    self._camDebug = world:Length()
    self._camAnimW = world
end

hook.Add("HUDPaint", "SandSwep_CamDebug", function()
    if not Developer() then return end

    local wep = IsValid(LocalPlayer()) and LocalPlayer():GetActiveWeapon()
    if not IsValid(wep) or not wep.IsSandSwep then return end

    local vm = LocalPlayer():GetViewModel()
    local seq = IsValid(vm) and vm:GetSequenceName(vm:GetSequence()) or "?"
    local hasBone = IsValid(vm) and vm:LookupBone("b_camera") ~= nil

    local camText = string.format("anim camera: %.2f deg   (sequence: %s, camera bone: %s, measured: %s, last anim: %s)",
        wep._camDebug or 0, seq, hasBone and "yes" or "no", wep._camSeq and "yes" or "no", tostring(wep.LastAnim))
    draw.SimpleTextOutlined(camText, "DermaDefault", ScrW() * 0.5, ScrH() * 0.3, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)

    local wallText = string.format("wall: depth %.1f   reach %.1f   tilt %.1f deg",
        wep._wallPen or 0, wep._wallReach or 0, SandSwepWall and SandSwepWall.TiltDegrees(wep._wallTilt or 0) or 0)
    draw.SimpleTextOutlined(wallText, "DermaDefault", ScrW() * 0.5, ScrH() * 0.3 + 16, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
    if not IsValid(vm) then return end

    local data = SandSwep.GetSequenceData(vm:GetModel(), seq)
    local last = data and math.max(data.frames - 1, 1) or 1
    local marks = data and data.marks or {}
    local function mark(name) return marks[name] and string.format("%d", math.Round(marks[name] * last)) or "-" end

    local gripText = vm.SandSwepGripAlpha and string.format("grip layer %.2f", vm.SandSwepGripAlpha)
        or string.format("gripweight %.2f (off %s, on %s)", vm:LookupPoseParameter("gripweight") >= 0 and vm:GetPoseParameter("gripweight") or 0,
            mark("gripoff"), mark("gripon"))
    local animText = string.format("frame: %.1f / %d   cycle %.3f   rate %.2f   %s",
        vm:GetCycle() * last, last, vm:GetCycle(), vm:GetPlaybackRate(), gripText)
    draw.SimpleTextOutlined(animText, "DermaDefault", ScrW() * 0.5, ScrH() * 0.3 + 32, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)

    local bob = wep._bob
    if bob and bob.dbgDt then
        local bobText = string.format("bob: dt %.4f   RealFrameTime %.4f   speed %.0f   loops/s %.3f   effective loops/s %.3f   amount %.2f",
            bob.dbgDt, bob.dbgReal, bob.dbgSpeed, bob.dbgRate, bob.dbgRate * bob.dbgDt / math.max(bob.dbgReal, 1e-4), bob.amt)
        draw.SimpleTextOutlined(bobText, "DermaDefault", ScrW() * 0.5, ScrH() * 0.3 + 48, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
    end
end)

local camMotionAng = Angle()

local function ApplyCameraMotion(wep, ang)
    wep:UpdateCameraAnim()
    local sprint = wep:GetSprintCamera()
    local camW = wep._camAnimW
    local jump = wep._jumpCam
    if not sprint and not camW and not jump then return ang end

    camMotionAng:SetUnpacked(ang.p, ang.y, ang.r)
    if jump then RotateLocal(camMotionAng, jump[1], jump[2], jump[3]) end

    if camW then
        local deg = camW:Length()
        camMotionAng:RotateAroundAxis(camW / deg, deg)
    end

    if sprint then RotateLocal(camMotionAng, sprint[1], sprint[2], sprint[3]) end

    return camMotionAng
end

function SWEP:CalcView(ply, pos, ang, fov)
    if self:GetBipodWeight() > 0 then
        pos = self:GetBipodView(pos, ang, fov)
        self._bipodCam, self._bipodCamFrame = pos, FrameNumber()
    else
        self._bipodCam = nil
    end

    if not self:DeadzoneActive() then
        self._dzOff, self._dzVM, self._dzLast = nil, nil, nil
        return pos, ApplyCameraMotion(self, ang), fov
    end

    self:UpdateDeadzone(ply)
    local offset = self._dzOff
    if not offset then return pos, ApplyCameraMotion(self, ang), fov end

    local pitch = math.Clamp(ang.p + (self._dzLeadP or 0) - offset.p, -89, 89)
    local yaw = ang.y + (self._dzLeadY or 0) - offset.y
    local dzCam = self._dzCam
    if not dzCam then
        dzCam = Angle(pitch, yaw, ang.r)
        self._dzCam = dzCam
    else
        dzCam:SetUnpacked(pitch, yaw, ang.r)
    end
    local viewAng = ApplyCameraMotion(self, dzCam)
    if viewAng ~= dzCam then dzCam:SetUnpacked(viewAng.p, viewAng.y, viewAng.r) end

    self._dzCamFrame = FrameNumber()
    return pos, viewAng, fov
end

function SWEP:ReleaseDeadzone()
    local offset = self._dzOff
    local ply = self:GetOwner()

    if offset and IsValid(ply) and ply == LocalPlayer() and IsFirstTimePredicted() then
        local eye = ply:EyeAngles()
        ply:SetEyeAngles(Angle(math.Clamp(eye.p - offset.p, -89, 89), eye.y - offset.y, 0))
    end

    self._dzOff, self._dzVM, self._dzLast = nil, nil, nil
end

function SWEP:DrawHUD()
    if SandSwep and SandSwep.PaintHUD then SandSwep.PaintHUD("weapon DrawHUD") end
end

local aimTrace = {}

local function DrawAimDot(wep)
    local ply = wep:GetOwner()
    local src, dir, _, barrel = wep:GetBarrelShot()

    local screen
    if barrel then
        local tr = SandSwep.TraceLine(src, src + dir * 8192, ply, MASK_SHOT, aimTrace)
        screen = tr.HitPos:ToScreen()
    else
        screen = (ply:GetShootPos() + wep:GetAimDirection() * 4096):ToScreen()
    end
    if not screen.visible then return end

    local radius = math.max(2, math.Round(ScrH() / 540))
    surface.SetDrawColor(0, 0, 0, 120)
    surface.DrawRect(screen.x - radius - 1, screen.y - radius - 1, radius * 2 + 2, radius * 2 + 2)

    surface.SetDrawColor(235, 230, 215, 200)
    surface.DrawRect(screen.x - radius, screen.y - radius, radius * 2, radius * 2)
end

function SWEP:DoDrawCrosshair()
    if self:IsSafe() or self:GetAimProgress() > 0.1 then return true end
    if not self:DeadzoneActive() then return cvHideCrosshair:GetBool() end
    if cvCrosshair:GetBool() and not self:IsReloading() then DrawAimDot(self) end
    return true
end
