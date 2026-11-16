if not CLIENT then return end

local AXIS_X, AXIS_Y, AXIS_Z = Vector(1, 0, 0), Vector(0, 1, 0), Vector(0, 0, 1)

local renderView, renderFrame, renderWep

local function ViewInfo(wep, inRender)
    local frame = FrameNumber()
    if inRender and renderFrame == frame and renderWep == wep then return renderView end

    local owner = IsValid(wep) and wep:GetOwner()
    local origin, ang
    if inRender then
        origin, ang = EyePos(), EyeAngles()
    else
        origin = IsValid(owner) and owner:EyePos() or EyePos()
        ang = IsValid(owner) and owner:EyeAngles() or EyeAngles()
    end

    local fov = IsValid(owner) and owner:GetFOV() or 75
    local vmFov = (IsValid(wep) and wep.ViewModelFOV) or 62
    local setup = inRender and render.GetViewSetup and render.GetViewSetup()
    if setup and setup.fov and setup.fovviewmodel then fov, vmFov = setup.fov, setup.fovviewmodel end

    local scale = math.tan(math.rad(fov) * 0.5) / math.max(math.tan(math.rad(vmFov) * 0.5), 0.01)

    local view = inRender and renderView or {}
    view.origin, view.ang, view.fwd, view.k = origin, ang, ang:Forward(), scale
    if inRender then renderView, renderFrame, renderWep = view, frame, wep end

    return view
end

local function Rescale(pos, view, scale, out)
    out = out or Vector()
    out:Set(pos)
    out:Sub(view.origin)

    local fwd = view.fwd
    local along = out:Dot(fwd) * (1 - scale)
    out:Mul(scale)
    out:Add(view.origin)
    out.x, out.y, out.z = out.x + fwd.x * along, out.y + fwd.y * along, out.z + fwd.z * along

    return out
end

local function ToWorld(pos, view, out)
    return Rescale(pos, view, view.k, out)
end

local function ToVM(pos, view, out)
    return Rescale(pos, view, 1 / view.k, out)
end

local function GunFrame(vm, view)
    local bone = SandSwep.BoneId(vm, "b_wpn")
    local boneMat = bone and vm:GetBoneMatrix(bone)
    if not boneMat then return end

    local origin = boneMat:GetTranslation()
    local left = (boneMat * AXIS_X) - origin
    left:Normalize()
    local fwd = origin - (boneMat * AXIS_Y)
    fwd:Normalize()
    local up = (boneMat * AXIS_Z) - origin
    up:Normalize()

    local muzzleBone = SandSwep.BoneId(vm, "b_wpn_muzzle")
    local muzzle = muzzleBone and vm:GetBoneMatrix(muzzleBone)
    if muzzle then
        local toMuzzle = muzzle:GetTranslation() - origin
        if toMuzzle:LengthSqr() > 1 then
            toMuzzle:Normalize()
            if toMuzzle:Dot(fwd) < 0.5 then
                fwd = toMuzzle
                local viewUp = view.ang:Up()
                up = viewUp - fwd * fwd:Dot(viewUp)
                up:Normalize()
                left = -fwd:Cross(up)
            end
        end
    end

    return {
        m = boneMat,
        F = fwd,
        R = -left,
        U = up,
    }
end

SandSwep.VMView = {
    ViewInfo = ViewInfo,
    ToWorld = ToWorld,
    ToVM = ToVM,
    GunFrame = GunFrame,
}
