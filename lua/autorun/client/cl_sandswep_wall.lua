SandSwepWall = SandSwepWall or {}
local WALL = SandSwepWall

WALL.Margin = 2
WALL.Pivot = Vector(10, -3, -5)
WALL.Tilt = Angle(40, 10, 12)
WALL.DefaultReach = 28
WALL.MinReach = 8
WALL.MaxReach = 60

local SETTINGS = {
    strength = 0.9,
    speed_in = 10,
    speed_out = 7.7,
    pullback = 4.5,
    tilt = 65,
    tilt_range = 0.59,
}

function WALL.Setting(name)
    return SETTINGS[name]
end

local hull = Vector(2, 2, 2)
local result = {}
local trace = {
    mins = -hull,
    maxs = hull,
    mask = bit.band(MASK_SOLID, bit.bnot(CONTENTS_MONSTER)),
    output = result,
}

function WALL.Penetration(ply, eyePos, eyeAng, reach)
    local length = reach + WALL.Margin

    trace.start = eyePos
    trace.endpos = eyePos + eyeAng:Forward() * length
    trace.filter = ply
    util.TraceHull(trace)

    if result.Hit and not result.StartSolid and not result.HitSky then
        return length * (1 - result.Fraction)
    end

    return 0
end

function WALL.Update(state, penetration, dt, stamp)
    state.amount = state.amount or 0
    state.velocity = state.velocity or 0

    if stamp ~= nil and state.stamp == stamp then
        return math.max(state.amount, 0)
    end

    state.stamp = stamp

    local omega = penetration > state.amount and WALL.Setting("speed_in") or WALL.Setting("speed_out")
    omega = math.max(omega, 0.1)

    dt = math.Clamp(dt, 0, 0.1)
    local steps = math.max(math.ceil(dt * 240), 1)
    dt = dt / steps

    for _ = 1, steps do
        local accel = omega * omega * (penetration - state.amount) - 2 * omega * state.velocity
        state.velocity = state.velocity + accel * dt
        state.amount = state.amount + state.velocity * dt
    end

    if state.amount ~= state.amount then
        state.amount, state.velocity = 0, 0
    end

    return math.max(state.amount, 0)
end

function WALL.Response(amount, reach, aimDelta)
    if amount < 0.01 then return 0, 0 end

    local strength = WALL.Setting("strength")
    local maxBack = WALL.Setting("pullback")
    local tiltScale = WALL.Setting("tilt") / WALL.Tilt.p
    local tiltRange = math.max(WALL.Setting("tilt_range"), 0.05)

    local back = math.min(amount, maxBack) * Lerp(aimDelta, 1, 0.75) * strength
    local tilt = math.Clamp((amount - maxBack * 0.5) / (reach * tiltRange), 0, 1)
    tilt = tilt * tilt * (3 - 2 * tilt) * Lerp(aimDelta, 1, 0.5) * strength * tiltScale

    return back, tilt
end

function WALL.Apply(pos, ang, eyeAng, back, tilt)
    if back <= 0 and tilt <= 0 then return pos end

    local pivotBefore = LocalToWorld(WALL.Pivot, angle_zero, pos, ang)
    ang:RotateAroundAxis(ang:Right(), WALL.Tilt.p * tilt)
    ang:RotateAroundAxis(ang:Up(), WALL.Tilt.y * tilt)
    ang:RotateAroundAxis(ang:Forward(), -WALL.Tilt.r * tilt)
    local pivotAfter = LocalToWorld(WALL.Pivot, angle_zero, pos, ang)

    return pos + (pivotBefore - pivotAfter)
        - eyeAng:Forward() * back
        - eyeAng:Up() * (back * 0.15)
end

function WALL.TiltDegrees(tilt)
    return WALL.Tilt.p * tilt
end

hook.Add("Think", "SandSwep_WallTrace", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not wep.IsSandSwep then return end

    local blocked = ply:InVehicle()
        or (wep.GetBipodDeployed and wep:GetBipodDeployed())
    if blocked then
        wep._wallPen = 0
        return
    end

    wep._wallPen = WALL.Penetration(ply, ply:GetShootPos(), ply:EyeAngles(), wep._wallReach or WALL.DefaultReach)
end)
