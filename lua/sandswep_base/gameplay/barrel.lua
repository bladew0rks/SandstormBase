-- Barrel bullets (client)

if CLIENT then
    local SEND_ACTIVE = 1 / 66
    local SEND_IDLE = 1 / 5

    local barrelFrame, barrelUpdateNext, barrelNext, wasActive = nil, 0, 0, false
    local muzzleScratch, barrelScratch = Vector(), Vector()
    local localPosScratch, localDirScratch = Vector(), Vector()
    local aimAngScratch = Angle()
    local muzzleMat = Matrix()
    local cvCrosshair

    local function NeedsFrameAccurateBarrel(wep)
        if not wep.DeadzoneActive or not wep:DeadzoneActive() then return false end
        cvCrosshair = cvCrosshair or GetConVar("cl_sandswep_crosshair")
        if cvCrosshair and not cvCrosshair:GetBool() then return false end
        return not wep:IsSafe() and not wep:IsReloading() and wep:GetAimProgress() <= 0.1
    end

    local function MuzzleAttachmentId(vm)
        local model = vm:GetModel()
        if vm.SandSwepMuzzleMdl ~= model then
            vm.SandSwepMuzzleMdl = model
            vm.SandSwepMuzzleAtt = vm:LookupAttachment("muzzle") or -1
        end
        return vm.SandSwepMuzzleAtt
    end

    local function UpdateBarrel(vm, ply, wep)
        if ply ~= LocalPlayer() or not IsValid(wep) or not wep.IsSandSwep or not wep.SetBarrelData then return end
        if not IsValid(vm) or vm ~= ply:GetViewModel(0) or ply:ShouldDrawLocalPlayer() then return end

        local frameNum = FrameNumber()
        if barrelFrame == frameNum then return end
        barrelFrame = frameNum

        local now = RealTime()
        local active = ply:KeyDown(IN_ATTACK) or wep:GetBurstLeft() > 0 or wep:GetAimProgress() > 0
        if not NeedsFrameAccurateBarrel(wep) and now < barrelUpdateNext and not (active and not wasActive) then
            wasActive = active
            return
        end
        barrelUpdateNext = now + SEND_ACTIVE

        local vmView = SandSwep.VMView
        if not vmView then return end

        local view = vmView.ViewInfo(wep, true)

        local muzzlePos, muzzleFwd
        local attId = MuzzleAttachmentId(vm)
        local attData = attId and attId > 0 and vm:GetAttachment(attId)
        if attData then
            muzzlePos, muzzleFwd = attData.Pos, attData.Ang:Forward()
        else
            local bone = SandSwep.BoneId(vm, "b_wpn_muzzle")
            local matrix = bone and SandSwep.Math.CopyBone(vm, bone, muzzleMat)
            local frame = vmView.GunFrame(vm, view)
            if not matrix or not frame then return end
            muzzlePos, muzzleFwd = matrix:GetTranslation(), frame.F
        end

        local muzzleWorld = vmView.ToWorld(muzzlePos, view, muzzleScratch)

        barrelScratch:Set(muzzleFwd)
        barrelScratch:Mul(20)
        barrelScratch:Add(muzzlePos)
        local barrelDir = vmView.ToWorld(barrelScratch, view, barrelScratch)
        barrelDir:Sub(muzzleWorld)       -- the drawn barrel's line, in the world
        barrelDir:Normalize()

        local base = wep:GetBulletSource()
        local eyeAng = ply:EyeAngles()
        local punch = ply:GetViewPunchAngles()
        aimAngScratch:SetUnpacked(eyeAng.p + punch.p, eyeAng.y + punch.y, eyeAng.r + punch.r)

        local aimFwd, aimRight, aimUp = aimAngScratch:Forward(), aimAngScratch:Right(), aimAngScratch:Up()
        local dx, dy, dz = muzzleWorld.x - base.x, muzzleWorld.y - base.y, muzzleWorld.z - base.z
        localPosScratch:SetUnpacked(
            dx * aimFwd.x + dy * aimFwd.y + dz * aimFwd.z,
            -(dx * aimRight.x + dy * aimRight.y + dz * aimRight.z),
            dx * aimUp.x + dy * aimUp.y + dz * aimUp.z)

        local bx, by, bz = barrelDir.x, barrelDir.y, barrelDir.z
        localDirScratch:SetUnpacked(
            bx * aimFwd.x + by * aimFwd.y + bz * aimFwd.z,
            -(bx * aimRight.x + by * aimRight.y + bz * aimRight.z),
            bx * aimUp.x + by * aimUp.y + bz * aimUp.z)

        local wall = SandSwepWall
        local tiltDeg = wall and math.Clamp(math.Round(wall.TiltDegrees(wep._wallTilt or 0)), 0, 90) or 0
        wep:SetBarrelData(localPosScratch, localDirScratch, tiltDeg)

        local canReach = wall
            and not wep:IsActionBusy() and not wep:IsSafe() and not wep:IsMagChecking()
            and wep:GetSprintVisual() <= 0

        if canReach then
            local vmPos, vmFwd = vm:GetPos(), vm:GetForward()
            local reach = (muzzlePos.x - vmPos.x) * vmFwd.x
                + (muzzlePos.y - vmPos.y) * vmFwd.y
                + (muzzlePos.z - vmPos.z) * vmFwd.z
            if reach > 4 then
                reach = math.Clamp(reach, wall.MinReach, wall.MaxReach)
                wep._wallReach = wep._wallReach and Lerp(math.min(5 * RealFrameTime(), 1), wep._wallReach, reach) or reach
            end
        end

        if now >= barrelNext or (active and not wasActive) then
            barrelNext = now + (active and SEND_ACTIVE or SEND_IDLE)
            net.Start("sandswep_muzzle", true)
                net.WriteVector(localPosScratch)
                net.WriteNormal(localDirScratch)
                net.WriteUInt(tiltDeg, 7)
            net.SendToServer()
        end
        wasActive = active
    end

    local handsFrame = -10

    hook.Add("PostDrawViewModel", "SandSwep_Barrel", function(vm, ply, wep)
        if FrameNumber() - handsFrame <= 1 then return end      -- wait for the hands, the bones are complete by then
        UpdateBarrel(vm, ply, wep)
    end)

    hook.Add("PostDrawPlayerHands", "SandSwep_Barrel", function(_, vm, ply, wep)
        handsFrame = FrameNumber()
        UpdateBarrel(vm, ply, wep)
    end)
end
