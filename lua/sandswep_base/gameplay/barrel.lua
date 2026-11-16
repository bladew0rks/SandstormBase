-- Barrel bullets (client)

if CLIENT then
    local SEND_ACTIVE = 1 / 66
    local SEND_IDLE = 1 / 5

    local barrelFrame, barrelNext, wasActive = nil, 0, false
    local muzzleScratch, barrelScratch = Vector(), Vector()
    hook.Add("PostDrawViewModel", "SandSwep_Barrel", function(vm, ply, wep)
        if ply ~= LocalPlayer() or not IsValid(wep) or not wep.IsSandSwep or not wep.SetBarrelData then return end
        if not IsValid(vm) or vm ~= ply:GetViewModel(0) or ply:ShouldDrawLocalPlayer() then return end

        local frameNum = FrameNumber()
        if barrelFrame == frameNum then return end
        barrelFrame = frameNum

        local vmView = SandSwep.VMView
        if not vmView then return end

        local view = vmView.ViewInfo(wep, true)
        local frame = vmView.GunFrame(vm, view)
        if not frame then return end

        local muzzlePos
        local attId = vm:LookupAttachment("muzzle")
        local attData = attId and attId > 0 and vm:GetAttachment(attId)
        if attData then
            muzzlePos = attData.Pos
        else
            local bone = SandSwep.BoneId(vm, "b_wpn_muzzle")
            local matrix = bone and vm:GetBoneMatrix(bone)
            if not matrix then return end
            muzzlePos = matrix:GetTranslation()
        end

        local muzzleWorld = vmView.ToWorld(muzzlePos, view, muzzleScratch)

        barrelScratch:Set(frame.F)
        barrelScratch:Mul(20)
        barrelScratch:Add(muzzlePos)
        local barrelDir = vmView.ToWorld(barrelScratch, view, barrelScratch)
        barrelDir:Sub(muzzleWorld)       -- the drawn barrel's line, in the world
        barrelDir:Normalize()

        local base = wep:GetBulletSource()
        local aimAng = ply:EyeAngles() + ply:GetViewPunchAngles()
        local localPos = WorldToLocal(muzzleWorld, angle_zero, base, aimAng)
        local localDir = WorldToLocal(barrelDir, angle_zero, vector_origin, aimAng)

        local wall = SandSwepWall
        local tiltDeg = wall and math.Clamp(math.Round(wall.TiltDegrees(wep._wallTilt or 0)), 0, 90) or 0
        wep:SetBarrelData(localPos, localDir, tiltDeg)

        local canReach = wall
            and not wep:IsActionBusy() and not wep:IsSafe() and not wep:IsMagChecking()
            and wep:GetSprintVisual() <= 0

        if canReach then
            local reach = WorldToLocal(muzzlePos, angle_zero, vm:GetPos(), vm:GetAngles()).x
            if reach > 4 then
                reach = math.Clamp(reach, wall.MinReach, wall.MaxReach)
                wep._wallReach = wep._wallReach and Lerp(math.min(5 * RealFrameTime(), 1), wep._wallReach, reach) or reach
            end
        end

        local active = ply:KeyDown(IN_ATTACK) or wep:GetBurstLeft() > 0 or wep:GetAimProgress() > 0
        local now = RealTime()
        if now >= barrelNext or (active and not wasActive) then
            barrelNext = now + (active and SEND_ACTIVE or SEND_IDLE)
            net.Start("sandswep_muzzle", true)
                net.WriteVector(localPos)
                net.WriteNormal(localDir)
                net.WriteUInt(tiltDeg, 7)
            net.SendToServer()
        end
        wasActive = active
    end)
end
