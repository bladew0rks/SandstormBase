SandSwep = SandSwep or {}
SandSwep.Math = SandSwep.Math or {}

local MATH = SandSwep.Math
local sqrt, abs, exp, min, max = math.sqrt, math.abs, math.exp, math.min, math.max

local function Clamp01(x)
    return x < 0 and 0 or (x > 1 and 1 or x)
end
MATH.Clamp01 = Clamp01

local function Smoothstep(t)
    return t * t * (3 - 2 * t)
end
MATH.Smoothstep = Smoothstep

function MATH.Smoothstep01(t)
    return Smoothstep(Clamp01(t))
end

function MATH.Lerp(cur, target, time, dt)
    local step = (dt or SandSwep.VisualFrameTime()) / max(time, 0.01)
    if cur < target then return min(cur + step, target) end
    return max(cur - step, target)
end

local function DampFactor(speed, dt)
    return 1 - exp(-speed * (dt or SandSwep.VisualFrameTime()))
end
MATH.DampFactor = DampFactor

function MATH.Damp(cur, target, speed, dt)
    return cur + (target - cur) * DampFactor(speed, dt)
end

local function Unit(x, y, z)
    local len = sqrt(x * x + y * y + z * z)
    if len < 1e-6 then return 0, 0, 0, 0 end

    return x / len, y / len, z / len, len
end
MATH.Unit = Unit

local function RotateXYZ(vx, vy, vz, ax, ay, az, cos, sin)
    local dot = (ax * vx + ay * vy + az * vz) * (1 - cos)
    return vx * cos + (ay * vz - az * vy) * sin + ax * dot,
        vy * cos + (az * vx - ax * vz) * sin + ay * dot,
        vz * cos + (ax * vy - ay * vx) * sin + az * dot
end

local function TurnMatrix(mat, axis, cos, sin, pivot)
    local m11, m12, m13, m14, m21, m22, m23, m24, m31, m32, m33, m34 = mat:Unpack()
    local ax, ay, az = axis.x, axis.y, axis.z
    local px, py, pz = pivot.x, pivot.y, pivot.z

    m11, m21, m31 = RotateXYZ(m11, m21, m31, ax, ay, az, cos, sin)
    m12, m22, m32 = RotateXYZ(m12, m22, m32, ax, ay, az, cos, sin)
    m13, m23, m33 = RotateXYZ(m13, m23, m33, ax, ay, az, cos, sin)
    m14, m24, m34 = RotateXYZ(m14 - px, m24 - py, m34 - pz, ax, ay, az, cos, sin)

    mat:SetUnpacked(
        m11, m12, m13, m14 + px,
        m21, m22, m23, m24 + py,
        m31, m32, m33, m34 + pz,
        0, 0, 0, 1)
    return mat
end
MATH.RotateXYZ = RotateXYZ
MATH.TurnMatrix = TurnMatrix

local function ReadMatrix(out, mat)
    out[1], out[2], out[3], out[4], out[5], out[6], out[7], out[8], out[9], out[10], out[11], out[12] = mat:Unpack()
end

local function CopyMatrix(out, src)
    for k = 1, 12 do out[k] = src[k] end
end

local function MulMatrix(out, lhs, rhs)
    local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 = lhs[1], lhs[2], lhs[3], lhs[4], lhs[5], lhs[6], lhs[7], lhs[8], lhs[9], lhs[10], lhs[11], lhs[12]
    local b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12 = rhs[1], rhs[2], rhs[3], rhs[4], rhs[5], rhs[6], rhs[7], rhs[8], rhs[9], rhs[10], rhs[11], rhs[12]

    out[1] = a1 * b1 + a2 * b5 + a3 * b9
    out[2] = a1 * b2 + a2 * b6 + a3 * b10
    out[3] = a1 * b3 + a2 * b7 + a3 * b11
    out[4] = a1 * b4 + a2 * b8 + a3 * b12 + a4
    out[5] = a5 * b1 + a6 * b5 + a7 * b9
    out[6] = a5 * b2 + a6 * b6 + a7 * b10
    out[7] = a5 * b3 + a6 * b7 + a7 * b11
    out[8] = a5 * b4 + a6 * b8 + a7 * b12 + a8
    out[9] = a9 * b1 + a10 * b5 + a11 * b9
    out[10] = a9 * b2 + a10 * b6 + a11 * b10
    out[11] = a9 * b3 + a10 * b7 + a11 * b11
    out[12] = a9 * b4 + a10 * b8 + a11 * b12 + a12
end

local function InvMulMatrix(out, lhs, rhs)
    local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 = lhs[1], lhs[2], lhs[3], lhs[4], lhs[5], lhs[6], lhs[7], lhs[8], lhs[9], lhs[10], lhs[11], lhs[12]
    local c1, c2, c3 = a6 * a11 - a7 * a10, a3 * a10 - a2 * a11, a2 * a7 - a3 * a6
    local det = a1 * c1 + a5 * c2 + a9 * c3
    if abs(det) < 1e-12 then return false end

    local invDet = 1 / det
    local i1, i2, i3 = c1 * invDet, c2 * invDet, c3 * invDet
    local i5, i6, i7 = (a7 * a9 - a5 * a11) * invDet, (a1 * a11 - a3 * a9) * invDet, (a3 * a5 - a1 * a7) * invDet
    local i9, i10, i11 = (a5 * a10 - a6 * a9) * invDet, (a2 * a9 - a1 * a10) * invDet, (a1 * a6 - a2 * a5) * invDet

    local b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12 = rhs[1], rhs[2], rhs[3], rhs[4] - a4, rhs[5], rhs[6], rhs[7], rhs[8] - a8, rhs[9], rhs[10], rhs[11], rhs[12] - a12

    out[1] = i1 * b1 + i2 * b5 + i3 * b9
    out[2] = i1 * b2 + i2 * b6 + i3 * b10
    out[3] = i1 * b3 + i2 * b7 + i3 * b11
    out[4] = i1 * b4 + i2 * b8 + i3 * b12
    out[5] = i5 * b1 + i6 * b5 + i7 * b9
    out[6] = i5 * b2 + i6 * b6 + i7 * b10
    out[7] = i5 * b3 + i6 * b7 + i7 * b11
    out[8] = i5 * b4 + i6 * b8 + i7 * b12
    out[9] = i9 * b1 + i10 * b5 + i11 * b9
    out[10] = i9 * b2 + i10 * b6 + i11 * b10
    out[11] = i9 * b3 + i10 * b7 + i11 * b11
    out[12] = i9 * b4 + i10 * b8 + i11 * b12

    return true
end
MATH.ReadMatrix = ReadMatrix
MATH.CopyMatrix = CopyMatrix
MATH.MulMatrix = MulMatrix
MATH.InvMulMatrix = InvMulMatrix

local ROT = {}

local function QuatRot(x, y, z, w)
    ROT[1], ROT[2], ROT[3] = 1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)
    ROT[4], ROT[5], ROT[6] = 2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)
    ROT[7], ROT[8], ROT[9] = 2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)
end

local function RotMul(out, mat)
    local r1, r2, r3, r4, r5, r6, r7, r8, r9 = ROT[1], ROT[2], ROT[3], ROT[4], ROT[5], ROT[6], ROT[7], ROT[8], ROT[9]
    local a1, a2, a3, a5, a6, a7, a9, a10, a11 = mat[1], mat[2], mat[3], mat[5], mat[6], mat[7], mat[9], mat[10], mat[11]

    out[1] = r1 * a1 + r2 * a5 + r3 * a9
    out[2] = r1 * a2 + r2 * a6 + r3 * a10
    out[3] = r1 * a3 + r2 * a7 + r3 * a11
    out[5] = r4 * a1 + r5 * a5 + r6 * a9
    out[6] = r4 * a2 + r5 * a6 + r6 * a10
    out[7] = r4 * a3 + r5 * a7 + r6 * a11
    out[9] = r7 * a1 + r8 * a5 + r9 * a9
    out[10] = r7 * a2 + r8 * a6 + r9 * a10
    out[11] = r7 * a3 + r8 * a7 + r9 * a11
end
MATH.QuatRot = QuatRot
MATH.RotMul = RotMul

local function BetweenRot(ax, ay, az, bx, by, bz)
    ax, ay, az = Unit(ax, ay, az)
    bx, by, bz = Unit(bx, by, bz)

    local w = 1 + ax * bx + ay * by + az * bz
    local x, y, z
    if w < 1e-6 then
        w = 0
        if abs(ax) > abs(az) then
            x, y, z = -ay, ax, 0
        else
            x, y, z = 0, -az, ay
        end
    else
        x, y, z = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
    end

    local len = sqrt(x * x + y * y + z * z + w * w)
    QuatRot(x / len, y / len, z / len, w / len)
end
MATH.BetweenRot = BetweenRot

--[[
    Copyright © 2026 Stephen Leitnick
    Copyright (c) 2023 tukars

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
    documentation files (the "Software"), to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of
    the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
    THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]]
local QUAT_EPSILON = 1e-5
local sin, cos, acos, atan2, rad, deg, log = math.sin, math.cos, math.acos, math.atan2, math.rad, math.deg, math.log

local function QuatDot(ax, ay, az, aw, bx, by, bz, bw)
    return ax * bx + ay * by + az * bz + aw * bw
end
MATH.QuatDot = QuatDot

local function QuatNormalize(x, y, z, w)
    local len = sqrt(x * x + y * y + z * z + w * w)
    if len < QUAT_EPSILON then return 0, 0, 0, 1 end

    local inv = 1 / len
    return x * inv, y * inv, z * inv, w * inv
end
MATH.QuatNormalize = QuatNormalize

local function QuatMul(ax, ay, az, aw, bx, by, bz, bw)
    return aw * bx + ax * bw + ay * bz - az * by,
        aw * by + ay * bw + az * bx - ax * bz,
        aw * bz + az * bw + ax * by - ay * bx,
        aw * bw - ax * bx - ay * by - az * bz
end
MATH.QuatMul = QuatMul

local function QuatInverse(x, y, z, w)
    local inv = 1 / (x * x + y * y + z * z + w * w)
    return -x * inv, -y * inv, -z * inv, w * inv
end
MATH.QuatInverse = QuatInverse

local function QuatAxisAngle(ax, ay, az, angle)
    local s = sin(angle * 0.5)
    return ax * s, ay * s, az * s, cos(angle * 0.5)
end
MATH.QuatAxisAngle = QuatAxisAngle

local function QuatToAxisAngle(x, y, z, w)
    local scale = sqrt(x * x + y * y + z * z)
    if scale < QUAT_EPSILON or w > 1 or w < -1 then return 0, 0, 1, 0 end

    local inv = 1 / scale
    return x * inv, y * inv, z * inv, 2 * acos(w)
end
MATH.QuatToAxisAngle = QuatToAxisAngle

local function QuatRotate(x, y, z, w, vx, vy, vz)
    local x2, y2, z2 = x * 2, y * 2, z * 2
    local xx, yy, zz = x * x2, y * y2, z * z2
    local xy, xz, yz = x * y2, x * z2, y * z2
    local wx, wy, wz = w * x2, w * y2, w * z2

    return (1 - (yy + zz)) * vx + (xy - wz) * vy + (xz + wy) * vz,
        (xy + wz) * vx + (1 - (xx + zz)) * vy + (yz - wx) * vz,
        (xz - wy) * vx + (yz + wx) * vy + (1 - (xx + yy)) * vz
end
MATH.QuatRotate = QuatRotate

local function QuatSlerp(ax, ay, az, aw, bx, by, bz, bw, t)
    local cosOmega = ax * bx + ay * by + az * bz + aw * bw
    local flip = cosOmega < 0
    if flip then cosOmega = -cosOmega end

    local s1, s2
    if cosOmega > 1 - QUAT_EPSILON then
        s1, s2 = 1 - t, t
    else
        local omega = acos(cosOmega)
        local invSin = 1 / sin(omega)
        s1, s2 = sin((1 - t) * omega) * invSin, sin(t * omega) * invSin
    end
    if flip then s2 = -s2 end

    return s1 * ax + s2 * bx, s1 * ay + s2 * by, s1 * az + s2 * bz, s1 * aw + s2 * bw
end
MATH.QuatSlerp = QuatSlerp

local function QuatNlerp(ax, ay, az, aw, bx, by, bz, bw, t)
    if ax * bx + ay * by + az * bz + aw * bw < 0 then t = -t end
    local s = t < 0 and 1 + t or 1 - t

    return QuatNormalize(ax * s + bx * t, ay * s + by * t, az * s + bz * t, aw * s + bw * t)
end
MATH.QuatNlerp = QuatNlerp

local function QuatAngle(ax, ay, az, aw, bx, by, bz, bw)
    local dot = min(abs(ax * bx + ay * by + az * bz + aw * bw), 1)
    return dot > 1 - QUAT_EPSILON and 0 or acos(dot) * 2
end
MATH.QuatAngle = QuatAngle

local function QuatFromRotation(m00, m01, m02, m10, m11, m12, m20, m21, m22)
    local fx, fy, fz = Unit(m00, m10, m20)
    local lx, ly, lz = Unit(m01, m11, m21)
    local ux, uy, uz = Unit(m02, m12, m22)
    m00, m10, m20, m01, m11, m21, m02, m12, m22 = fx, fy, fz, lx, ly, lz, ux, uy, uz

    local trace = m00 + m11 + m22
    if trace > 0 then
        local s = sqrt(trace + 1) * 2
        local inv = 1 / s
        return (m21 - m12) * inv, (m02 - m20) * inv, (m10 - m01) * inv, 0.25 * s
    elseif m00 > m11 and m00 > m22 then
        local s = sqrt(1 + m00 - m11 - m22) * 2
        local inv = 1 / s
        return 0.25 * s, (m01 + m10) * inv, (m02 + m20) * inv, (m21 - m12) * inv
    elseif m11 > m22 then
        local s = sqrt(1 + m11 - m00 - m22) * 2
        local inv = 1 / s
        return (m01 + m10) * inv, 0.25 * s, (m12 + m21) * inv, (m02 - m20) * inv
    end

    local s = sqrt(1 + m22 - m00 - m11) * 2
    local inv = 1 / s
    return (m02 + m20) * inv, (m12 + m21) * inv, 0.25 * s, (m10 - m01) * inv
end
MATH.QuatFromRotation = QuatFromRotation

local function QuatFromMatrix(mat)
    local m00, m01, m02, _, m10, m11, m12, _, m20, m21, m22 = mat:Unpack()
    return QuatFromRotation(m00, m01, m02, m10, m11, m12, m20, m21, m22)
end
MATH.QuatFromMatrix = QuatFromMatrix

local function QuatToRotation(x, y, z, w)
    local x2, y2, z2 = x * 2, y * 2, z * 2
    local xx, yy, zz = x * x2, y * y2, z * z2
    local xy, xz, yz = x * y2, x * z2, y * z2
    local wx, wy, wz = w * x2, w * y2, w * z2

    return 1 - (yy + zz), xy - wz, xz + wy,
        xy + wz, 1 - (xx + zz), yz - wx,
        xz - wy, yz + wx, 1 - (xx + yy)
end
MATH.QuatToRotation = QuatToRotation

function MATH.QuatToMatrix(out, x, y, z, w, tx, ty, tz, sx, sy, sz)
    local m00, m01, m02, m10, m11, m12, m20, m21, m22 = QuatToRotation(x, y, z, w)
    sx, sy, sz = sx or 1, sy or 1, sz or 1

    out:SetUnpacked(
        m00 * sx, m01 * sy, m02 * sz, tx or 0,
        m10 * sx, m11 * sy, m12 * sz, ty or 0,
        m20 * sx, m21 * sy, m22 * sz, tz or 0,
        0, 0, 0, 1)
    return out
end

local function QuatFromAngles(p, y, r)
    p, y, r = rad(p) * 0.5, rad(y) * 0.5, rad(r) * 0.5
    local sp, cp, sy, cy, sr, cr = sin(p), cos(p), sin(y), cos(y), sin(r), cos(r)

    return cy * cp * sr - sy * sp * cr,
        cy * sp * cr + sy * cp * sr,
        sy * cp * cr - cy * sp * sr,
        cy * cp * cr + sy * sp * sr
end
MATH.QuatFromAngles = QuatFromAngles

local function QuatToAngles(x, y, z, w)
    local m00, m01, _, m10, m11, _, m20, m21, m22 = QuatToRotation(x, y, z, w)
    local flat = sqrt(m00 * m00 + m10 * m10)

    if flat > 0.001 then
        return deg(atan2(-m20, flat)), deg(atan2(m10, m00)), deg(atan2(m21, m22))
    end

    return deg(atan2(-m20, flat)), deg(atan2(-m01, m11)), 0
end
MATH.QuatToAngles = QuatToAngles

local function QuatLookRotation(fx, fy, fz, ux, uy, uz)
    fx, fy, fz = Unit(fx, fy, fz)
    ux, uy, uz = ux or 0, uy or 0, uz or 1

    local lx, ly, lz = Unit(uy * fz - uz * fy, uz * fx - ux * fz, ux * fy - uy * fx)
    if lx == 0 and ly == 0 and lz == 0 then lx, ly, lz = Unit(fz, 0, -fx) end
    ux, uy, uz = fy * lz - fz * ly, fz * lx - fx * lz, fx * ly - fy * lx

    return QuatFromRotation(fx, lx, ux, fy, ly, uy, fz, lz, uz)
end
MATH.QuatLookRotation = QuatLookRotation

local function QuatLog(x, y, z, w)
    local vv = x * x + y * y + z * z
    local mm = w * w + vv
    if mm <= 0 then return 0, 0, 0, -math.huge end
    if vv <= 0 then return 0, 0, 0, log(mm) * 0.5 end

    local m = sqrt(mm)
    local s = acos(w / m) / sqrt(vv)
    return x * s, y * s, z * s, log(m)
end
MATH.QuatLog = QuatLog

local function QuatExp(x, y, z, w)
    local m = exp(w)
    local vv = x * x + y * y + z * z
    if vv <= 0 then return 0, 0, 0, m end

    local v = sqrt(vv)
    local s = m * sin(v) / v
    return x * s, y * s, z * s, m * cos(v)
end
MATH.QuatExp = QuatExp

local function QuatPow(x, y, z, w, power)
    if power == -1 then return QuatInverse(x, y, z, w) end

    local im = x * x + y * y + z * z
    local mag = sqrt(w * w + im)
    local imLen = sqrt(im)
    local outMag = mag ^ power
    if imLen <= QUAT_EPSILON * mag then return 0, 0, 0, outMag end

    local angle = power * atan2(imLen, w)
    local s = outMag * sin(angle) / imLen
    return x * s, y * s, z * s, outMag * cos(angle)
end
MATH.QuatPow = QuatPow

local function QuatDifference(ax, ay, az, aw, bx, by, bz, bw)
    if ax * bx + ay * by + az * bz + aw * bw < 0 then ax, ay, az, aw = -ax, -ay, -az, -aw end

    local ix, iy, iz, iw = QuatInverse(ax, ay, az, aw)
    return QuatMul(ix, iy, iz, iw, bx, by, bz, bw)
end
MATH.QuatDifference = QuatDifference

local function QuatToRotationVector(x, y, z, w)
    local ax, ay, az, angle = QuatToAxisAngle(x, y, z, w)
    return ax * angle, ay * angle, az * angle
end
MATH.QuatToRotationVector = QuatToRotationVector

function MATH.QuatAngularVelocity(ax, ay, az, aw, bx, by, bz, bw, dt)
    if dt <= 0 then return 0, 0, 0 end

    local vx, vy, vz = QuatToRotationVector(QuatDifference(ax, ay, az, aw, bx, by, bz, bw))
    local inv = 1 / dt
    return vx * inv, vy * inv, vz * inv
end

function MATH.QuatIntegrate(x, y, z, w, rx, ry, rz, dt)
    x, y, z, w = QuatNormalize(x, y, z, w)

    local ax, ay, az, angle = Unit(rx * dt, ry * dt, rz * dt)
    if angle <= 0 then return x, y, z, w end

    local qx, qy, qz, qw = QuatAxisAngle(ax, ay, az, angle)
    return QuatNormalize(QuatMul(x, y, z, w, qx, qy, qz, qw))
end

local Quaternion = {}
Quaternion.__index = Quaternion

local function NewQuat(x, y, z, w)
    return setmetatable({ X = x, Y = y, Z = z, W = w }, Quaternion)
end

local QUAT = {
    new = NewQuat,
    identity = NewQuat(0, 0, 0, 1),
}
MATH.Quaternion = QUAT

function QUAT.axisAngle(axis, angle)
    local ax, ay, az = Unit(axis.x, axis.y, axis.z)
    return NewQuat(QuatAxisAngle(ax, ay, az, angle))
end

function QUAT.angles(ang)
    return NewQuat(QuatFromAngles(ang.p, ang.y, ang.r))
end

function QUAT.lookRotation(forward, up)
    if up then return NewQuat(QuatLookRotation(forward.x, forward.y, forward.z, up.x, up.y, up.z)) end
    return NewQuat(QuatLookRotation(forward.x, forward.y, forward.z))
end

function QUAT.matrix(mat)
    return NewQuat(QuatFromMatrix(mat))
end

function QUAT.IsQuaternion(value)
    return getmetatable(value) == Quaternion
end

function Quaternion:Unpack()
    return self.X, self.Y, self.Z, self.W
end

function Quaternion:Dot(other)
    return QuatDot(self.X, self.Y, self.Z, self.W, other.X, other.Y, other.Z, other.W)
end

function Quaternion:Slerp(other, t)
    return NewQuat(QuatSlerp(self.X, self.Y, self.Z, self.W, other.X, other.Y, other.Z, other.W, t))
end

function Quaternion:Nlerp(other, t)
    return NewQuat(QuatNlerp(self.X, self.Y, self.Z, self.W, other.X, other.Y, other.Z, other.W, t))
end

function Quaternion:Angle(other)
    return QuatAngle(self.X, self.Y, self.Z, self.W, other.X, other.Y, other.Z, other.W)
end

function Quaternion:RotateTowards(other, maxRadiansDelta)
    local angle = self:Angle(other)
    if angle == 0 then return self end

    return self:Slerp(other, min(maxRadiansDelta / angle, 1))
end

function Quaternion:ToMatrix(pos, out)
    out = out or Matrix()
    if pos then return MATH.QuatToMatrix(out, self.X, self.Y, self.Z, self.W, pos.x, pos.y, pos.z) end

    return MATH.QuatToMatrix(out, self.X, self.Y, self.Z, self.W)
end

function Quaternion:ToAngles()
    return Angle(QuatToAngles(self.X, self.Y, self.Z, self.W))
end

function Quaternion:ToAxisAngle()
    local ax, ay, az, angle = QuatToAxisAngle(self.X, self.Y, self.Z, self.W)
    return Vector(ax, ay, az), angle
end

function Quaternion:Inverse()
    return NewQuat(QuatInverse(self.X, self.Y, self.Z, self.W))
end

function Quaternion:Conjugate()
    return NewQuat(-self.X, -self.Y, -self.Z, self.W)
end

function Quaternion:Normalize()
    return NewQuat(QuatNormalize(self.X, self.Y, self.Z, self.W))
end

function Quaternion:Magnitude()
    return sqrt(self:Dot(self))
end

function Quaternion:SqrMagnitude()
    return self:Dot(self)
end

function Quaternion:Log()
    return NewQuat(QuatLog(self.X, self.Y, self.Z, self.W))
end

function Quaternion:Exp()
    return NewQuat(QuatExp(self.X, self.Y, self.Z, self.W))
end

function Quaternion:Pow(power)
    return NewQuat(QuatPow(self.X, self.Y, self.Z, self.W, power))
end

function Quaternion:Difference(other)
    return NewQuat(QuatDifference(self.X, self.Y, self.Z, self.W, other.X, other.Y, other.Z, other.W))
end

function Quaternion:AngularVelocity(other, dt)
    return Vector(MATH.QuatAngularVelocity(self.X, self.Y, self.Z, self.W, other.X, other.Y, other.Z, other.W, dt))
end

function Quaternion:Integrate(rate, dt)
    return NewQuat(MATH.QuatIntegrate(self.X, self.Y, self.Z, self.W, rate.x, rate.y, rate.z, dt))
end

function Quaternion:Rotate(vec)
    return Vector(QuatRotate(self.X, self.Y, self.Z, self.W, vec.x, vec.y, vec.z))
end

function Quaternion.__mul(a, b)
    if getmetatable(b) == Quaternion then
        return NewQuat(QuatMul(a.X, a.Y, a.Z, a.W, b.X, b.Y, b.Z, b.W))
    end
    if isvector(b) then return a:Rotate(b) end

    error("cannot multiply a quaternion with " .. type(b), 2)
end

function Quaternion.__pow(self, power)
    return self:Pow(power)
end

function Quaternion.__unm(self)
    return NewQuat(-self.X, -self.Y, -self.Z, -self.W)
end

function Quaternion.__eq(a, b)
    return a.X == b.X and a.Y == b.Y and a.Z == b.Z and a.W == b.W
end

function Quaternion.__tostring(self)
    return string.format("Quaternion(%g, %g, %g, %g)", self.X, self.Y, self.Z, self.W)
end

local ENTITY = FindMetaTable("Entity")
local copyBoneMatrix, getBoneMatrix = ENTITY.CopyBoneMatrix, ENTITY.GetBoneMatrix

function MATH.CopyBone(ent, bone, out)
    if bone < 0 or bone >= ent:GetBoneCount() then return end

    if copyBoneMatrix then
        copyBoneMatrix(ent, bone, out)
        return out
    end

    local mat = getBoneMatrix(ent, bone)
    if not mat then return end

    out:Set(mat)
    return out
end

function MATH.BlendMatrix(from, to, w, out)
    local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 = from:Unpack()
    local b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12 = to:Unpack()

    local fx, fy, fz, fLen = Unit(a1 + (b1 - a1) * w, a5 + (b5 - a5) * w, a9 + (b9 - a9) * w)
    local ux, uy, uz = a3 + (b3 - a3) * w, a7 + (b7 - a7) * w, a11 + (b11 - a11) * w
    local rx, ry, rz, rLen = Unit(fy * uz - fz * uy, fz * ux - fx * uz, fx * uy - fy * ux)

    if fLen == 0 or rLen == 0 then
        if out ~= to then out:Set(to) end
        return out
    end

    ux, uy, uz = ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx

    local sx = sqrt(a1 * a1 + a5 * a5 + a9 * a9)
    local sy = sqrt(a2 * a2 + a6 * a6 + a10 * a10)
    local sz = sqrt(a3 * a3 + a7 * a7 + a11 * a11)
    sx = sx + (sqrt(b1 * b1 + b5 * b5 + b9 * b9) - sx) * w
    sy = sy + (sqrt(b2 * b2 + b6 * b6 + b10 * b10) - sy) * w
    sz = sz + (sqrt(b3 * b3 + b7 * b7 + b11 * b11) - sz) * w

    out:SetUnpacked(
        fx * sx, -rx * sy, ux * sz, a4 + (b4 - a4) * w,
        fy * sx, -ry * sy, uy * sz, a8 + (b8 - a8) * w,
        fz * sx, -rz * sy, uz * sz, a12 + (b12 - a12) * w,
        0, 0, 0, 1)
    return out
end
