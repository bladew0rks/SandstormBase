SANDTPIK = SANDTPIK or {}

function SANDTPIK.Solve2PartIK(startPos, endPos, upperLen, lowerLen, sign, angs)
    local reach = math.max((startPos - endPos):Length(), 0.001)
    local span = upperLen + lowerLen

    if span > 0 and reach > span then
        local scale = math.min(reach / span, SANDTPIK.ArmStretch or 1.35)
        upperLen = upperLen * scale
        lowerLen = lowerLen * scale
    end

    local cosShoulder = math.Clamp(((reach * reach) + (upperLen * upperLen) - (lowerLen * lowerLen)) / (2 * reach * upperLen), -1, 1)
    local shoulderAng = -math.deg(math.acos(cosShoulder))
    local cosElbow = math.Clamp(((lowerLen * lowerLen) + (upperLen * upperLen) - (reach * reach)) / (2 * lowerLen * upperLen), -1, 1)
    local elbowAng = -math.deg(math.acos(cosElbow))

    local dir = endPos - startPos
    dir:Normalize()

    local pitch = math.deg(math.atan2(-math.sqrt(dir.x * dir.x + dir.y * dir.y), dir.z)) - 90
    local yaw = math.NormalizeAngle(-math.deg(math.atan2(dir.x, dir.y)) - 90)

    local axis = dir * 1
    axis:Normalize()

    local roll = 90 + (sign > 0 and -30 or 30)
    local torsoRight = angs.y + 120 * sign

    local upperJoint = Angle(shoulderAng + pitch, yaw, 0)
    upperJoint:RotateAroundAxis(upperJoint:Forward(), roll)
    upperJoint:RotateAroundAxis(axis, yaw - torsoRight)
    local upperAng = -(-upperJoint)

    local lowerJoint = Angle(shoulderAng + pitch + 180 + elbowAng, yaw, 0)
    lowerJoint:RotateAroundAxis(lowerJoint:Forward(), roll)
    lowerJoint:RotateAroundAxis(axis, yaw - torsoRight)
    local lowerAng = -(-lowerJoint)

    local elbow = startPos + upperJoint:Forward() * upperLen
    local hand = elbow + lowerJoint:Forward() * lowerLen

    return elbow, hand, upperAng, lowerAng
end

local SOFT_STRETCH_START = 0.92
local POLE_MIN_LENGTH = 0.25
local BODY_MIN_WEIGHT = 0.05

local function normalize(x, y, z)
    local len = math.sqrt(x * x + y * y + z * z)
    if len < 1e-6 then return 0, 0, 0, 0 end

    return x / len, y / len, z / len, len
end

local function perpendicular(px, py, pz, dx, dy, dz)
    local dot = px * dx + py * dy + pz * dz
    return normalize(px - dx * dot, py - dy * dot, pz - dz * dot)
end

function SANDTPIK.SolvePoleIK(rootPos, targetPos, poleDir, dropDir, dropWeight, upperLen, lowerLen)
    local rx, ry, rz = rootPos.x, rootPos.y, rootPos.z
    local dx, dy, dz, reach = normalize(targetPos.x - rx, targetPos.y - ry, targetPos.z - rz)
    if reach < 0.001 then dx, dy, dz, reach = 0, 0, -1, 0.001 end

    local span = upperLen + lowerLen
    local maxScale = SANDTPIK.ArmStretch or 1.35
    local range = maxScale - SOFT_STRETCH_START

    if span > 0 and range > 0 then
        local stretch = 1 + (maxScale - 1) * math.Clamp((reach / span - SOFT_STRETCH_START) / range, 0, 1)
        upperLen, lowerLen, span = upperLen * stretch, lowerLen * stretch, span * stretch
    end

    if reach >= span then
        return Vector(rx + dx * upperLen, ry + dy * upperLen, rz + dz * upperLen),
            Vector(rx + dx * span, ry + dy * span, rz + dz * span)
    end

    local px, py, pz = normalize(poleDir.x, poleDir.y, poleDir.z)
    local dot = px * dx + py * dy + pz * dz
    px, py, pz = px - dx * dot, py - dy * dot, pz - dz * dot

    local poleScale = (1 - dropWeight) / math.max(math.sqrt(px * px + py * py + pz * pz), POLE_MIN_LENGTH)
    local bodyScale = math.max(dropWeight, BODY_MIN_WEIGHT)
    local fx, fy, fz = perpendicular(dropDir.x, dropDir.y, dropDir.z, dx, dy, dz)
    local bx, by, bz, bend = normalize(px * poleScale + fx * bodyScale, py * poleScale + fy * bodyScale, pz * poleScale + fz * bodyScale)
    if bend == 0 then bx, by, bz, bend = perpendicular(0, 0, -1, dx, dy, dz) end
    if bend == 0 then bx, by, bz = perpendicular(1, 0, 0, dx, dy, dz) end

    local cosShoulder = math.Clamp((upperLen * upperLen + reach * reach - lowerLen * lowerLen) / (2 * upperLen * reach), -1, 1)
    local along = upperLen * cosShoulder
    local out = upperLen * math.sqrt(1 - cosShoulder * cosShoulder)

    local elbow = Vector(rx + dx * along + bx * out, ry + dy * along + by * out, rz + dz * along + bz * out)
    local hand = Vector(rx + dx * reach, ry + dy * reach, rz + dz * reach)

    return elbow, hand
end
