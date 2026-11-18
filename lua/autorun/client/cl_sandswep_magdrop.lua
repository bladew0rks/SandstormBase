SandSwep = SandSwep or {}

local cvDrop = CreateClientConVar("cl_sandswep_magdrop", "1", true, false, "Quick reloads drop the mag", 0, 1)
local cvLife = CreateClientConVar("cl_sandswep_magdrop_life", "30", true, false, "Dropped mag lifetime (s)", 1, 300)

local MAX_MAGS = 24
local FADE = 2
local JUMP_SPEED = 350
local RELEASE_DIST = 0.5
local LOW_DROP = 4
local LOW_RISE = 1
local MAX_FALL = 300
local RELOAD_QUICK = 2

local SETS = {
    lmg_cloth = 8, lmg_metal = 8, lmg_polymer = 8,
    rifle_metal = 12, rifle_polymer = 12,
    sidearm_metal = 9, smg_metal = 11, smg_polymer = 11,
}
local SURFACES = { "carpet", "dirt", "grass", "gravel", "metalvent", "mud", "sand", "snow", "solidmetal", "water", "wood" }

local function AddSet(name, file, count, volume)
    local paths = {}
    for i = 1, count do
        paths[i] = string.format("sandstorm/shared/magdrop/%s_%02d.ogg", file, i)
        util.PrecacheSound(paths[i])
    end

    sound.Add({
        name = name,
        channel = CHAN_STATIC,
        volume = volume,
        level = 70,
        pitch = { 96, 104 },
        sound = paths,
    })
end
for set, count in pairs(SETS) do AddSet("SandSwep.MagDrop." .. set, set, count, 0.8) end
for _, surf in ipairs(SURFACES) do AddSet("SandSwep.MagDrop.surface_" .. surf, "surface_" .. surf, 6, 0.63) end

local MAT_SURFACE = {
    [MAT_DIRT] = "dirt", [MAT_GRASS] = "grass", [MAT_FOLIAGE] = "grass", [MAT_SAND] = "sand",
    [MAT_SNOW] = "snow", [MAT_WOOD] = "wood", [MAT_METAL] = "solidmetal", [MAT_GRATE] = "metalvent",
    [MAT_VENT] = "metalvent", [MAT_SLOSH] = "mud", [MAT_CONCRETE] = "gravel", [MAT_TILE] = "gravel",
    [MAT_PLASTIC] = "carpet", [MAT_COMPUTER] = "solidmetal",
}

local mags = {}
local ZERO = Vector(0, 0, 0)

local function RoundMatrix(entry)
    local x, y, z, w = entry[5], entry[6], entry[7], entry[8]
    local mat = Matrix({
        { 1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), entry[2] },
        { 2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), entry[3] },
        { 2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y), entry[4] },
        { 0, 0, 0, 1 },
    })

    entry.m = mat
    return mat
end

local shown, shownStamp = {}, 0
local roundTmp, hiddenTmp = Matrix(), Matrix()

function SandSwep.PoseMagRounds(ent, data, spent)
    local magId = SandSwep.BoneId(ent, "b_wpn_mag")
    local mag = magId and ent:GetBoneMatrix(magId)
    if not mag then return end

    local ids = ent.SandSwepRoundIds
    if not ids or ids.data ~= data or ids.model ~= ent:GetModel() then
        ids = { data = data, model = ent:GetModel() }
        for i, name in ipairs(data.Bones) do
            ids[i] = ent:LookupBone(name) or false
        end
        ent.SandSwepRoundIds = ids
    end

    shownStamp = shownStamp + 1
    for _, entry in ipairs(data.States[spent + 1]) do
        local id = ids[entry[1]]
        if id then
            roundTmp:Set(mag)
            roundTmp:Mul(entry.m or RoundMatrix(entry))
            ent:SetBoneMatrix(id, roundTmp)
            shown[entry[1]] = shownStamp
        end
    end

    local hidden
    for i, id in ipairs(ids) do
        if id and shown[i] ~= shownStamp then
            if not hidden then
                hidden = hiddenTmp
                hidden:Set(mag)
                hidden:SetScale(ZERO)
            end
            ent:SetBoneMatrix(id, hidden)
        end
    end
end

function SandSwep.MagPropRounds(wep)
    local spec = wep.MagRounds
    if not spec or not SandSwep.MagRoundData or not wep.GetRoundsInMag then return end

    local groups = wep.GetDesiredBodygroups and wep:GetDesiredBodygroups() or {}
    local data = SandSwep.MagRoundData[spec[groups.mag or groups.Mag or 0] or ""]
    if not data then return end

    return {
        data = data,
        k = math.Clamp(wep:GetMagSize() - wep:GetRoundsInMag(), 0, #data.States - 1),
    }
end

local function RemoveMag(i)
    local mag = mags[i]
    if mag and IsValid(mag.ent) then mag.ent:Remove() end

    table.remove(mags, i)
end

local extraProps = SandSwep.MagPropsExtra or {}
SandSwep.MagPropsExtra = extraProps
function SandSwep.RegisterMagProps(viewModel, row)
    extraProps[string.lower(viewModel)] = row
end

local warmed = {}
function SandSwep.WarmModel(model, physics)
    if not isstring(model) or model == "" or warmed[model] then return end
    warmed[model] = true

    util.PrecacheModel(model)
    local ent = physics and ents.CreateClientProp(model) or ClientsideModel(model, RENDERGROUP_OPAQUE)
    if not IsValid(ent) then return end

    ent:SetNoDraw(true)
    ent:SetPos(EyePos())
    if physics then ent:Spawn() end

    render.SetBlend(0)
    ent:DrawModel()
    render.SetBlend(1)

    timer.Simple(0, function()
        if IsValid(ent) then ent:Remove() end
    end)
end

function SandSwep.PrecacheMagProps(wep)
    local vm = string.lower(wep.ViewModel or "")
    local row = (SandSwep.MagProps and SandSwep.MagProps[vm]) or extraProps[vm]

    for _, entry in pairs(row or {}) do
        SandSwep.WarmModel(entry[1], true)
    end
end

function SandSwep.MagPropFor(wep)
    local vm = string.lower(wep.ViewModel or "")
    local row = (SandSwep.MagProps and SandSwep.MagProps[vm]) or extraProps[vm]
    if not row then return end

    local groups = wep.GetDesiredBodygroups and wep:GetDesiredBodygroups() or {}
    local entry = row[groups.mag or groups.Mag or 0]
    if entry then return entry[1], entry[2] end
end

function SandSwep.SpawnMagProp(model, snd, pos, ang, vel, angvel, rounds)
    if not cvDrop:GetBool() or not model then return end

    util.PrecacheModel(model)
    local ent = ents.CreateClientProp(model)
    if not IsValid(ent) then return end

    ent:SetPos(pos)
    ent:SetAngles(ang)
    ent:Spawn()
    ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

    if rounds then
        ent:AddCallback("BuildBonePositions", function(prop)
            SandSwep.PoseMagRounds(prop, rounds.data, rounds.k)
        end)
    end

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetVelocity(vel)
        phys:AddAngleVelocity(angvel or VectorRand() * 200)
    end

    mags[#mags + 1] = {
        ent = ent,
        born = CurTime(),
        snd = snd,
        lastVel = vel,
        nextSound = CurTime() + 0.05,
        hits = 0,
    }
    while #mags > MAX_MAGS do RemoveMag(1) end

    return ent
end

local function ImpactSound(mag, strength)
    local ent = mag.ent
    local vol = math.Clamp(strength / 250, 0.2, 1) * (mag.hits == 0 and 1 or 0.6)
    ent:EmitSound("SandSwep.MagDrop." .. (mag.snd or "rifle_metal"), 70, math.random(96, 104), vol)

    local pos = ent:GetPos()
    local tr = SandSwep.TraceLine(pos + Vector(0, 0, 4), pos - Vector(0, 0, 12), ent, MASK_SOLID)
    local surf = tr.Hit and MAT_SURFACE[tr.MatType]
    if bit.band(util.PointContents(pos), CONTENTS_WATER) ~= 0 then
        surf = "water"
    end

    if surf then ent:EmitSound("SandSwep.MagDrop.surface_" .. surf, 65, math.random(96, 104), vol) end
end

hook.Add("Think", "SandSwep_MagDropProps", function()
    local now = CurTime()
    local life = cvLife:GetFloat()

    for i = #mags, 1, -1 do
        local mag = mags[i]
        local ent = mag.ent
        if not IsValid(ent) then
            table.remove(mags, i)
            continue
        end

        local age = now - mag.born
        if age > life + FADE then
            RemoveMag(i)
            continue
        end

        if age > life then
            ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
            ent:SetColor(Color(255, 255, 255, 255 * (1 - (age - life) / FADE)))
        end

        local phys = ent:GetPhysicsObject()
        if not IsValid(phys) or mag.hits >= 4 then continue end

        local vel = phys:GetVelocity()
        local impact = (vel - mag.lastVel):Length()
        if impact > 70 and now >= mag.nextSound then
            ImpactSound(mag, impact)
            mag.hits = mag.hits + 1
            mag.nextSound = now + 0.12
        end
        mag.lastVel = vel
    end
end)

concommand.Add("sandswep_clearmags", function()
    for i = #mags, 1, -1 do RemoveMag(i) end
end)

function SandSwep.MagDropStep(state, sample)
    local hist = state.hist
    local prev = hist[#hist]
    hist[#hist + 1] = sample
    if #hist > 16 then table.remove(hist, 1) end

    state.rest = state.rest or sample.rel
    if not state.released then
        if sample.rel:Distance(state.rest) > RELEASE_DIST then
            state.released = true
            state.startZ = sample.eye.z
            state.low = sample
        end
        return
    end

    if prev and sample.t > prev.t then
        local dt = sample.t - prev.t
        if sample.rel:Distance(prev.rel) / dt > JUMP_SPEED then return prev end

        local vel = (sample.eye - prev.eye) / dt
        if vel.z < 0 and (not state.fall or vel.z < state.fall.z) then
            state.fall = vel
        end
    end

    if sample.eye.z < state.low.eye.z then state.low = sample end

    local dropped = state.startZ - state.low.eye.z > LOW_DROP
    if dropped and sample.eye.z > state.low.eye.z + LOW_RISE then return state.low end
end

function SandSwep.MagDropVelocity(state)
    local vel = state.fall and Vector(state.fall) or Vector(0, 0, -60)
    if vel:Length() > MAX_FALL then vel = vel:GetNormalized() * MAX_FALL end

    return vel
end

hook.Add("Think", "SandSwep_MagDropOthers", function()
    if not cvDrop:GetBool() or not SandSwep.Holders then return end

    local localPly = LocalPlayer()
    local holders, wepOf = SandSwep.Holders()

    for _, ply in ipairs(holders) do
        local wep = wepOf[ply]
        if wep:IsDormant() or not wep:IsReloading() or wep:GetReloadState() ~= RELOAD_QUICK then continue end
        if ply == localPly and not ply:ShouldDrawLocalPlayer() then continue end

        local key = wep:GetActionStart()
        if wep._magDropKey == key then continue end

        local entry = wep:GetCurrentReloadEntry()
        local dropAt = (istable(entry) and entry.MagOut or 0.5) + 0.25
        if wep:GetReloadAnimTime() < dropAt then continue end

        wep._magDropKey = key

        local model, snd = SandSwep.MagPropFor(wep)
        if not model then continue end

        local hand = ply:LookupBone("ValveBiped.Bip01_L_Hand")
        local pos = hand and ply:GetBonePosition(hand) or (ply:GetPos() + Vector(0, 0, 40))
        local ang = Angle(math.Rand(-30, 30), ply:EyeAngles().y + math.Rand(-60, 60), math.Rand(-30, 30))

        local vel = ply:GetVelocity() + Vector(0, 0, -40)
        local spin = VectorRand() * 250
        local rounds = ply == localPly and SandSwep.MagPropRounds(wep) or nil
        SandSwep.SpawnMagProp(model, snd, pos, ang, vel, spin, rounds)
    end
end)

local function SpawnVMMag(wep, ply, state)
    local spawnAt = state.spawnAt
    local model, snd = SandSwep.MagPropFor(wep)
    if not model then return end

    local view = state.view
    local fall = SandSwep.MagDropVelocity(state)
    local fwd, left, up = view.ang:Forward(), -view.ang:Right(), view.ang:Up()
    local vel = fwd * fall.x + left * (fall.y * view.k) + up * (fall.z * view.k) + ply:GetVelocity()

    local pos = spawnAt.pos
    local tr = SandSwep.TraceLine(ply:EyePos(), pos, ply, MASK_SOLID)
    if tr.Hit then pos = tr.HitPos + tr.HitNormal * 3 end

    SandSwep.SpawnMagProp(model, snd, pos, spawnAt.ang, vel, VectorRand() * 150, state.rounds)
end

hook.Add("PostDrawViewModel", "SandSwep_MagDrop", function(vm, ply, wep)
    if ply ~= LocalPlayer() or not IsValid(wep) or not wep.IsSandSwep or not SandSwep.MagDropStep then return end
    if not IsValid(vm) or vm ~= ply:GetViewModel(0) or ply:ShouldDrawLocalPlayer() then return end

    local state = wep._magDrop
    local quick = wep:IsReloading() and wep:GetReloadState() == RELOAD_QUICK
    if not quick then
        if state and state.released and not state.done then
            state.spawnAt = state.hist[#state.hist]
            state.done = true
            SpawnVMMag(wep, ply, state)
        end
        wep._magDrop = nil
        return
    end

    local key = wep:GetActionStart()
    if not state or state.key ~= key then
        state = {
            key = key,
            hist = {},
            rounds = SandSwep.MagPropRounds and SandSwep.MagPropRounds(wep),
        }
        wep._magDrop = state
    end

    if state.done or state.frame == FrameNumber() then return end
    state.frame = FrameNumber()

    local magBone, wpnBone = SandSwep.BoneId(vm, "b_wpn_mag"), SandSwep.BoneId(vm, "b_wpn")
    local magMat, wpnMat = magBone and vm:GetBoneMatrix(magBone), wpnBone and vm:GetBoneMatrix(wpnBone)
    if not magMat or not wpnMat then return end

    local vmView = SandSwep.VMView
    if not vmView then return end

    local view = vmView.ViewInfo(wep, true)
    state.view = view

    local magPos = magMat:GetTranslation()
    local sample = {
        t = UnPredictedCurTime(),
        rel = (wpnMat:GetInverseTR() * magMat):GetTranslation(),
        eye = WorldToLocal(magPos, angle_zero, view.origin, view.ang),
        pos = vmView.ToWorld(magPos, view),
        ang = magMat:GetAngles(),
    }

    local hit = SandSwep.MagDropStep(state, sample)
    if hit then
        state.spawnAt = hit
        state.done = true
        wep._magDropKey = key
        SpawnVMMag(wep, ply, state)
    end
end)
