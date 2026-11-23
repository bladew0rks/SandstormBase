-- welcome to math hell

SandSwep = SandSwep or {}
SandSwep.GripData = SandSwep.GripData or {}

local DIR = "sandswep_base/gripdata/"
local REQUIRED_FIELDS = { "map", "curves", "deltas", "joint", "stretch" }

local function GripDataProblem(data)
    if not istable(data) then return "did not return a table" end
    if not isstring(data.model) then return "has no model" end

    for _, field in ipairs(REQUIRED_FIELDS) do
        if not istable(data[field]) then return "is missing " .. field end
    end
end

for _, fileName in ipairs(file.Find(DIR .. "*.lua", "LUA")) do
    local path = DIR .. fileName

    if SERVER then
        AddCSLuaFile(path)
        continue
    end

    local ok, data = pcall(include, path)

    local problem
    if ok then
        problem = GripDataProblem(data)
    else
        problem = tostring(data)
    end

    if problem then
        ErrorNoHalt("[sandswep grip] " .. path .. ": " .. problem .. "\n")
    else
        SandSwep.GripData[string.lower(data.model)] = data
    end
end

if SERVER then return end

local THUMB_HOLD, THUMB_RATE = 0.1, 6
local THUMB_HOLD_IN, THUMB_RATE_IN = 0.03, 14

local sqrt, abs, min, max = math.sqrt, math.abs, math.min, math.max

local IDLE_RAIL_MIN, IDLE_RAIL_MAX = -0.25, 1.25
local IDLE_RAIL_RADIUS_SQR = 0.36

local function Clamp01(x)
    return x < 0 and 0 or (x > 1 and 1 or x)
end

local function Read(out, mat)
    out[1], out[2], out[3], out[4], out[5], out[6], out[7], out[8], out[9], out[10], out[11], out[12] = mat:Unpack()
end

local function Copy(out, src)
    for k = 1, 12 do out[k] = src[k] end
end

local function Mul(out, lhs, rhs)
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

local function InvMul(out, lhs, rhs)
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

local function DeltaRot(delta, weight)
    local bias = delta[5] >= 0 and 1 or -1
    local x, y, z, w = delta[2] * weight, delta[3] * weight, delta[4] * weight, delta[5] * weight + (1 - weight) * bias
    local len = sqrt(x * x + y * y + z * z + w * w)
    QuatRot(x / len, y / len, z / len, w / len)
end

local function Normalize(x, y, z)
    local len = sqrt(x * x + y * y + z * z)
    if len < 1e-12 then return 0, 0, 0 end

    return x / len, y / len, z / len
end

local function BetweenRot(ax, ay, az, bx, by, bz)
    ax, ay, az = Normalize(ax, ay, az)
    bx, by, bz = Normalize(bx, by, bz)

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

local function SolveTwoBone(rx, ry, rz, jx, jy, jz, tx, ty, tz, gx, gy, gz, ex, ey, ez, startRatio, maxScale)
    local upper = sqrt((jx - rx) ^ 2 + (jy - ry) ^ 2 + (jz - rz) ^ 2)
    local lower = sqrt((tx - jx) ^ 2 + (ty - jy) ^ 2 + (tz - jz) ^ 2)
    local maxLen = upper + lower

    local dx, dy, dz = ex - rx, ey - ry, ez - rz
    local len = sqrt(dx * dx + dy * dy + dz * dz)
    if len < 1e-4 then
        len, dx, dy, dz = 1e-4, 1, 0, 0
    else
        dx, dy, dz = dx / len, dy / len, dz / len
    end

    local qx, qy, qz = gx - rx, gy - ry, gz - rz
    local bx, by, bz
    if qx * qx + qy * qy + qz * qz < 1e-8 then
        bx, by, bz = 0, 1, 0
    else
        local nx, ny, nz = dy * qz - dz * qy, dz * qx - dx * qz, dx * qy - dy * qx
        if nx * nx + ny * ny + nz * nz < 1e-8 then
            local fx, fy, fz = 0, 0, 1
            if abs(dz) >= 0.999 then fx, fz = 1, 0 end
            local cx, cy, cz = Normalize(fy * dz - fz * dy, fz * dx - fx * dz, fx * dy - fy * dx)
            bx, by, bz = dy * cz - dz * cy, dz * cx - dx * cz, dx * cy - dy * cx
        else
            local dot = qx * dx + qy * dy + qz * dz
            bx, by, bz = Normalize(qx - dx * dot, qy - dy * dot, qz - dz * dot)
        end
    end

    local range = maxScale - startRatio
    if range > 1e-4 and maxLen > 1e-4 then
        local scale = (maxScale - 1) * Clamp01((len / maxLen - startRatio) / range)
        if scale > 1e-4 then
            upper, lower, maxLen = upper * (1 + scale), lower * (1 + scale), maxLen * (1 + scale)
        end
    end

    if len >= maxLen then
        return rx + dx * upper, ry + dy * upper, rz + dz * upper, rx + dx * maxLen, ry + dy * maxLen, rz + dz * maxLen
    end

    local twoAB = 2 * upper * len
    local cosA = twoAB ~= 0 and (upper * upper + len * len - lower * lower) / twoAB or 0
    cosA = max(-1, min(1, cosA))

    local lineDist = upper * sqrt(1 - cosA * cosA)
    local proj = upper * cosA

    return rx + dx * proj + bx * lineDist, ry + dy * proj + by * lineDist, rz + dz * proj + bz * lineDist, ex, ey, ez
end

local function EvalCurve(keys, x)
    local count = #keys
    if count == 0 then return 0 end
    if x <= keys[1][1] then return keys[1][2] end

    for i = 1, count - 1 do
        local key, nextKey = keys[i], keys[i + 1]
        if x < nextKey[1] then
            if key[3] == 1 then return key[2] end

            local span = nextKey[1] - key[1]
            if span <= 0 then return nextKey[2] end

            return key[2] + (nextKey[2] - key[2]) * (x - key[1]) / span
        end
    end

    return keys[count][2]
end

local function ArmBoneSets(rig, list, parent, under, inSet)
    local fixed = { [rig.upper] = true, [rig.fore] = true, [rig.hand] = true }

    local chain = {}
    for _, start in ipairs({ rig.fore, rig.hand }) do
        local bone = parent[start]
        while bone and inSet[bone] and not fixed[bone] do
            chain[bone] = true
            bone = parent[bone]
        end
    end

    local deferred = {}
    for _, i in ipairs(list) do
        if under[i] and not fixed[i] and not chain[i] then deferred[i] = true end
    end

    return fixed, deferred
end

local function Prepare(vm, data)
    local function BoneId(name)
        local bone = vm:LookupBone(name)
        return bone and bone >= 0 and bone or nil
    end

    local rig = {
        clav = BoneId("b_ch_l_clavical"),
        upper = BoneId("b_ch_l_upperarm"),
        fore = BoneId("b_ch_l_forearm"),
        hand = BoneId("b_ch_l_hand"),
        ikw = BoneId("ik_hand_wpn_l"),
        ikl = BoneId("ik_hand_l"),
    }
    if not (rig.clav and rig.upper and rig.fore and rig.hand and rig.ikw and rig.ikl) then return false end

    local inSet, list, parent, under, outside, seen = {}, {}, {}, {}, {}, {}
    for i = 0, vm:GetBoneCount() - 1 do
        local parentId = vm:GetBoneParent(i)
        local tracked = i == rig.clav or i == rig.ikw or i == rig.ikl or (parentId >= 0 and inSet[parentId])
        if tracked then
            inSet[i] = true
            list[#list + 1] = i
            parent[i] = parentId
            if i == rig.upper or under[parentId] then under[i] = true end

            if not inSet[parentId] and not seen[parentId] then
                seen[parentId] = true
                outside[#outside + 1] = parentId
            end
        end
    end

    if seen[-1] then return false end

    local deltas = {}
    for pose, rows in pairs(data.deltas) do
        local poseDeltas = {}
        for _, row in ipairs(rows) do
            local bone = BoneId(row[1])
            if bone and inSet[bone] then
                poseDeltas[#poseDeltas + 1] = {
                    bone, row[2], row[3], row[4], row[5], row[6], row[7], row[8],
                    string.find(row[1], "finger", 1, true) ~= nil,
                    string.find(row[1], "_l_finger_0", 1, true) ~= nil,
                }
            end
        end
        deltas[pose] = poseDeltas
    end

    local curves, fingers = {}, {}
    for i = 0, vm:GetSequenceCount() - 1 do
        local name = string.lower(vm:GetSequenceName(i) or "")
        if data.curves[name] then curves[i] = data.curves[name] end
        if data.fingers and data.fingers[name] then fingers[i] = data.fingers[name] end
    end

    local world, locals, solved, out = {}, {}, {}, {}
    for _, i in ipairs(list) do
        world[i], locals[i], solved[i], out[i] = {}, {}, {}, Matrix()
    end
    for _, parentId in ipairs(outside) do world[parentId] = {} end

    rig.list, rig.parent, rig.under, rig.outside, rig.deltas, rig.curves, rig.fingers = list, parent, under, outside, deltas, curves, fingers
    rig.W, rig.L, rig.N, rig.out = world, locals, solved, out
    rig.joint, rig.stretch = data.joint, data.stretch
    rig.fixed, rig.deferred = ArmBoneSets(rig, list, parent, under, inSet)

    return rig
end

function SWEP:GetGripPose(data)
    for _, id, def in self:IterAttachments() do
        if def.AnimSet == "foregrip" then return data.map[id], id, def end

        if def.GripBase and data.map[id] then
            local alt = data.map[id] .. "@" .. def.GripBase
            if data.deltas[alt] then return alt, id, def end
        end
    end
end

local function ApplyDelta(mat, delta, amount)
    DeltaRot(delta, amount)
    RotMul(mat, mat)
    mat[4], mat[8], mat[12] = mat[4] + delta[6] * amount, mat[8] + delta[7] * amount, mat[12] + delta[8] * amount
end

local function ApplyDeltas(locals, deltas, alpha, fingerAlpha, thumbAlpha)
    for _, delta in ipairs(deltas) do
        local amount = (delta[10] and thumbAlpha) or (delta[9] and fingerAlpha) or alpha
        if amount > 0 then ApplyDelta(locals[delta[1]], delta, amount) end
    end
end

local PickDeltas

local CopyBone = SandSwep.Math.CopyBone
local solveMat = Matrix()

local function Solve(vm, rig, deltas, alpha, fingerAlpha, thumbAlpha, unbase, aim, ctx)
    local list, parent, world, locals, solved = rig.list, rig.parent, rig.W, rig.L, rig.N

    for _, parentId in ipairs(rig.outside) do
        local mat = CopyBone(vm, parentId, solveMat)
        if not mat then return false end
        Read(world[parentId], mat)
    end
    for _, i in ipairs(list) do
        local mat = CopyBone(vm, i, solveMat)
        if not mat then return false end

        Read(world[i], mat)
        if not InvMul(locals[i], world[parent[i]], world[i]) then return false end
    end

    if ctx then deltas = PickDeltas(rig, locals[rig.ikw], ctx) end
    if alpha > 0 or thumbAlpha > 0 then ApplyDeltas(locals, deltas, alpha, fingerAlpha, thumbAlpha) end
    if unbase and aim > 0 then ApplyDeltas(locals, unbase, aim, aim, aim) end

    local under, fixed, deferred = rig.under, rig.fixed, rig.deferred
    for _, i in ipairs(list) do
        if not deferred[i] then
            local parentId = parent[i]
            Mul(solved[i], solved[parentId] or world[parentId], locals[i])
        end
    end

    local ikl, ikw = solved[rig.ikl], solved[rig.ikw]
    Copy(ikl, ikw)

    local upperMat, foreMat, handMat = solved[rig.upper], solved[rig.fore], solved[rig.hand]
    local rx, ry, rz = upperMat[4], upperMat[8], upperMat[12]
    local jx, jy, jz = foreMat[4], foreMat[8], foreMat[12]
    local tx, ty, tz = handMat[4], handMat[8], handMat[12]

    local joint = rig.joint
    local gx = foreMat[1] * joint[1] + foreMat[2] * joint[2] + foreMat[3] * joint[3] + jx
    local gy = foreMat[5] * joint[1] + foreMat[6] * joint[2] + foreMat[7] * joint[3] + jy
    local gz = foreMat[9] * joint[1] + foreMat[10] * joint[2] + foreMat[11] * joint[3] + jz

    local ojx, ojy, ojz, otx, oty, otz = SolveTwoBone(rx, ry, rz, jx, jy, jz, tx, ty, tz, gx, gy, gz,
        ikl[4], ikl[8], ikl[12], rig.stretch[1], rig.stretch[2])

    BetweenRot(jx - rx, jy - ry, jz - rz, ojx - rx, ojy - ry, ojz - rz)
    RotMul(upperMat, upperMat)
    BetweenRot(tx - jx, ty - jy, tz - jz, otx - ojx, oty - ojy, otz - ojz)
    RotMul(foreMat, foreMat)
    foreMat[4], foreMat[8], foreMat[12] = ojx, ojy, ojz
    Copy(handMat, ikl)
    handMat[4], handMat[8], handMat[12] = otx, oty, otz

    for _, i in ipairs(list) do
        if under[i] and not fixed[i] then Mul(solved[i], solved[parent[i]], locals[i]) end

        local mat = solved[i]
        rig.out[i]:SetUnpacked(mat[1], mat[2], mat[3], mat[4], mat[5], mat[6], mat[7], mat[8], mat[9], mat[10], mat[11], mat[12], 0, 0, 0, 1)
    end

    return true
end

local ORIG, NEW, NEW_POOL = {}, {}, {}
local thumbParentMat, thumbBoneMat = Matrix(), Matrix()

local function SolveThumb(vm, rig, deltas, thumbAlpha)
    local locals = rig.L
    rig.thumbs = rig.thumbs or {}

    local thumbs = rig.thumbs[deltas]
    if not thumbs then
        thumbs = {}
        for _, delta in ipairs(deltas) do
            if delta[10] then thumbs[#thumbs + 1] = delta end
        end
        table.sort(thumbs, function(x, y) return x[1] < y[1] end)
        rig.thumbs[deltas] = thumbs
    end

    for _, delta in ipairs(thumbs) do
        local bone = delta[1]
        local parent = rig.parent[bone]
        local parentMat, boneMat = CopyBone(vm, parent, thumbParentMat), CopyBone(vm, bone, thumbBoneMat)
        if not (parentMat and boneMat) then break end

        local parentOrig, boneOrig = ORIG[parent] or {}, ORIG[bone] or {}
        ORIG[parent], ORIG[bone] = parentOrig, boneOrig
        if not NEW[parent] then Read(parentOrig, parentMat) end
        Read(boneOrig, boneMat)
        if NEW[parent] then parentOrig = NEW[parent].orig end
        if not InvMul(locals[bone], parentOrig, boneOrig) then break end

        ApplyDelta(locals[bone], delta, thumbAlpha)

        local world = rig.W[bone]
        Mul(world, NEW[parent] and NEW[parent].w or parentOrig, locals[bone])

        local entry = NEW_POOL[bone]
        if not entry then
            entry = { orig = {} }
            NEW_POOL[bone] = entry
        end

        Copy(entry.orig, boneOrig)
        entry.w = world
        NEW[bone] = entry

        rig.out[bone]:SetUnpacked(world[1], world[2], world[3], world[4], world[5], world[6], world[7], world[8], world[9], world[10], world[11], world[12], 0, 0, 0, 1)
        vm:SetBoneMatrix(bone, rig.out[bone])
    end

    for k in pairs(NEW) do NEW[k] = nil end
end

local function ThumbWeight(cache, target)
    local now = RealTime()
    local weight, last = cache.tw, cache.twTime
    cache.twTime = now

    if not weight or not last then
        cache.tw, cache.twHold = target, nil
        return target
    end
    if abs(target - weight) < 1e-3 then
        cache.tw, cache.twHold = target, nil
        return target
    end

    local rising = target > weight
    if not cache.twHold then
        cache.twHold = now + (rising and THUMB_HOLD_IN or THUMB_HOLD)
    end
    if now >= cache.twHold then
        local step = (rising and THUMB_RATE_IN or THUMB_RATE) * (now - last)
        weight = target > weight and min(target, weight + step) or max(target, weight - step)
    end

    cache.tw = weight
    return weight
end

local function IdleBaseWeight(mat, ik)
    if not ik then return end

    local grip, back = ik.fg, ik.b
    local ax, ay, az = back[1] - grip[1], back[2] - grip[2], back[3] - grip[3]
    local lenSqr = ax * ax + ay * ay + az * az
    if lenSqr < 1e-4 then return end

    local px, py, pz = mat[4] - grip[1], mat[8] - grip[2], mat[12] - grip[3]
    local frac = (px * ax + py * ay + pz * az) / lenSqr
    local ox, oy, oz = px - ax * frac, py - ay * frac, pz - az * frac
    if frac < IDLE_RAIL_MIN or frac > IDLE_RAIL_MAX then return end
    if ox * ox + oy * oy + oz * oz > IDLE_RAIL_RADIUS_SQR then return end

    return Clamp01(frac)
end

local function BlendDeltas(rig, pose, baseDeltas, altDeltas, weight)
    rig.blend = rig.blend or {}

    local cache = rig.blend[pose]
    if not cache then
        local byBone, src = {}, {}
        for _, delta in ipairs(baseDeltas) do
            local entry = { delta[1], delta, nil, delta[9], delta[10] }
            byBone[delta[1]] = entry
            src[#src + 1] = entry
        end
        for _, delta in ipairs(altDeltas) do
            local entry = byBone[delta[1]]
            if entry then
                entry[3] = delta
            else
                src[#src + 1] = { delta[1], nil, delta, delta[9], delta[10] }
            end
        end

        local out = {}
        for i, entry in ipairs(src) do
            out[i] = { entry[1], 0, 0, 0, 1, 0, 0, 0, entry[4], entry[5] }
        end

        cache = { src = src, out = out }
        rig.blend[pose] = cache
    end

    local inv = 1 - weight
    for i, entry in ipairs(cache.src) do
        local fromDelta, toDelta, dst = entry[2], entry[3], cache.out[i]

        local ax, ay, az, aw = 0, 0, 0, 1
        local apx, apy, apz = 0, 0, 0
        if fromDelta then
            ax, ay, az, aw, apx, apy, apz = fromDelta[2], fromDelta[3], fromDelta[4], fromDelta[5], fromDelta[6], fromDelta[7], fromDelta[8]
        end

        local bx, by, bz, bw = 0, 0, 0, 1
        local bpx, bpy, bpz = 0, 0, 0
        if toDelta then
            bx, by, bz, bw, bpx, bpy, bpz = toDelta[2], toDelta[3], toDelta[4], toDelta[5], toDelta[6], toDelta[7], toDelta[8]
        end
        if ax * bx + ay * by + az * bz + aw * bw < 0 then bx, by, bz, bw = -bx, -by, -bz, -bw end

        local qx, qy, qz, qw = ax * inv + bx * weight, ay * inv + by * weight, az * inv + bz * weight, aw * inv + bw * weight
        local len = sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
        dst[2], dst[3], dst[4], dst[5] = qx / len, qy / len, qz / len, qw / len
        dst[6], dst[7], dst[8] = apx * inv + bpx * weight, apy * inv + bpy * weight, apz * inv + bpz * weight
    end

    return cache.out
end

PickDeltas = function(rig, mat, ctx)
    local weight = IdleBaseWeight(mat, ctx.ik)
    if not weight then weight = ctx.ib and 1 or 0 end

    if weight >= 1 then return ctx.alt end
    if weight > 0 then return BlendDeltas(rig, ctx.pose, ctx.base, ctx.alt, weight) end

    return ctx.base
end

local gfBase, gfInv, gfTmp = Matrix(), Matrix(), Matrix()

local function ReuseFrameCache(vm, frameCache)
    vm.SandSwepGripAlpha = frameCache.alpha
    gfBase:SetTranslation(vm:GetPos())
    gfBase:SetAngles(vm:GetAngles())

    for k = 1, frameCache.n do
        gfTmp:Set(gfBase)
        gfTmp:Mul(frameCache.loc[k])
        vm:SetBoneMatrix(frameCache.ids[k], gfTmp)
    end
end

local function StoreFrameCache(vm, rig, frame, seq, cycle, pose, model)
    local frameCache = vm.SandSwepGripFrame
    if not frameCache or not frameCache.loc then
        frameCache = { loc = {}, ids = {} }
        vm.SandSwepGripFrame = frameCache
    end

    gfInv:SetTranslation(vm:GetPos())
    gfInv:SetAngles(vm:GetAngles())
    gfInv:InvertTR()

    local out = rig.out
    local count = 0
    for _, i in ipairs(rig.list) do
        count = count + 1
        local mat = frameCache.loc[count]
        if not mat then
            mat = Matrix()
            frameCache.loc[count] = mat
        end
        mat:Set(gfInv)
        mat:Mul(out[i])
        frameCache.ids[count] = i
    end

    frameCache.n, frameCache.frame, frameCache.seq, frameCache.cycle = count, frame, seq, cycle
    frameCache.pose, frameCache.model, frameCache.alpha = pose, model, vm.SandSwepGripAlpha
end

local function GetRigCache(vm, model, data)
    local cache = vm.SandSwepGripRig
    if not cache or cache.model ~= model then
        cache = { model = model, rig = Prepare(vm, data) }
        vm.SandSwepGripRig = cache
    end

    return cache
end

local function IdleBaseContext(vm, rig, data, pose, deltas, seq)
    local alt = data.idlebase and rig.deltas[pose .. "@idle"]
    if not alt then return nil, deltas end

    rig.idleBase = rig.idleBase or {}

    local idleBase = rig.idleBase[seq]
    if idleBase == nil then
        idleBase = data.idlebase[string.lower(vm:GetSequenceName(seq) or "")] or false
        rig.idleBase[seq] = idleBase
    end

    local ctx = rig.pickCtx or {}
    rig.pickCtx = ctx
    ctx.alt, ctx.ik, ctx.ib, ctx.pose, ctx.base = alt, data.idleik, idleBase, pose, deltas

    return ctx, idleBase and alt or deltas
end

local function ReloadRelease(vm, rig, seq, cycle, release)
    rig.isReload = rig.isReload or {}

    local isReload = rig.isReload[seq]
    if isReload == nil then
        isReload = string.find(string.lower(vm:GetSequenceName(seq) or ""), "reload", 1, true) ~= nil
        rig.isReload[seq] = isReload
    end
    if not isReload then return 0 end

    local progress = Clamp01(cycle * vm:SequenceDuration(seq) / release)
    return 1 - progress * progress * (3 - 2 * progress)
end

local function GripWeights(wep, vm, rig, data, gripId, gripDef, seq, cycle)
    local keys = rig.curves[seq]
    local hold = Clamp01(1 - (keys and EvalCurve(keys, cycle) or 0))
    local alpha = hold

    local release = gripDef and gripDef.GripReloadRelease
    if release and keys and alpha < 1 then
        alpha = max(alpha, ReloadRelease(vm, rig, seq, cycle, release))
    end

    local unbase = data.noads and data.noads[gripId] and rig.deltas._unbase
    local aim = unbase and Clamp01(wep:GetAimProgress()) * hold or 0
    alpha = alpha * (1 - aim)
    if gripDef and gripDef.GripWeight then alpha = alpha * gripDef.GripWeight end

    local fingerKeys = rig.fingers[seq]
    local fingerAlpha = fingerKeys and alpha * EvalCurve(fingerKeys, cycle) or alpha
    if gripDef and gripDef.GripFingerWeight then
        fingerAlpha = fingerAlpha * gripDef.GripFingerWeight
    end

    return alpha, fingerAlpha, aim, unbase
end

function SWEP:VMGrip(vm)
    vm.SandSwepGripAlpha = nil

    local model = vm:GetModel()
    local data = model and SandSwep.GripData[string.lower(model)]
    if not data then return end

    local pose, gripId, gripDef = self:GetGripPose(data)
    if not pose then return end

    local frame, seq, cycle = FrameNumber(), vm:GetSequence(), vm:GetCycle()
    local frameCache = vm.SandSwepGripFrame
    local reuse = frameCache and frameCache.loc and frameCache.frame == frame
        and frameCache.seq == seq and frameCache.cycle == cycle
        and frameCache.pose == pose and frameCache.model == model

    if reuse then
        ReuseFrameCache(vm, frameCache)
        return
    end

    local cache = GetRigCache(vm, model, data)
    local rig = cache.rig
    local deltas = rig and rig.deltas[pose]
    if not deltas then return end

    local ctx
    ctx, deltas = IdleBaseContext(vm, rig, data, pose, deltas, seq)

    local alpha, fingerAlpha, aim, unbase = GripWeights(self, vm, rig, data, gripId, gripDef, seq, cycle)
    vm.SandSwepGripAlpha = alpha

    local thumbAlpha = ThumbWeight(cache, fingerAlpha)
    if alpha <= 0 and aim <= 0 then
        if thumbAlpha > 0 then SolveThumb(vm, rig, deltas, thumbAlpha) end
        return
    end

    if not Solve(vm, rig, deltas, alpha, fingerAlpha, thumbAlpha, unbase, aim, ctx) then return end

    local out = rig.out
    for _, i in ipairs(rig.list) do vm:SetBoneMatrix(i, out[i]) end

    StoreFrameCache(vm, rig, frame, seq, cycle, pose, model)
end
