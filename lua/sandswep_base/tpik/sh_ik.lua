SANDTPIK = SANDTPIK or {}

local SOFT_STRETCH_START = 0.92
local POLE_MIN_LENGTH = 0.25
local BODY_MIN_WEIGHT = 0.05

local normalize = SandSwep.Math.Unit

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
