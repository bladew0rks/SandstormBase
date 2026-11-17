local VisualFrameTime = SandSwep.VisualFrameTime

if not CLIENT then return end

local cvShellLife = GetConVar("cl_sandswep_shell_life")

local CM = 0.393700787
local EJECT_VM_TIME = 0.2
local FADE_TIME = 3

local ATTACHED_GRAVITY = Vector(0, 0, -386)
local ATTACHED_STEP = 1 / 120
local MAX_DROPPED = 6
local DROP_STEP = 1 / 60
local DROP_GRAVITY = Vector(0, 0, -600)

local view = SandSwep.VMView
local models = {}
local dropped = {}

local function LinkModel(model)
    local ent = models[model]

    if not IsValid(ent) then
        util.PrecacheModel(model)
        ent = ClientsideModel(model, RENDERGROUP_OPAQUE)
        if not IsValid(ent) then return end

        ent:SetNoDraw(true)
        models[model] = ent
    end

    return ent
end

local function ClosestOnSegment(point, segStart, segEnd)
    local seg = segEnd - segStart
    local lenSqr = seg:LengthSqr()
    if lenSqr < 1e-6 then return segStart end

    return segStart + seg * math.Clamp((point - segStart):Dot(seg) / lenSqr, 0, 1)
end

local function RelaxPairs(nodes, gap, rest, compressOnly, pinFirst)
    for i = 1, #nodes - gap do
        local nodeA, nodeB = nodes[i], nodes[i + gap]
        local delta = nodeB.p - nodeA.p
        local len = delta:Length()

        if len > 1e-4 and (not compressOnly or len < rest) then
            local diff = (len - rest) / len
            if pinFirst and i == 1 then
                nodeB.p = nodeB.p - delta * diff
            else
                nodeA.p = nodeA.p + delta * (diff * 0.5)
                nodeB.p = nodeB.p - delta * (diff * 0.5)
            end
        end
    end
end

local BOX_FACES = {
    { "x", 1, -1 },
    { "x", 2, 1 },
    { "y", 1, -1 },
    { "y", 2, 1 },
    { "z", 1, -1 },
    { "z", 2, 1 },
}

local function PushOutOfBoxes(node, frame, toLocal, boxes, radius)
    local localPos = toLocal * node.p
    local moved = false

    for _, box in ipairs(boxes) do
        local mins, maxs = box[1] * CM, box[2] * CM
        local inside = localPos.x > mins.x - radius and localPos.x < maxs.x + radius
            and localPos.y > mins.y - radius and localPos.y < maxs.y + radius
            and localPos.z > mins.z - radius and localPos.z < maxs.z + radius

        if inside then
            local best, axis, value = math.huge
            for _, face in ipairs(BOX_FACES) do
                local bound = (face[2] == 1 and mins or maxs)[face[1]] + face[3] * radius
                local dist = math.abs(localPos[face[1]] - bound)
                if dist < best then best, axis, value = dist, face[1], bound end
            end

            localPos[axis] = value
            moved = true
        end
    end

    if moved then node.p = frame.m * localPos end
end

local function PushOutOfCapsules(node, capsules)
    for _, cap in ipairs(capsules) do
        local closest = ClosestOnSegment(node.p, cap[1], cap[2])
        local away = node.p - closest
        local len = away:Length()

        if len < cap[3] then
            if len < 1e-4 then
                away = Vector(0, 0, 1)
                len = 1
            end
            node.p = closest + away * (cap[3] / len)
        end
    end
end

local function AvoidCapsules(cfg, vm, radius)
    local capsules = {}

    for _, spec in ipairs(cfg.AvoidBones or {}) do
        local boneA = SandSwep.BoneId(vm, spec[1])
        local matA = boneA and vm:GetBoneMatrix(boneA)

        if matA then
            local boneB = spec[2] and SandSwep.BoneId(vm, spec[2])
            local matB = boneB and vm:GetBoneMatrix(boneB)
            capsules[#capsules + 1] = {
                matA:GetTranslation(),
                matB and matB:GetTranslation() or matA:GetTranslation(),
                (spec[3] or 3) * CM + radius,
            }
        end
    end

    return capsules
end

local function SolveAttached(sim, cfg, frame, toLocal, capsules, pin, dir, pitch)
    local nodes = sim.nodes
    local radius = (cfg.Radius or 0.8) * CM
    local boxes = cfg.Avoid or {}
    local bend = (cfg.Stiffness or 1.6) * pitch

    for _ = 1, 6 do
        nodes[1].p = pin
        if #nodes >= 2 then
            nodes[2].p = LerpVector(0.35, nodes[2].p, pin + dir * pitch)
        end

        RelaxPairs(nodes, 1, pitch, false, true)
        RelaxPairs(nodes, 2, bend, true, true)

        for i = 2, #nodes do
            if boxes[1] then PushOutOfBoxes(nodes[i], frame, toLocal, boxes, radius) end
            PushOutOfCapsules(nodes[i], capsules)
        end
    end
end

local function DropBelt(wep, cfg, nodes, info, push, side)
    if #nodes == 0 then return end

    local owner = wep:GetOwner()
    local ownerVel = IsValid(owner) and owner:GetVelocity() or Vector(0, 0, 0)

    local out = {}
    for i, node in ipairs(nodes) do
        local worldPos = view.ToWorld(node.p, info)
        local step = (view.ToWorld(node.p + (node.p - node.o) * (DROP_STEP / ATTACHED_STEP), info) - worldPos)
            + (push + ownerVel + VectorRand() * 15) * DROP_STEP
        out[i] = { p = worldPos, o = worldPos - step }
    end

    local spacing = (cfg.Pitch or 2.1) * CM
    dropped[#dropped + 1] = {
        mdl = cfg.Model,
        nodes = out,
        spacing = spacing,
        bend = (cfg.Stiffness or 1.6) * 0.85 * spacing,
        side = side,
        born = CurTime(),
        vmStage = true,
        sounds = cfg.Sounds,
        sndPitch = cfg.SoundPitch,
        clinks = 0,
        calm = 0,
        asleep = false,
    }

    while #dropped > MAX_DROPPED do table.remove(dropped, 1) end
end

local dropOut = {}
local dropIn = { output = dropOut, mask = MASK_SOLID }

local function PlayClink(belt, pos, speed)
    if speed <= 60 or belt.clinks >= 4 then return end
    if not belt.sounds or #belt.sounds == 0 then return end

    belt.clinks = belt.clinks + 1

    local pmin, pmax = 120, 140
    if belt.sndPitch then pmin, pmax = belt.sndPitch[1], belt.sndPitch[2] end

    sound.Play(belt.sounds[math.random(#belt.sounds)], pos, 60, math.random(pmin, pmax), math.Clamp(speed / 300, 0.15, 0.5))
end

local function StepDropped(belt, ply)
    local nodes = belt.nodes
    local gravity = DROP_GRAVITY * (DROP_STEP * DROP_STEP)

    for _, node in ipairs(nodes) do
        local vel = (node.p - node.o) * (node.ground and 0.6 or 0.995)
        node.o = node.p
        node.p = node.p + vel + gravity
    end

    for _ = 1, 4 do
        RelaxPairs(nodes, 1, belt.spacing, false, false)
        RelaxPairs(nodes, 2, belt.bend, true, false)
    end

    local moving = 0
    for _, node in ipairs(nodes) do
        dropIn.start, dropIn.endpos, dropIn.filter = node.o, node.p, ply
        util.TraceLine(dropIn)
        node.ground = false

        if dropOut.Hit and not dropOut.StartSolid then
            local normal = dropOut.HitNormal
            local speed = (node.p - node.o):Length() / DROP_STEP
            node.p = dropOut.HitPos + normal * 0.3
            node.ground = normal.z > 0.5
            PlayClink(belt, node.p, speed)
        elseif dropOut.StartSolid then
            node.p = node.o
        end

        moving = math.max(moving, (node.p - node.o):LengthSqr())
    end

    return moving
end

local function DrawLinks(belt, ent, toPos, scale)
    local scaleMatrix = Matrix()
    scaleMatrix:Scale(Vector(scale, scale, scale))
    ent:EnableMatrix("RenderMultiply", scaleMatrix)

    local nodes = belt.nodes
    local count = #nodes
    for i = 1, count do
        local tangent = nodes[math.min(i + 1, count)].p - nodes[math.max(i - 1, 1)].p
        if tangent:LengthSqr() < 1e-6 then tangent = Vector(1, 0, 0) end
        tangent:Normalize()

        local linkFwd = belt.side - tangent * belt.side:Dot(tangent)
        if linkFwd:LengthSqr() < 1e-4 then linkFwd = Vector(0, 0, 1) - tangent * tangent.z end
        linkFwd:Normalize()

        local linkUp = linkFwd:Cross(tangent)
        linkUp:Normalize()

        ent:SetPos(toPos(nodes[i].p))
        ent:SetAngles(linkFwd:AngleEx(linkUp))
        ent:SetupBones()
        ent:DrawModel()
    end

    ent:DisableMatrix("RenderMultiply")
end

hook.Add("Think", "SandSwep_DroppedBelts", function()
    if #dropped == 0 then return end

    local ct = CurTime()
    local life = cvShellLife:GetFloat()
    local ply = LocalPlayer()
    local dt = math.min(VisualFrameTime(), 0.1)

    for i = #dropped, 1, -1 do
        local belt = dropped[i]

        if ct - belt.born > life + FADE_TIME then
            table.remove(dropped, i)
        elseif not belt.asleep then
            belt.acc = (belt.acc or 0) + dt

            local steps = 0
            while belt.acc >= DROP_STEP and steps < 6 do
                belt.acc = belt.acc - DROP_STEP
                steps = steps + 1

                if StepDropped(belt, ply) < 0.0004 then
                    belt.calm = belt.calm + DROP_STEP
                else
                    belt.calm = 0
                end
            end

            if belt.calm > 0.5 or ct - belt.born > 6 then belt.asleep = true end
        end
    end
end)

local function Identity(pos)
    return pos
end

hook.Add("PostDrawOpaqueRenderables", "SandSwep_DroppedBelts", function(depth, sky)
    if depth or sky or #dropped == 0 then return end

    local ct = CurTime()
    local life = cvShellLife:GetFloat()

    for _, belt in ipairs(dropped) do
        if not belt.vmStage or ct - belt.born > EJECT_VM_TIME + 0.1 then
            belt.vmStage = false

            local ent = LinkModel(belt.mdl)
            if IsValid(ent) then
                local fading = ct - belt.born > life
                if fading then
                    ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
                    ent:SetColor(Color(255, 255, 255, (1 - math.Clamp((ct - belt.born - life) / FADE_TIME, 0, 1)) * 255))
                end

                DrawLinks(belt, ent, Identity, 1)

                if fading then
                    ent:SetColor(Color(255, 255, 255, 255))
                    ent:SetRenderMode(RENDERMODE_NORMAL)
                end
            end
        end
    end
end)

local function DrawYoungBelts(info)
    local ct = CurTime()

    for _, belt in ipairs(dropped) do
        if belt.vmStage then
            local age = ct - belt.born
            if age >= EJECT_VM_TIME then
                belt.vmStage = false
            else
                local ent = LinkModel(belt.mdl)
                if IsValid(ent) then
                    local scale = Lerp(math.Clamp(age / EJECT_VM_TIME, 0, 1), 1, 1 / info.k)
                    DrawLinks(belt, ent, function(pos) return view.ToVM(pos, info) end, scale)
                end
            end
        end
    end
end

local collideOut = {}
local collideIn = { output = collideOut, mask = MASK_SOLID }

local function CollideAttached(sim, cfg, info, ply)
    if cfg.Collide == false then return end

    local nodes = sim.nodes
    local radius = (cfg.Radius or 0.8) * CM * (info.k or 1)
    collideIn.filter = ply

    for i = 2, #nodes do
        local node = nodes[i]
        local worldNew = view.ToWorld(node.p, info)
        local worldOld = node.w or worldNew
        if worldOld:DistToSqr(worldNew) > 60 * 60 then worldOld = worldNew end

        collideIn.start, collideIn.endpos = worldOld, worldNew
        util.TraceLine(collideIn)

        if collideOut.Hit and not collideOut.StartSolid then
            local hit = collideOut.HitPos + collideOut.HitNormal * radius
            local vel = node.p - node.o
            node.p = view.ToVM(hit, info)

            local normal = collideOut.HitNormal
            node.o = node.p - (vel - normal * vel:Dot(normal)) * 0.3
            node.w = hit
        elseif collideOut.StartSolid and node.w then
            node.p = view.ToVM(node.w, info)
            node.o = node.p
        else
            node.w = worldNew
        end
    end
end

local function FollowGun(sim, frame, inertia, snap)
    if sim.lastM then
        local carry = frame.m * sim.lastM:GetInverseTR()
        local follow = snap and 1 or 1 - math.Clamp(inertia, 0, 1)

        if follow > 0 then
            for _, node in ipairs(sim.nodes) do
                node.p = LerpVector(follow, node.p, carry * node.p)
                node.o = LerpVector(follow, node.o, carry * node.o)
            end
        end
    end

    sim.lastM = sim.lastM or Matrix()
    sim.lastM:Set(frame.m)
end

local function Integrate(sim, cfg, frame, vm, pin, dir, pitch)
    local nodes = sim.nodes
    sim.acc = (sim.acc or 0) + math.min(VisualFrameTime(), 1 / 20)

    local damping = cfg.Damping or 0.97
    local gravity = ATTACHED_GRAVITY * (ATTACHED_STEP * ATTACHED_STEP)
    local maxStep = (cfg.MaxSpeed or 60) * ATTACHED_STEP
    local toLocal, capsules

    local steps = 0
    while sim.acc >= ATTACHED_STEP and steps < 8 do
        if not toLocal then
            toLocal = frame.m:GetInverseTR()
            capsules = AvoidCapsules(cfg, vm, (cfg.Radius or 0.8) * CM)
        end
        sim.acc = sim.acc - ATTACHED_STEP
        steps = steps + 1

        for i = 2, #nodes do
            local node = nodes[i]
            local vel = (node.p - node.o) * damping
            local speed = vel:Length()
            if speed > maxStep then vel = vel * (maxStep / speed) end

            node.o = node.p
            node.p = node.p + vel + gravity
        end

        SolveAttached(sim, cfg, frame, toLocal, capsules, pin, dir, pitch)
    end

    if steps == 0 then nodes[1].p = pin end
end

local function DropMoment(wep)
    local entry = wep:GetCurrentReloadEntry()
    return istable(entry) and (entry.BeltDropAt or (istable(entry.Cover) and entry.Cover[2]) or entry.MagOut)
end

local function DrawHangingBelt(wep, vm, info)
    local cfg = wep.HangingBelt
    if not isstring(cfg.Model) then return end

    local sim = wep._beltSim
    if not sim then
        sim = { nodes = {}, shiftT = 0 }
        wep._beltSim = sim
    end

    local feeds = wep._beltFeeds or 0
    wep._beltFeeds = 0

    if wep:IsMagHidden() then
        sim.nodes = {}
        return
    end

    local frame = view.GunFrame(vm, info)
    if not frame then return end

    local nodes = sim.nodes
    local pitch = (cfg.Pitch or 2.1) * CM

    local cfgDir = cfg.Dir or Vector(1, 0, 0)
    local dir = frame.R * -cfgDir.x + frame.F * -cfgDir.y + frame.U * cfgDir.z
    dir:Normalize()

    local exit = frame.m * ((cfg.Exit or Vector(0, 0, 0)) * CM)
    local dropVel = cfg.DropVelocity or Vector(0, -30, 0)
    local push = frame.F * dropVel.x + frame.R * dropVel.y + frame.U * dropVel.z

    if wep:IsReloading() and #nodes > 0 then
        local dropAt = DropMoment(wep)
        if dropAt and wep:GetReloadAnimTime() >= dropAt then
            DropBelt(wep, cfg, nodes, info, push, frame.F)
            sim.nodes = {}
            return
        end
    end
    if wep:IsReloading() and #nodes == 0 then feeds = 0 end

    FollowGun(sim, frame, cfg.Inertia or 0.15, sim.lastExit and sim.lastExit:DistToSqr(exit) > 40 * 40)
    sim.lastExit = exit

    for _ = 1, feeds do
        local linkPos = exit - dir * pitch
        table.insert(nodes, 1, { p = linkPos, o = linkPos })
        sim.shiftT = CurTime()

        local kick = cfg.ShotKick or 0.35
        for i = 2, #nodes do
            local node = nodes[i]
            node.o = node.o - (dir * 0.5 + VectorRand() * 0.5) * kick * math.Rand(0.3, 1)
        end
    end

    while #nodes > (cfg.MaxLinks or 16) do table.remove(nodes) end
    if #nodes == 0 then return end

    if wep:Clip1() <= 0 and not wep:IsReloading() then
        DropBelt(wep, cfg, nodes, info, push, frame.F)
        sim.nodes = {}
        return
    end

    local shift = math.Clamp((CurTime() - sim.shiftT) / math.max(cfg.ShiftTime or 0.08, 0.001), 0, 1)
    local pin = exit - dir * pitch * (1 - shift)
    Integrate(sim, cfg, frame, vm, pin, dir, pitch)
    CollideAttached(sim, cfg, info, LocalPlayer())

    local ent = LinkModel(cfg.Model)
    if not IsValid(ent) then return end

    local fwd = frame.F
    local count = #nodes
    for i = 1, count do
        local tangent = (count > 1) and (nodes[math.min(i + 1, count)].p - nodes[math.max(i - 1, 1)].p) or dir
        if tangent:LengthSqr() < 1e-6 then tangent = dir end
        tangent:Normalize()

        local linkFwd = fwd - tangent * fwd:Dot(tangent)
        linkFwd:Normalize()

        local linkUp = linkFwd:Cross(tangent)
        linkUp:Normalize()

        ent:SetPos(nodes[i].p)
        ent:SetAngles(linkFwd:AngleEx(linkUp))
        ent:SetupBones()
        ent:DrawModel()
    end
end

local function LiveBasis(cfg)
    local basis = cfg._basis
    if basis then return basis end

    local tangent = (cfg.Dir or Vector(1, 0, 0)):GetNormalized()
    local axis = cfg.Axis or Vector(0, -1, 0)

    local across = axis - tangent * axis:Dot(tangent)
    across:Normalize()
    local normal = across:Cross(tangent)

    basis = {
        x = Vector(across.x, tangent.x, normal.x),
        z = Vector(across.z, tangent.z, normal.z),
    }
    cfg._basis = basis

    return basis
end

local function LiveFeedDir(cfg, vm, frame, start, boneAng)
    local bone2 = SandSwep.BoneId(vm, "b_wpn_mag_b2")
    local mat2 = bone2 and vm:GetBoneMatrix(bone2)

    local dir
    if mat2 then dir = mat2:GetTranslation() - start end
    if not dir or dir:LengthSqr() < 1e-4 then
        dir = LocalToWorld(cfg.Dir or Vector(1, 0, 0), angle_zero, vector_origin, boneAng)
    end
    dir:Normalize()

    if cfg.Side then
        local right = frame.R
        if dir:Dot(right * -cfg.Side.x) < 0 then
            dir = dir - right * (2 * dir:Dot(right))
            dir:Normalize()
        end
    end

    return dir
end

local DOWN = Vector(0, 0, -1)

local function DrawLiveBelt(wep, vm, info)
    local cfg = wep:GetLiveBelt()
    if not cfg or not isstring(cfg.Model) then
        wep._liveSim = nil
        return
    end

    local sim = wep._liveSim
    if not sim then
        sim = { nodes = {}, shiftT = 0 }
        wep._liveSim = sim
    end

    local rounds = wep:GetLiveBeltRounds()
    local bone1 = SandSwep.BoneId(vm, "b_wpn_mag_b1")
    local mat1 = bone1 and vm:GetBoneMatrix(bone1)
    local frame = view.GunFrame(vm, info)

    if not mat1 or not frame or rounds <= 0 then
        sim.nodes = {}
        sim.lastN = rounds
        sim.lastM = nil
        return
    end

    local pitch = (cfg.Pitch or 1.3) * CM
    local start = mat1:GetTranslation()
    local boneAng = mat1:GetAngles()
    local dir = LiveFeedDir(cfg, vm, frame, start, boneAng)

    local axis = LocalToWorld(cfg.Axis or Vector(0, -1, 0), angle_zero, vector_origin, boneAng)
    axis:Normalize()

    local nodes = sim.nodes
    local last = sim.lastN
    if last and rounds > last + 1 then
        nodes = {}
        sim.nodes = nodes
    elseif last and rounds < last and #nodes > 0 then
        for _ = 1, math.min(last - rounds, 8) do table.remove(nodes, 1) end
        sim.shiftT = CurTime()
    end
    sim.lastN = rounds

    if nodes[1] and nodes[1].p:DistToSqr(start) > 40 * 40 then
        nodes = {}
        sim.nodes = nodes
    end

    FollowGun(sim, frame, cfg.Inertia or 0.2, false)

    local want = math.min(rounds, cfg.MaxLinks or 30)
    while #nodes > want do table.remove(nodes) end
    while #nodes < want do
        local count = #nodes
        local linkPos
        if count == 0 then
            linkPos = start
        elseif count == 1 then
            linkPos = nodes[1].p + dir * pitch
        else
            local prev = (nodes[count].p - nodes[count - 1].p):GetNormalized()
            linkPos = nodes[count].p + (prev + DOWN):GetNormalized() * pitch
        end
        nodes[count + 1] = { p = linkPos, o = linkPos }
    end
    if #nodes == 0 then return end

    local shift = math.Clamp((CurTime() - sim.shiftT) / math.max(cfg.ShiftTime or 0.05, 0.001), 0, 1)
    local pin = start + dir * pitch * (1 - shift)
    Integrate(sim, cfg, frame, vm, pin, dir, pitch)
    CollideAttached(sim, cfg, info, LocalPlayer())

    local ent = LinkModel(cfg.Model)
    if not IsValid(ent) then return end

    local basis = LiveBasis(cfg)
    local count = #nodes
    for i = 1, count do
        local tangent
        if i == 1 then
            tangent = dir
        else
            local nextPos = i == count and nodes[i].p or nodes[math.min(i + 1, count)].p
            tangent = nextPos - nodes[i - 1].p
            if tangent:LengthSqr() < 1e-6 then tangent = dir end
            tangent:Normalize()
        end

        local across = axis - tangent * axis:Dot(tangent)
        if across:LengthSqr() < 1e-6 then across = frame.F - tangent * frame.F:Dot(tangent) end
        across:Normalize()
        local normal = across:Cross(tangent)

        local linkFwd = across * basis.x.x + tangent * basis.x.y + normal * basis.x.z
        local linkUp = across * basis.z.x + tangent * basis.z.y + normal * basis.z.z

        ent:SetPos(nodes[i].p)
        ent:SetAngles(linkFwd:AngleEx(linkUp))
        ent:SetupBones()
        ent:DrawModel()
    end
end

function SandSwep.DrawViewmodelBelts(wep, vm, info)
    if IsValid(wep) and istable(wep.HangingBelt) then DrawHangingBelt(wep, vm, info) end
    if IsValid(wep) and istable(wep.LiveBelt) then DrawLiveBelt(wep, vm, info) end
    DrawYoungBelts(info)
end
