local VisualFrameTime = SandSwep.VisualFrameTime

if not CLIENT then return end

local cvShells = CreateClientConVar("cl_sandswep_shells", "1", true, false, "Casings", 0, 1)
local cvShellLife = CreateClientConVar("cl_sandswep_shell_life", "15", true, false, "Casing lifetime (s)", 0, 120)

local MAX_SHELLS = 90
local GRAVITY = 600
local EJECT_VM_TIME = 0.2
local PENDING_TIMEOUT = 0.15
local CM = 0.393700787
local FADE_TIME = 3
local STEP = 1 / 30

local view = SandSwep.VMView
local shells = {}
local pending = {}
local debugShells = false

local function ShellDebug(msg, ...)
    if debugShells then print("[sandswep shells] " .. string.format(msg, ...)) end
end

local function Jitter(x)
    return x * math.Rand(0.8, 1.2)
end

local function RemoveShell(i)
    local shell = shells[i]
    if shell and IsValid(shell.ent) then shell.ent:Remove() end
    table.remove(shells, i)
end

local function TrimShells()
    while #shells > MAX_SHELLS do RemoveShell(1) end
end

local function GetEjects(wep)
    if istable(wep.Ejects) then return wep.Ejects end

    if isstring(wep.ShellModel) and wep.ShellModel ~= "" then
        wep._legacyEjects = wep._legacyEjects or { {
            Model = wep.ShellModel,
            Attachment = wep.ShellAttachment or "shell",
            Velocity = wep.ShellVelocity or Vector(0, 150, 70),
            ViewAxes = true,
            Sounds = wep.ShellSounds,
            RestRoll = 90,
        } }
        return wep._legacyEjects
    end
end

function SWEP:PrecacheShells()
    for _, spec in ipairs(GetEjects(self) or {}) do
        SandSwep.WarmModel(spec.Model)
    end
end

local function EjectPoint(vm, spec, frame, info)
    if spec.Pos and frame then
        return frame.m * (spec.Pos * CM)
    end

    local att = vm:LookupAttachment(spec.Attachment or "shell")
    local data = att and att > 0 and vm:GetAttachment(att)
    if data then
        if spec.Offset and frame then
            local off = spec.Offset * CM
            return data.Pos + frame.R * -off.x + frame.F * -off.y + frame.U * off.z
        end
        return data.Pos
    end

    ShellDebug("no spawn point for %s on %s, using a fixed spot", spec.Model, vm:GetModel())
    local pos = info.origin + info.ang:Forward() * 14 + info.ang:Right() * 5 - info.ang:Up() * 5
    return view.ToVM(pos, info)
end

local function SpawnEject(owner, vm, spec, info, frame, worldOnly)
    local model = spec.Model
    if not isstring(model) or model == "" then return end

    local vmPos = EjectPoint(vm, spec, frame, info)
    local fwd, right, up
    if frame and not spec.ViewAxes then
        fwd, right, up = frame.F, frame.R, frame.U
    else
        fwd, right, up = info.ang:Forward(), info.ang:Right(), info.ang:Up()
    end

    local baseVel = spec.Velocity or Vector(0, 150, 70)
    local vmVel = fwd * Jitter(baseVel.x) + right * Jitter(baseVel.y) + up * Jitter(baseVel.z)

    local worldPos = view.ToWorld(vmPos, info)
    local dt = 0.02
    local vel = (view.ToWorld(vmPos + vmVel * dt, info) - worldPos) / dt + owner:GetVelocity()
    local ang = fwd:AngleEx(up)

    util.PrecacheModel(model)
    local ent = ClientsideModel(model, RENDERGROUP_OPAQUE)
    if not IsValid(ent) then return ShellDebug("ClientsideModel(%s) failed", model) end

    ent:SetPos(worldPos)
    ent:SetAngles(ang)
    if not worldOnly then ent:SetNoDraw(true) end

    local spin = spec.Spin
    shells[#shells + 1] = {
        ent = ent,
        vel = vel,
        ang = ang,
        prevPos = Vector(worldPos),
        nextPos = Vector(worldPos),
        drawPos = Vector(worldPos),
        acc = STEP,
        alpha = 255,
        spin = spin and Angle(Jitter(spin.p), Jitter(spin.y), Jitter(spin.r))
            or Angle(math.Rand(-900, 900), math.Rand(500, 1100), math.Rand(-300, 300)),
        born = CurTime(),
        bounces = 0,
        rest = false,
        vmStage = not worldOnly,
        restRoll = spec.RestRoll or 0,
        sounds = spec.Sounds,
        pitch = spec.Pitch,
    }

    ShellDebug("spawned %s at %s (vm %s)", model, tostring(worldPos), tostring(vmPos))
    TrimShells()
end

local function SpawnAll(wep, vm, info, worldOnly, ejects)
    local owner = wep:GetOwner()
    ejects = ejects or GetEjects(wep)
    if not ejects or not IsValid(owner) then return end

    local frame = view.GunFrame(vm, info)
    for _, spec in ipairs(ejects) do SpawnEject(owner, vm, spec, info, frame, worldOnly) end
end

local function LeaveViewmodel(shell)
    shell.vmStage = false
    shell.ent:DisableMatrix("RenderMultiply")
    shell.ent:SetNoDraw(false)
end

function SWEP:EjectCasingClient()
    ShellDebug("EjectCasingClient called")
    self._shotCount = (self._shotCount or 0) + 1

    if self.ShotBones then
        local times = self._shotTimes or {}
        self._shotTimes = times
        times[#times + 1] = CurTime()
        while #times > 8 do table.remove(times, 1) end
    end

    if not cvShells:GetBool() then return ShellDebug("off (cl_sandswep_shells 0)") end

    local owner = self:GetOwner()
    if not IsValid(owner) or owner ~= LocalPlayer() then return ShellDebug("not the local player's gun") end
    if owner:ShouldDrawLocalPlayer() then return ShellDebug("third person") end

    if self.HangingBelt then self._beltFeeds = math.min((self._beltFeeds or 0) + 1, 32) end
    if not GetEjects(self) then return ShellDebug("nothing to eject (no Ejects / ShellModel)") end

    pending[#pending + 1] = { wep = self, t = CurTime() }
end

function SWEP:EjectLiveRoundClient()
    if not cvShells:GetBool() or not istable(self.LiveEjects) then return end

    local owner = self:GetOwner()
    if not IsValid(owner) or owner ~= LocalPlayer() or owner:ShouldDrawLocalPlayer() then return end

    pending[#pending + 1] = { wep = self, t = CurTime(), ejects = self.LiveEjects }
end

local lastFrame
local scaleMatrix, scaleVec = Matrix(), Vector()
hook.Add("PostDrawViewModel", "SandSwep_Shells", function(vm, ply, wep)
    if ply ~= LocalPlayer() or not IsValid(vm) or vm ~= ply:GetViewModel(0) then return end

    local frameNum = FrameNumber()
    if lastFrame == frameNum then return end
    lastFrame = frameNum

    local info = view.ViewInfo(wep, true)

    for i = #pending, 1, -1 do
        local queued = pending[i]
        if queued.wep == wep and IsValid(wep) then SpawnAll(wep, vm, info, false, queued.ejects) end
        table.remove(pending, i)
    end

    local ct = CurTime()
    for _, shell in ipairs(shells) do
        local ent = shell.ent
        if shell.vmStage and IsValid(ent) then
            local age = ct - shell.born
            if age >= EJECT_VM_TIME then
                LeaveViewmodel(shell)
            else
                local worldPos = ent:GetPos()
                local scale = Lerp(math.Clamp(age / EJECT_VM_TIME, 0, 1), 1, 1 / info.k)

                scaleVec:SetUnpacked(scale, scale, scale)
                scaleMatrix:Identity()
                scaleMatrix:Scale(scaleVec)
                ent:EnableMatrix("RenderMultiply", scaleMatrix)

                ent:SetPos(view.ToVM(worldPos, info))
                ent:SetupBones()
                ent:DrawModel()
                ent:SetPos(worldPos)
            end
        end
    end

    SandSwep.DrawViewmodelBelts(wep, vm, info)
end)

local function FlushPending(ct)
    for i = #pending, 1, -1 do
        local queued = pending[i]

        if not IsValid(queued.wep) then
            table.remove(pending, i)
        elseif ct - queued.t > PENDING_TIMEOUT then
            local owner = queued.wep:GetOwner()
            local vm = IsValid(owner) and owner.GetViewModel and owner:GetViewModel(0)
            if IsValid(vm) then SpawnAll(queued.wep, vm, view.ViewInfo(queued.wep, false), true, queued.ejects) end

            table.remove(pending, i)
        end
    end
end

local function PlayBounce(shell, pos, speed)
    if speed <= 50 or shell.bounces > 3 then return end
    if not shell.sounds or #shell.sounds == 0 then return end

    local pmin, pmax = 95, 110
    if shell.pitch then pmin, pmax = shell.pitch[1], shell.pitch[2] end

    sound.Play(shell.sounds[math.random(#shell.sounds)], pos, 60, math.random(pmin, pmax), math.Clamp(speed / 250, 0.15, 0.6))
end

local traceOut = {}
local traceIn = { output = traceOut, mask = MASK_SOLID }

local stepTo, push, spinStep = Vector(), Vector(), Angle()

local function StepShell(shell, ply)
    local vel = shell.vel
    local prevPos, nextPos = shell.prevPos, shell.nextPos
    vel.z = vel.z - GRAVITY * STEP

    prevPos:Set(nextPos)
    stepTo:Set(vel)
    stepTo:Mul(STEP)
    stepTo:Add(prevPos)

    traceIn.start, traceIn.endpos, traceIn.filter = prevPos, stepTo, ply
    util.TraceLine(traceIn)

    if not traceOut.Hit or traceOut.StartSolid then
        nextPos:Set(stepTo)
        return
    end

    local normal = traceOut.HitNormal
    local speed = vel:Length()

    push:Set(normal)
    push:Mul(vel:Dot(normal) * 0.85)
    vel:Mul(0.55)
    vel:Sub(push)

    nextPos:Set(normal)
    nextPos:Mul(0.4)
    nextPos:Add(traceOut.HitPos)

    shell.spin:Mul(0.5)
    shell.bounces = shell.bounces + 1
    PlayBounce(shell, nextPos, speed)

    if normal.z > 0.7 and vel:Length() < 25 then
        shell.rest = true
        shell.ang = Angle(0, shell.ang.y, shell.restRoll)
    end
end

local function MoveShell(shell, dt, ply)
    shell.acc = math.min(shell.acc + dt, STEP * 8)
    while shell.acc >= STEP and not shell.rest do
        StepShell(shell, ply)
        shell.acc = shell.acc - STEP
    end

    local ent = shell.ent
    if shell.rest then
        ent:SetPos(shell.nextPos)
        ent:SetAngles(shell.ang)
        return
    end

    local drawPos = shell.drawPos
    drawPos:Set(shell.nextPos)
    drawPos:Sub(shell.prevPos)
    drawPos:Mul(shell.acc / STEP)
    drawPos:Add(shell.prevPos)
    ent:SetPos(drawPos)

    spinStep:Set(shell.spin)
    spinStep:Mul(dt)
    shell.ang:Add(spinStep)
    ent:SetAngles(shell.ang)
end

local fadeColor = Color(255, 255, 255, 255)

hook.Add("Think", "SandSwep_Shells", function()
    local ct = CurTime()
    FlushPending(ct)
    if #shells == 0 then return end

    local dt = VisualFrameTime()
    local life = cvShellLife:GetFloat()
    local ply = LocalPlayer()

    for i = #shells, 1, -1 do
        local shell = shells[i]
        local ent = shell.ent
        local age = ct - shell.born
        local valid = IsValid(ent)

        if not valid or age > life + FADE_TIME then
            RemoveShell(i)
        else
            if shell.vmStage and age > EJECT_VM_TIME + 0.1 then LeaveViewmodel(shell) end
            if not shell.rest and dt > 0 then MoveShell(shell, dt, ply) end

            if age > life then
                if not shell.fading then
                    shell.fading = true
                    ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
                end

                local alpha = math.floor((1 - math.Clamp((age - life) / FADE_TIME, 0, 1)) * 255)
                if alpha ~= shell.alpha then
                    shell.alpha = alpha
                    fadeColor.a = alpha
                    ent:SetColor(fadeColor)
                end
            end
        end
    end
end)

concommand.Add("sandswep_testshell", function()
    local wep = LocalPlayer():GetActiveWeapon()
    if not IsValid(wep) or not wep.EjectCasingClient then
        print("[sandswep shells] hold a sandswep gun")
        return
    end

    debugShells = true
    local ok, err = pcall(wep.EjectCasingClient, wep)
    debugShells = false

    if not ok then print("[sandswep shells] ERROR: " .. tostring(err)) end
    print("[sandswep shells] queued; alive: " .. #shells)
end)

concommand.Add("sandswep_clearshells", function()
    for i = #shells, 1, -1 do RemoveShell(i) end
end)
