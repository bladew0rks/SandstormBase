SandSwep = SandSwep or {}
SandSwep.Math = SandSwep.Math or {}

local MATH = SandSwep.Math
local sqrt = math.sqrt

local function Unit(x, y, z)
    local len = sqrt(x * x + y * y + z * z)
    if len < 1e-6 then return 0, 0, 0, 0 end

    return x / len, y / len, z / len, len
end
MATH.Unit = Unit

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
