SandSwep = SandSwep or {}
SandSwep.Math = SandSwep.Math or {}

local MATH = SandSwep.Math
local sqrt, abs = math.sqrt, math.abs

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
