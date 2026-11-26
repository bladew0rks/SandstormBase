if not CLIENT then return end

local Unit, CopyBone = SandSwep.Math.Unit, SandSwep.Math.CopyBone
local gunMat, muzzleMat = Matrix(), Matrix()
local gunF, gunR, gunU = Vector(), Vector(), Vector()
local gunFrame = { m = gunMat, F = gunF, R = gunR, U = gunU }

local renderView, renderFrame, renderWep
local nonRenderView = {}

local function ViewInfo(wep, inRender)
    local frame = FrameNumber()
    if inRender and renderFrame == frame and renderWep == wep then return renderView end

    local owner = IsValid(wep) and wep:GetOwner()
    local setup = inRender and render.GetViewSetup and render.GetViewSetup()
    local origin, ang
    if setup and setup.origin and setup.angles then
        origin, ang = setup.origin, setup.angles
    elseif inRender then
        origin, ang = EyePos(), EyeAngles()
    else
        origin = IsValid(owner) and owner:EyePos() or EyePos()
        ang = IsValid(owner) and owner:EyeAngles() or EyeAngles()
    end

    local fov = (setup and setup.fov) or (IsValid(owner) and owner:GetFOV()) or 75
    local vmFov = (setup and setup.fovviewmodel) or (IsValid(wep) and wep.ViewModelFOV) or 62

    local scale = math.tan(math.rad(fov) * 0.5) / math.max(math.tan(math.rad(vmFov) * 0.5), 0.01)

    local view
    if inRender then
        view = renderView or {}
        renderView, renderFrame, renderWep = view, frame, wep
    else
        view = nonRenderView
    end

    view.origin, view.ang, view.fwd, view.k = origin, ang, ang:Forward(), scale
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
    local boneMat = bone and CopyBone(vm, bone, gunMat)
    if not boneMat then return end

    local m11, m12, m13, ox, m21, m22, m23, oy, m31, m32, m33, oz = boneMat:Unpack()
    local lx, ly, lz = Unit(m11, m21, m31)
    local fx, fy, fz = Unit(-m12, -m22, -m32)
    local ux, uy, uz = Unit(m13, m23, m33)

    local muzzleBone = SandSwep.BoneId(vm, "b_wpn_muzzle")
    local muzzle = muzzleBone and CopyBone(vm, muzzleBone, muzzleMat)
    if muzzle then
        local mx = muzzle:GetField(1, 4) - ox
        local my = muzzle:GetField(2, 4) - oy
        local mz = muzzle:GetField(3, 4) - oz
        if mx * mx + my * my + mz * mz > 1 then
            mx, my, mz = Unit(mx, my, mz)
            if mx * fx + my * fy + mz * fz < 0.5 then
                fx, fy, fz = mx, my, mz
                local viewUp = view.ang:Up()
                local dot = fx * viewUp.x + fy * viewUp.y + fz * viewUp.z
                ux, uy, uz = Unit(viewUp.x - fx * dot, viewUp.y - fy * dot, viewUp.z - fz * dot)
                lx, ly, lz = -(fy * uz - fz * uy), -(fz * ux - fx * uz), -(fx * uy - fy * ux)
            end
        end
    end

    gunF:SetUnpacked(fx, fy, fz)
    gunR:SetUnpacked(-lx, -ly, -lz)
    gunU:SetUnpacked(ux, uy, uz)
    return gunFrame
end

SandSwep.VMView = {
    ViewInfo = ViewInfo,
    ToWorld = ToWorld,
    ToVM = ToVM,
    GunFrame = GunFrame,
}
