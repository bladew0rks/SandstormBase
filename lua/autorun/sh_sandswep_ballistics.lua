AddCSLuaFile()

SandSwep = SandSwep or {}

local B = SandSwep.Ballistics or {}
SandSwep.Ballistics = B

local FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY)
local cvEnabled = CreateConVar("sv_sandswep_ballistics", "1", FLAGS, "Bullets have travel time and drop (0 = instant hitscan)", 0, 1)
local cvPen = CreateConVar("sv_sandswep_penetration", "1", FLAGS, "Bullets go through walls, props and bodies", 0, 1)
local cvGravity = CreateConVar("sv_sandswep_ballistics_gravity", "1", FLAGS, "Bullet drop multiplier", 0, 5)
local cvMinDamage = CreateConVar("sv_sandswep_ballistics_min_damage", "0.3", FLAGS, "Lowest damage a slowed bullet does, as a fraction of full damage", 0, 1)
local cvPenMult = CreateConVar("sv_sandswep_penetration_mult", "1", FLAGS, "Multiplies how far bullets get through walls and bodies", 0, 5)
local cvPenMax = CreateConVar("sv_sandswep_penetration_max", "3", FLAGS, "Most surfaces one bullet can go through", 0, 10)
local cvTracers = CreateConVar("sv_sandswep_bullet_tracers", "1", FLAGS, "Draw bullet tracers", 0, 1)
local cvTracerTime = CreateConVar("sv_sandswep_bullet_tracer_time", "6", FLAGS, "Seconds a tracer burns before it goes out", 0.5, 15)
local cvTracerEvery = CreateConVar("sv_sandswep_bullet_tracer_every", "1", FLAGS, "Every how many rounds is a tracer (1 = every shot)", 1, 10)
function B.TracerEvery() return cvTracerEvery:GetInt() end
local cvCracks = CreateConVar("sv_sandswep_bullet_cracks", "1", FLAGS, "Bullets passing close by crack and whiz", 0, 1)

local UNITS = 39.37
local GRAVITY = 9.81 * UNITS
local AIR = 1.225
local SOUND_SPEED = 340.3
local LB_IN2 = 703.07
local CM_PER_UNIT = 2.54

local STEP = 1 / 100
local TABLE_TIME = 14
local LIFETIME = 10
local INSTANT = 0.1
local MIN_SPEED = 60 * UNITS
local MAX_FLYING = 512
local BODY_DEPTH = 10
local MAX_DEPTH = 128

B.Instant = INSTANT
B.Units = UNITS

local G7_MACH = { 0.00, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70, 0.725, 0.75, 0.775, 0.80, 0.825, 0.85, 0.875, 0.90, 0.925, 0.95, 0.975, 1.0, 1.025, 1.05, 1.075, 1.10, 1.125, 1.15, 1.20, 1.25, 1.30, 1.35, 1.40, 1.50, 1.55, 1.60, 1.65, 1.70, 1.75, 1.80, 1.85, 1.90, 1.95, 2.00, 2.05, 2.10, 2.15, 2.20, 2.25, 2.30, 2.35, 2.40, 2.45, 2.50, 2.55, 2.60, 2.65, 2.70, 2.75, 2.80, 2.85, 2.90, 2.95, 3.00, 3.10, 3.20, 3.30, 3.40, 3.50, 3.60, 3.70, 3.80, 3.90, 4.00, 4.20, 4.40, 4.60, 4.80, 5.00 }
local G7_CD = { 0.1198, 0.1197, 0.1196, 0.1194, 0.1193, 0.1194, 0.1194, 0.1194, 0.1193, 0.1193, 0.1194, 0.1193, 0.1194, 0.1197, 0.1202, 0.1207, 0.1215, 0.1226, 0.1242, 0.1266, 0.1306, 0.1368, 0.1464, 0.1660, 0.2054, 0.2993, 0.3803, 0.4015, 0.4043, 0.4034, 0.4014, 0.3987, 0.3955, 0.3884, 0.3810, 0.3732, 0.3657, 0.3580, 0.3440, 0.3376, 0.3315, 0.3260, 0.3209, 0.3160, 0.3117, 0.3078, 0.3042, 0.3010, 0.2980, 0.2951, 0.2922, 0.2892, 0.2864, 0.2835, 0.2807, 0.2779, 0.2752, 0.2725, 0.2697, 0.2670, 0.2643, 0.2615, 0.2588, 0.2561, 0.2533, 0.2506, 0.2479, 0.2451, 0.2424, 0.2368, 0.2313, 0.2258, 0.2205, 0.2154, 0.2106, 0.2060, 0.2017, 0.1975, 0.1935, 0.1861, 0.1793, 0.1730, 0.1672, 0.1618 }

local function G7(mach)
    local n = #G7_MACH
    if mach >= G7_MACH[n] then return G7_CD[n] end

    for i = 2, n do
        local hi = G7_MACH[i]
        if mach < hi then
            local lo = G7_MACH[i - 1]
            return Lerp((mach - lo) / (hi - lo), G7_CD[i - 1], G7_CD[i])
        end
    end

    return G7_CD[n]
end

B.Calibres = B.Calibres or {}
B.ById = B.ById or {}

local PEN_RATIOS = { wood = 1, sand = 0.38, concrete = 0.15, steel = 0.024, flesh = 1.8 }

function B.AddCalibre(name, def)
    if isnumber(def.Pen) then
        local wood = def.Pen
        def.Pen = {}
        for class, ratio in pairs(PEN_RATIOS) do def.Pen[class] = wood * ratio end
    end
    def.Pen = def.Pen or {}

    local old = B.Calibres[name]
    def.Name = name
    def.Id = old and old.Id or #B.ById + 1

    local k = AIR * math.pi / (8 * def.BC * LB_IN2)
    local v = def.Velocity * 1.25
    local s = 0
    local speed, dist = {}, {}
    local count = math.ceil(TABLE_TIME / STEP) + 1
    local sub = 10
    local h = STEP / sub

    for i = 1, count do
        speed[i] = v * UNITS
        dist[i] = s * UNITS

        for _ = 1, sub do
            local mid = v - k * v * v * G7(v / SOUND_SPEED) * h * 0.5
            s = s + mid * h
            v = math.max(v - k * mid * mid * G7(mid / SOUND_SPEED) * h, 1)
        end
    end

    def.Speed, def.Dist, def.Count = speed, dist, count
    def.Duration = (count - 1) * STEP
    def.MuzzleTime = B.TimeAtSpeed(def, def.Velocity * UNITS)

    B.Calibres[name] = def
    B.ById[def.Id] = def

    return def
end

local function Sample(arr, count, t)
    local x = t / STEP
    if x <= 0 then return arr[1] end

    local i = math.floor(x)
    if i >= count - 1 then return arr[count] end

    local a = arr[i + 1]
    return a + (arr[i + 2] - a) * (x - i)
end

function B.SpeedAt(def, t) return Sample(def.Speed, def.Count, t) end
function B.DistAt(def, t) return Sample(def.Dist, def.Count, t) end

local function Search(arr, count, value, descending)
    if descending then
        if value >= arr[1] then return 0 end
        if value <= arr[count] then return (count - 1) * STEP end
    else
        if value <= arr[1] then return 0 end
        if value >= arr[count] then return (count - 1) * STEP end
    end

    local lo, hi = 1, count
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if (arr[mid] > value) == descending then lo = mid else hi = mid end
    end

    return (lo - 1 + (value - arr[lo]) / (arr[hi] - arr[lo])) * STEP
end

function B.TimeAtSpeed(def, speed) return Search(def.Speed, def.Count, speed, true) end
function B.TimeAtDist(def, dist) return Search(def.Dist, def.Count, dist, false) end

function B.DropAt(def, tau, dist)
    local t = B.TimeAtDist(def, B.DistAt(def, tau) + dist) - tau
    return 0.5 * GRAVITY * cvGravity:GetFloat() * t * t
end

B.AddCalibre("556x45",      { Velocity = 920, BC = 0.151, Pen = { wood = 25, sand = 8,  concrete = 3,   steel = 1.0,  flesh = 35 } })
B.AddCalibre("545x39",      { Velocity = 880, BC = 0.168, Pen = { wood = 28, sand = 9,  concrete = 3.5, steel = 0.8,  flesh = 50 } })
B.AddCalibre("58x42",       { Velocity = 930, BC = 0.170, Pen = { wood = 28, sand = 9,  concrete = 3.5, steel = 1.0,  flesh = 40 } })
B.AddCalibre("762x39",      { Velocity = 715, BC = 0.140, Pen = { wood = 35, sand = 10, concrete = 4,   steel = 0.6,  flesh = 65 } })
B.AddCalibre("9x39",        { Velocity = 290, BC = 0.170, Pen = { wood = 30, sand = 8,  concrete = 3,   steel = 0.5,  flesh = 60 } })
B.AddCalibre("300blk",      { Velocity = 310, BC = 0.300, Pen = { wood = 25, sand = 6,  concrete = 2,   steel = 0.3,  flesh = 55 } })
B.AddCalibre("762x51",      { Velocity = 840, BC = 0.200, Pen = { wood = 33, sand = 13, concrete = 5,   steel = 0.8,  flesh = 60 } })
B.AddCalibre("762x51match", { Velocity = 790, BC = 0.243, Pen = { wood = 33, sand = 13, concrete = 5,   steel = 0.8,  flesh = 60 } })
B.AddCalibre("762x54r",     { Velocity = 830, BC = 0.190, Pen = { wood = 35, sand = 13, concrete = 5,   steel = 0.8,  flesh = 60 } })
B.AddCalibre("338lapua",    { Velocity = 900, BC = 0.320, Pen = { wood = 70, sand = 22, concrete = 7,   steel = 1.3,  flesh = 100 } })
B.AddCalibre("50bmg",       { Velocity = 890, BC = 0.330, Pen = { wood = 120, sand = 36, concrete = 5,  steel = 2.0,  flesh = 200 } })
B.AddCalibre("9x19",        { Velocity = 370, BC = 0.075, Pen = { wood = 18, sand = 5,  concrete = 1.5, steel = 0.2,  flesh = 60 } })
B.AddCalibre("45acp",       { Velocity = 255, BC = 0.090, Pen = { wood = 15, sand = 4,  concrete = 1.2, steel = 0.15, flesh = 65 } })
B.AddCalibre("762x25",      { Velocity = 430, BC = 0.060, Pen = { wood = 25, sand = 6,  concrete = 2,   steel = 0.4,  flesh = 60 } })
B.AddCalibre("9x18",        { Velocity = 315, BC = 0.070, Pen = { wood = 14, sand = 4,  concrete = 1.2, steel = 0.15, flesh = 45 } })
B.AddCalibre("357mag",      { Velocity = 435, BC = 0.100, Pen = { wood = 22, sand = 6,  concrete = 2,   steel = 0.3,  flesh = 55 } })
B.AddCalibre("50ae",        { Velocity = 470, BC = 0.120, Pen = { wood = 30, sand = 8,  concrete = 2.5, steel = 0.4,  flesh = 70 } })
B.AddCalibre("46x30",       { Velocity = 735, BC = 0.075, Pen = { wood = 20, sand = 5,  concrete = 2,   steel = 0.6,  flesh = 40 } })
B.AddCalibre("57x28",       { Velocity = 715, BC = 0.090, Pen = { wood = 20, sand = 5,  concrete = 2,   steel = 0.5,  flesh = 35 } })

B.AmmoCalibres = B.AmmoCalibres or {
    SMG1 = "556x45",
    AR2 = "762x51",
    Pistol = "9x19",
    ["357"] = "357mag",
    SniperRound = "762x51match",
    SniperPenetratedRound = "50bmg",
}

function B.Enabled() return cvEnabled:GetBool() end

local MATERIALS = {}
local function Class(mat, class, fill) if mat then MATERIALS[mat] = { class, fill or 1 } end end
Class(MAT_WOOD, "wood")
Class(MAT_DEFAULT, "wood")
Class(MAT_PLASTIC, "wood", 0.5)
Class(MAT_EGGSHELL, "wood", 0.5)
Class(MAT_GLASS, "wood", 0.3)
Class(MAT_FOLIAGE, "wood", 0.1)
Class(MAT_FLESH, "flesh")
Class(MAT_BLOODYFLESH, "flesh")
Class(MAT_ALIENFLESH, "flesh")
Class(MAT_SLOSH, "flesh")
Class(MAT_ANTLION, "flesh", 1.5)
Class(MAT_DIRT, "sand")
Class(MAT_GRASS, "sand")
Class(MAT_SAND, "sand")
Class(MAT_SNOW, "sand", 0.3)
Class(MAT_CONCRETE, "concrete")
Class(MAT_TILE, "concrete")
Class(MAT_METAL, "steel", 0.1)
Class(MAT_VENT, "steel", 0.05)
Class(MAT_GRATE, "steel", 0.05)
Class(MAT_COMPUTER, "steel", 0.05)
Class(MAT_CLIP, "none")
Class(MAT_WARPSHIELD, "none")
B.Materials = MATERIALS

local MAT_NAMES = {}
for name, value in pairs(_G) do
    if isnumber(value) and string.sub(name, 1, 4) == "MAT_" then MAT_NAMES[value] = string.lower(string.sub(name, 5)) end
end

local DOWN = Vector(0, 0, -1)

local cvDebug = CreateConVar("sv_sandswep_ballistics_debug", "0", FLAGS, "Bullet debug drawing: 1 paths, 2 short labels, 3 full labels, 4 full labels where bullets stop", 0, 4)
local cvDebugTime = CreateConVar("sv_sandswep_ballistics_debug_time", "60", FLAGS, "Seconds the bullet debug drawing stays visible", 1, 600)
local COL_INSTANT, COL_FLIGHT, COL_PEN, COL_HIT, COL_SKY = 1, 2, 3, 4, 5
local DEBUG_COLORS = { Color(80, 255, 80), Color(255, 220, 60), Color(80, 160, 255), Color(255, 60, 60), Color(200, 80, 255) }
local debugQueue = {}

local function Debugging() return SERVER and cvDebug:GetInt() > 0 end
local function DebugLine(a, b, col) debugQueue[#debugQueue + 1] = { 1, col, Vector(a), Vector(b) } end
local function DebugCross(pos, col) debugQueue[#debugQueue + 1] = { 2, col, Vector(pos) } end
local function DebugText(pos, text, col) debugQueue[#debugQueue + 1] = { 3, col, Vector(pos), text } end
local function DebugPass(pos, full, short)
    local level = cvDebug:GetInt()
    if level == 2 then DebugText(pos, short, COL_PEN) elseif level == 3 then DebugText(pos, full, COL_PEN) end
end
local function DebugEnd(pos, full, col, short)
    local level = cvDebug:GetInt()
    DebugCross(pos, col or COL_SKY)
    if level == 2 then
        DebugText(pos, short or full, col or COL_SKY)
    elseif level >= 3 then
        DebugText(pos, full, col or COL_SKY)
        print(string.format("[sandswep ballistics] %s at %d %d %d", full, pos.x, pos.y, pos.z))
    end
end

local WATER = bit.bor(CONTENTS_WATER, CONTENTS_SLIME)
local UNDERWATER = 24
local waterTrace, waterOut = { mask = WATER }, {}

local function PosAt(state, e, out)
    local o, d = state.Origin, state.Dir
    local s = B.DistAt(state.Def, state.Tau + e) - state.Base
    local drop = 0.5 * GRAVITY * cvGravity:GetFloat() * e * e
    out.x = o.x + d.x * s
    out.y = o.y + d.y * s
    out.z = o.z + d.z * s - drop
    return out
end
B.PosAt = PosAt

local function Restart(state, pos, speed)
    local d = state.Dir
    local v = B.SpeedAt(state.Def, state.Tau + state.E)
    local fall = GRAVITY * cvGravity:GetFloat() * state.E
    d.x, d.y, d.z = d.x * v, d.y * v, d.z * v - fall
    d:Normalize()

    state.Origin:Set(pos)
    state.Tau = B.TimeAtSpeed(state.Def, speed)
    state.Base = B.DistAt(state.Def, state.Tau)
    state.E = 0
end

local exitTrace, exitOut = { mask = MASK_SHOT }, {}
local exitEnt

local function OnlyExitEnt(ent) return ent == exitEnt end
local function NoEntities() return false end

local function FindExit(hit, dir, depth)
    local ent = hit.ent
    local pos = hit.pos

    if IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then
        if depth < BODY_DEPTH then return nil end
        return pos + dir * BODY_DEPTH
    end

    if hit.world or not IsValid(ent) then
        exitTrace.start = pos + dir * depth
        exitTrace.endpos = pos
        exitTrace.filter = NoEntities
        exitTrace.ignoreworld = false
        exitTrace.output = exitOut

        local back = util.TraceLine(exitTrace)
        exitTrace.filter = nil
        if not back.StartSolid then
            return back.Hit and back.HitPos or pos + dir * 0.5
        end

        exitTrace.start = pos + dir * 0.5
        exitTrace.endpos = pos + dir * depth
        local fwd = util.TraceLine(exitTrace)
        if fwd.StartSolid and not fwd.AllSolid and fwd.FractionLeftSolid > 0 then
            return LerpVector(fwd.FractionLeftSolid, exitTrace.start, exitTrace.endpos)
        end

        return nil
    end

    exitEnt = ent
    exitTrace.start = pos + dir * depth
    exitTrace.endpos = pos
    exitTrace.filter = OnlyExitEnt
    exitTrace.ignoreworld = true
    exitTrace.output = exitOut

    local tr = util.TraceLine(exitTrace)
    exitTrace.filter, exitEnt = nil, nil

    if tr.StartSolid then return nil end
    if not tr.Hit then return pos end

    return tr.HitPos
end

local function Penetrate(state, hit)
    hit.why, hit.whyShort = nil, nil
    if hit.sky then return false end

    local def = state.Def
    local mat = MAT_NAMES[hit.mat] or "unknown material"
    local info = MATERIALS[hit.mat] or MATERIALS[MAT_DEFAULT] or { "wood", 1 }
    local class, fill = info[1], info[2]
    local reach = (def.Pen[class] or 0) / fill * state.PenMult * cvPenMult:GetFloat() * hit.speed / state.Muzzle
    local head = Debugging() and string.format("%s at %.0f m/s | %s (%s%s), reaches %.1f cm", def.Name, hit.speed / UNITS, mat, class,
        fill ~= 1 and string.format(", %d%% solid", fill * 100) or "", reach) or ""

    if not cvPen:GetBool() then hit.why, hit.whyShort = head .. " | penetration off", mat .. ": penetration off" return false end
    if state.Pens >= cvPenMax:GetInt() then hit.why, hit.whyShort = head .. " | surface limit reached", mat .. ": surface limit reached" return false end
    if hit.disp then hit.why, hit.whyShort = head .. " | terrain stops bullets", mat .. ": terrain stops bullets" return false end
    if class == "none" or reach <= 0 then hit.why, hit.whyShort = head .. " | impenetrable", mat .. ": impenetrable" return false end

    local depth = math.min(reach / CM_PER_UNIT, MAX_DEPTH)
    if depth < 0.5 then hit.why, hit.whyShort = head .. " | can't reach 0.5 units", mat .. ": can't reach 0.5 units" return false end

    local dir = state.Dir
    local exit = FindExit(hit, dir, depth + 1)
    if not exit then hit.why, hit.whyShort = string.format("%s | thicker than its max %.1f u (%.0f cm)", head, depth, depth * CM_PER_UNIT), string.format("%s: more than %.0f cm", mat, depth * CM_PER_UNIT) return false end

    local thick = exit:Distance(hit.pos)
    local cost = thick * CM_PER_UNIT
    local left = 1 - cost / reach
    if left <= 0.05 then hit.why, hit.whyShort = string.format("%s | %.1f u (%.0f cm) thick", head, thick, cost), string.format("%s: %.0f cm, reaches %.0f", mat, cost, reach) return false end

    local speed = hit.speed * math.sqrt(left)
    if speed < MIN_SPEED then hit.why, hit.whyShort = head .. " | too slow after it", mat .. ": too slow after it" return false end

    if Debugging() then
        DebugCross(hit.pos, COL_PEN)
        DebugPass(hit.pos, string.format("%s | %.1f u (%.0f cm) thick, out at %.0f m/s", head, thick, cost, speed / UNITS), string.format("through %.0f cm %s", cost, mat))
    end

    state.Pens = state.Pens + 1
    state.Ignore = IsValid(hit.ent) and not hit.world and hit.ent or nil

    if Debugging() then DebugLine(hit.pos, exit, COL_PEN) end

    Restart(state, exit, speed)

    local spread = (1 - left) * 0.03
    local seed = state.Seed + state.Pens
    local d = state.Dir
    d.x = d.x + util.SharedRandom("SandSwepPenX", -spread, spread, seed)
    d.y = d.y + util.SharedRandom("SandSwepPenY", -spread, spread, seed)
    d.z = d.z + util.SharedRandom("SandSwepPenZ", -spread, spread, seed)
    d:Normalize()

    state.Origin:Add(d * 0.25)

    return true
end

local hit = { pos = Vector() }
local cur, curE, curDur

local function OnBullet(attacker, tr, dmg)
    hit.called = true

    if not tr.Hit or tr.HitSky then
        hit.hit = false
        hit.sky = tr.HitSky
        return
    end

    hit.hit = true
    hit.sky = false
    hit.pos:Set(tr.HitPos)
    hit.ent = tr.Entity
    hit.world = tr.HitWorld
    hit.disp = (tr.DispFlags or 0) ~= 0
    hit.mat = tr.MatType
    hit.frac = tr.Fraction

    local speed = B.SpeedAt(cur.Def, cur.Tau + curE + curDur * tr.Fraction)
    hit.speed = speed

    if dmg then dmg:ScaleDamage(math.Clamp(speed / cur.Muzzle, cvMinDamage:GetFloat(), 1)) end

    if cur.Callback and IsValid(cur.Weapon) then cur.Callback(attacker, tr, dmg) end
end

local shot = { Num = 1, Spread = Vector(0, 0, 0) }
local p0, p1 = Vector(), Vector()

local function FireSegment(state, e, dur, from, to, tracer, col)
    local dir = to - from
    local len = dir:Length()
    if len < 0.01 then
        hit.called, hit.hit, hit.sky = true, false, false
        return
    end
    dir:Div(len)

    local waterHit = false
    waterTrace.start, waterTrace.endpos, waterTrace.output = from, to, waterOut
    local wtr = util.TraceLine(waterTrace)
    if wtr.Hit and not wtr.StartSolid then
        local cut = math.min(len, len * wtr.Fraction + UNDERWATER)
        dur = dur * cut / len
        len = cut
        to = from + dir * len
        waterHit = true
    end

    local b = state.Bullet
    shot.Src = from
    shot.Dir = dir
    shot.Distance = len
    shot.Damage = b.Damage
    shot.Force = b.Force
    shot.AmmoType = b.AmmoType
    shot.Tracer = (tracer and b.TracerName) and 1 or 0
    shot.TracerName = b.TracerName
    shot.IgnoreEntity = state.Ignore
    shot.Callback = OnBullet

    cur, curE, curDur = state, e, dur
    hit.called, hit.hit, hit.sky, hit.ent, hit.water = false, false, false, nil, false

    state.Owner:FireBullets(shot)

    if waterHit and not hit.hit and not hit.sky then
        hit.water = true
        hit.waterTime = dur
        hit.pos:Set(to)
    end

    if Debugging() and (SERVER or IsFirstTimePredicted()) then
        DebugLine(from, (hit.hit or hit.water) and hit.pos or to, col)
        if hit.hit then DebugCross(hit.pos, COL_HIT) end
    end

    cur = nil
    shot.Src, shot.Dir, shot.IgnoreEntity, shot.Callback = nil, nil, nil, nil
end

local live, pool = {}, {}
local outgoing = {}

local function NewState()
    local s = table.remove(pool)
    if s then return s end
    return { Origin = Vector(), Dir = Vector(), Bullet = {} }
end

local function Release(s)
    s.Owner, s.Weapon, s.Ignore, s.Callback, s.Def = nil, nil, nil, nil, nil
    pool[#pool + 1] = s
end

local function Copy(src)
    local s = NewState()
    for k, v in pairs(src) do
        if k == "Origin" or k == "Dir" then s[k]:Set(v)
        elseif k ~= "Bullet" then s[k] = v end
    end
    for k, v in pairs(src.Bullet) do s.Bullet[k] = v end
    return s
end

local function Alive(state)
    return state.Age < LIFETIME
        and state.Tau + state.E < state.Def.Duration
        and B.SpeedAt(state.Def, state.Tau + state.E) > MIN_SPEED
end

local function Launch(state)
    if not Alive(state) then
        if Debugging() then DebugEnd(PosAt(state, state.E, p1), "not launched: dead after first 0.1 s") end
        return
    end

    if SERVER then
        if #live >= MAX_FLYING then
            if Debugging() then DebugEnd(PosAt(state, state.E, p1), "not launched: too many bullets") end
            return
        end
        local s = Copy(state)
        live[#live + 1] = s
        if not s.Tracer then
            outgoing[#outgoing + 1] = { s.Def.Id, Vector(s.Origin), Vector(s.Dir), s.Tau, s.E, s.Owner, false, -1 }
        end
    end
end

local function SendTracer(state, origin, dir, tau, stopAt)
    if SERVER then
        outgoing[#outgoing + 1] = { state.Def.Id, Vector(origin), Vector(dir), tau, 0, state.Owner, true, stopAt or -1 }
    elseif IsFirstTimePredicted() then
        B.AddVisual(state.Def.Id, origin, dir, tau, 0, state.Owner, true, stopAt)
    end
end

function B.Fire(owner, wep, src, dir, bullet, opts)
    local def = opts.Def
    local state = NewState()

    state.Def = def
    state.Owner = owner
    state.Weapon = wep
    state.Callback = bullet.Callback
    state.Origin:Set(src)
    state.Dir:Set(dir)
    state.Muzzle = opts.Speed
    state.Tau = B.TimeAtSpeed(def, opts.Speed)
    state.Base = B.DistAt(def, state.Tau)
    state.E = 0
    state.Age = 0
    state.Pens = 0
    state.PenMult = opts.PenMult or 1
    state.Seed = opts.Seed or 0
    state.Tracer = opts.Tracer
    state.Ignore = nil

    local b = state.Bullet
    b.Damage = bullet.Damage
    b.Force = bullet.Force
    b.AmmoType = bullet.AmmoType
    b.TracerName = bullet.TracerName

    local window = INSTANT
    local first = true
    local muzzleOrigin, muzzleDir, muzzleTau = Vector(src), Vector(state.Dir), state.Tau
    local stopAt

    while window > 0.001 do
        PosAt(state, state.E, p0)
        PosAt(state, state.E + window, p1)

        FireSegment(state, state.E, window, p0, p1, first and state.Tracer, COL_INSTANT)
        first = false

        if hit.water then
            window = -1
            stopAt = stopAt or state.Age + hit.waterTime
            if Debugging() then DebugEnd(hit.pos, "water") end
        elseif hit.hit then
            local used = window * hit.frac
            stopAt = stopAt or state.Age + used
            state.Age = state.Age + used
            state.E = state.E + used
            window = window - used
            if not Penetrate(state, hit) then
                window = -1
                if Debugging() then DebugEnd(hit.pos, "stopped: " .. (hit.why or "?"), COL_HIT, "stopped: " .. (hit.whyShort or "?")) end
            end
        elseif hit.sky then
            window = -1
            if Debugging() then DebugEnd(p1, "left the map (sky)") end
        else
            state.Age = state.Age + window
            state.E = state.E + window
            window = 0
        end
    end

    if state.Tracer and cvTracers:GetBool() then SendTracer(state, muzzleOrigin, muzzleDir, muzzleTau, stopAt) end
    if window == 0 then Launch(state) end

    Release(state)
end

local function Step(state, dt)
    PosAt(state, state.E, p0)
    PosAt(state, state.E + dt, p1)

    FireSegment(state, state.E, dt, p0, p1, false, COL_FLIGHT)

    if hit.water then return false end

    if hit.hit then
        local used = dt * hit.frac
        state.E = state.E + used
        state.Age = state.Age + used
        if not Penetrate(state, hit) then return false end
        return Alive(state)
    end

    if hit.sky then return false end

    state.E = state.E + dt
    state.Age = state.Age + dt

    return Alive(state)
end

local probe, probeOut = { mask = bit.bor(MASK_SHOT, WATER) }, {}
local probeFilter = {}

local function Clear(state)
    probeFilter[1] = state.Owner
    probeFilter[2] = state.Ignore
    probe.start = PosAt(state, state.E, p0)
    probe.endpos = PosAt(state, state.E + engine.TickInterval(), p1)
    probe.filter = probeFilter
    probe.output = probeOut

    local tr = util.TraceLine(probe)
    probeFilter[1], probeFilter[2], probe.filter = nil, nil, nil

    if tr.HitSky then
        if Debugging() then
            DebugLine(p0, tr.HitPos, COL_FLIGHT)
            DebugCross(tr.HitPos, COL_SKY)
        end
        return nil
    end
    return not tr.Hit and not tr.StartSolid
end

if SERVER then
    util.AddNetworkString("sandswep_bullets")
    util.AddNetworkString("sandswep_bulletdebug")

    hook.Add("Think", "SandSwep_BallisticsDebug", function()
        local n = #debugQueue
        if n == 0 then return end

        local i = 1
        while i <= n do
            local count = math.min(200, n - i + 1)
            net.Start("sandswep_bulletdebug")
            net.WriteUInt(count, 8)
            for j = i, i + count - 1 do
                local d = debugQueue[j]
                net.WriteUInt(d[1], 2)
                net.WriteUInt(d[2], 3)
                net.WriteVector(d[3])
                if d[1] == 1 then net.WriteVector(d[4]) elseif d[1] == 3 then net.WriteString(d[4]) end
            end
            net.Broadcast()
            i = i + count
        end

        for k = n, 1, -1 do debugQueue[k] = nil end
    end)

    hook.Add("Tick", "SandSwep_Ballistics", function()
        local n = #live
        if n == 0 then return end

        local dt = engine.TickInterval()

        for i = n, 1, -1 do
            local s = live[i]
            local keep = IsValid(s.Owner)
            local why = not keep and "owner gone" or nil
            local endPos, whyShort

            if keep then
                local clear = Clear(s)
                if clear == nil then
                    keep, why = false, "left the map (sky)"
                elseif clear then
                    if Debugging() then DebugLine(p0, p1, COL_FLIGHT) end
                    s.E = s.E + dt
                    s.Age = s.Age + dt
                    keep = Alive(s)
                else
                    keep = Step(s, dt)
                    if not keep then
                        endPos = (hit.water or hit.hit) and hit.pos
                        why = hit.water and "water" or hit.sky and "left the map (sky)" or hit.hit and "stopped: " .. (hit.why or "?") or nil
                        whyShort = hit.hit and not hit.water and not hit.sky and "stopped: " .. (hit.whyShort or "?") or nil
                    end
                end
                if not keep and not why then
                    why = s.Age >= LIFETIME and "lifetime" or B.SpeedAt(s.Def, s.Tau + s.E) <= MIN_SPEED and "too slow" or "end of table"
                end
            end

            if not keep and Debugging() and s.Def then
                local at = endPos or PosAt(s, s.E, p1)
                DebugEnd(at, string.format("%s (%.2f s in flight)", why or "?", s.Age), endPos and hit.hit and COL_HIT or nil, whyShort or why)
            end

            if not keep then
                live[i] = live[#live]
                live[#live] = nil
                Release(s)
            end
        end
    end)

    hook.Add("Think", "SandSwep_BallisticsSend", function()
        local n = #outgoing
        if n == 0 then return end

        net.Start("sandswep_bullets", true)
        net.WriteUInt(math.min(n, 255), 8)

        for i = 1, math.min(n, 255) do
            local o = outgoing[i]
            net.WriteUInt(o[1], 8)
            net.WriteVector(o[2])
            net.WriteNormal(o[3])
            net.WriteFloat(o[4])
            net.WriteFloat(o[5])
            net.WriteEntity(o[6])
            net.WriteBool(o[7])
            net.WriteFloat(o[8])
        end

        net.Broadcast()

        for i = n, 1, -1 do outgoing[i] = nil end
    end)


    return
end

local visuals = {}
local CRACK_RADIUS = 160
local TRACER_LENGTH = 3 * UNITS
local TRACER_WIDTH = 0.035 * UNITS
local MIN_PIXELS = 2
local STOP_FADE = 0.12
local SHUTTER = 0.5
local BURNOUT = 0.35
local EXPOSURE = 0.05
local FAR_DRAW = 12000
local HISTORY = 48
local MAX_LIGHTS = 6

local tracerMat = Material("sandswep/fx/tracer")
local glowMat = Material("sprites/light_glow02_add")
local CORE = Color(255, 190, 170)
local GLOW = Color(255, 45, 20)
local CORE_HOT, CORE_COLD = Color(255, 190, 170), Color(170, 25, 10)
local GLOW_HOT, GLOW_COLD = Color(255, 45, 20), Color(110, 8, 4)

local function Burn(v)
    local life = cvTracerTime:GetFloat()
    local left = math.Clamp((life - v.Age) / (life * BURNOUT), 0, 1)
    local heat = left * left * (3 - 2 * left)
    local sputter = 1 - 0.4 * (1 - left) * math.abs(math.sin(v.Age * 31 + v.Flicker) * math.sin(v.Age * 17))

    CORE.r, CORE.g, CORE.b = Lerp(left, CORE_COLD.r, CORE_HOT.r), Lerp(left * left, CORE_COLD.g, CORE_HOT.g), Lerp(left * left, CORE_COLD.b, CORE_HOT.b)
    GLOW.r, GLOW.g, GLOW.b = Lerp(left, GLOW_COLD.r, GLOW_HOT.r), Lerp(left, GLOW_COLD.g, GLOW_HOT.g), Lerp(left, GLOW_COLD.b, GLOW_HOT.b)

    return heat * sputter, 0.45 + 0.55 * heat
end

function B.AddVisual(id, origin, dir, tau, e, owner, tracer, stopAt)
    local def = B.ById[id]
    if not def or #visuals >= MAX_FLYING then return end

    local v = {
        Def = def,
        Origin = Vector(origin),
        Dir = Vector(dir),
        Tau = tau,
        Base = B.DistAt(def, tau),
        E = e,
        StartE = e,
        Age = e,
        StopAt = stopAt and stopAt >= 0 and stopAt or nil,
        Owner = owner,
        Tracer = tracer,
        Pos = Vector(),
        Prev = Vector(),
        TailE = e,
        Fade = 1,
        Flicker = math.random() * 10,
    }
    PosAt(v, e, v.Pos)
    v.Prev:Set(v.Pos)
    visuals[#visuals + 1] = v
end

local debugLines, debugTexts = {}, {}
local MAX_DEBUG_LINES = 20000
local CROSS = { Vector(12, 0, 0), Vector(0, 12, 0), Vector(0, 0, 12) }

net.Receive("sandswep_bulletdebug", function()
    local die = RealTime() + cvDebugTime:GetFloat()
    for _ = 1, net.ReadUInt(8) do
        local kind, col = net.ReadUInt(2), DEBUG_COLORS[net.ReadUInt(3)] or color_white
        local pos = net.ReadVector()
        if kind == 1 then
            debugLines[#debugLines + 1] = { pos, net.ReadVector(), col, die }
        elseif kind == 2 then
            for _, off in ipairs(CROSS) do debugLines[#debugLines + 1] = { pos - off, pos + off, col, die } end
        else
            debugTexts[#debugTexts + 1] = { pos, net.ReadString(), col, die }
        end
    end
end)

local function Prune(list, now, cap)
    local first = 1
    local n = #list
    while first <= n and (list[first][4] < now or n - first + 1 > cap) do first = first + 1 end
    if first == 1 then return end

    table.move(list, first, n, 1)
    for i = n - first + 2, n do list[i] = nil end
end

hook.Add("PostDrawTranslucentRenderables", "SandSwep_BallisticsDebug", function(depth, sky)
    if depth or sky or (#debugLines == 0 and #debugTexts == 0) then return end

    if cvDebug:GetInt() <= 0 then
        debugLines, debugTexts = {}, {}
        return
    end

    local now = RealTime()
    Prune(debugLines, now, MAX_DEBUG_LINES)
    Prune(debugTexts, now, MAX_DEBUG_LINES)

    for i = 1, #debugLines do
        local d = debugLines[i]
        render.DrawLine(d[1], d[2], d[3], false)
    end
end)

hook.Add("HUDPaint", "SandSwep_BallisticsDebug", function()
    for i = 1, #debugTexts do
        local d = debugTexts[i]
        local screen = d[1]:ToScreen()
        if screen.visible then
            draw.SimpleTextOutlined(d[2], "DermaDefault", screen.x, screen.y, d[3], TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, color_black)
        end
    end
end)

net.Receive("sandswep_bullets", function()
    local me = LocalPlayer()
    local sp = game.SinglePlayer()

    for _ = 1, net.ReadUInt(8) do
        local id = net.ReadUInt(8)
        local origin = net.ReadVector()
        local dir = net.ReadNormal()
        local tau = net.ReadFloat()
        local e = net.ReadFloat()
        local owner = net.ReadEntity()
        local tracer = net.ReadBool()
        local stopAt = net.ReadFloat()

        if sp or owner ~= me then
            B.AddVisual(id, origin, dir, tau, e, owner, tracer, stopAt)
        end
    end
end)

local wallTrace, wallOut = { mask = bit.bor(MASK_SOLID_BRUSHONLY, WATER) }, {}

local function NearMiss(v, eye)
    local a, b = v.Prev, v.Pos
    local ab = b - a
    local len2 = ab:LengthSqr()
    if len2 < 1 then return end

    local t = math.Clamp((eye - a):Dot(ab) / len2, 0, 1)
    local closest = a + ab * t
    if closest:DistToSqr(eye) > CRACK_RADIUS * CRACK_RADIUS then return end

    v.Cracked = true
    EmitSound("Bullets.DefaultNearmiss", closest, 0, CHAN_STATIC, 1, 75, 0, math.random(95, 105))
end

local function TailTime(v, dt)
    local speed = math.max(B.SpeedAt(v.Def, v.Tau + v.E), 1)
    return math.max(v.StartE, v.E - math.max(TRACER_LENGTH / speed, dt * SHUTTER))
end

hook.Add("Think", "SandSwep_BallisticsVisuals", function()
    local n = #visuals
    if n == 0 then return end

    local dt = FrameTime()
    if dt <= 0 then return end

    local me = LocalPlayer()
    local eye = IsValid(me) and me:EyePos()

    for i = n, 1, -1 do
        local v = visuals[i]
        local remove = false

        if v.Stopped then
            v.Fade = v.Fade - dt / STOP_FADE
            v.TailE = math.min(v.E, v.TailE + dt * 0.5)
            remove = v.Fade <= 0
        else
            v.Prev:Set(v.Pos)
            local prevE = v.E
            local step = dt
            local stop = false
            if v.StopAt and v.Age + step >= v.StopAt then
                step = math.max(0, v.StopAt - v.Age)
                stop = true
            end
            v.E = v.E + step
            v.Age = v.Age + step
            PosAt(v, v.E, v.Pos)

            if v.Tracer and v.Age >= cvTracerTime:GetFloat() then
                v.Stopped = true
                v.Fade = 0
                remove = true
            elseif v.Sky then
                if not v.Tracer then remove = true end
            else
                wallTrace.start = v.Prev
                wallTrace.endpos = v.Pos
                wallTrace.output = wallOut
                local tr = util.TraceLine(wallTrace)

                if tr.HitSky then
                    v.Sky, v.SkyAge = true, v.Age
                elseif tr.Hit then
                    v.E = prevE + step * tr.Fraction
                    v.Pos:Set(tr.HitPos)
                    stop = true
                end

                if eye and not v.Cracked and v.Owner ~= me and cvCracks:GetBool() then NearMiss(v, eye) end
            end

            v.TailE = TailTime(v, dt)
            if stop or not Alive(v) then
                v.Stopped = true
                if not v.Tracer then remove = true end
            end
        end

        if remove then
            visuals[i] = visuals[#visuals]
            visuals[#visuals] = nil
        end
    end
end)

local viewPos, viewAng = Vector(), Angle()
local history, histHead, histCount = {}, 0, 0

hook.Add("RenderScene", "SandSwep_BallisticsView", function(origin, angles)
    viewPos:Set(origin)
    viewAng:Set(angles)

    histHead = histHead % HISTORY + 1
    local h = history[histHead]
    if not h then
        h = { pos = Vector(), ang = Angle(), t = 0 }
        history[histHead] = h
    end
    h.pos:Set(origin)
    h.ang:Set(angles)
    h.t = RealTime()
    histCount = math.min(histCount + 1, HISTORY)
end)

local tailPos, nearHead, nearTail = Vector(), Vector(), Vector()
local stripPts, stripAge = {}, {}

local function TracerTail(v, out)
    return PosAt(v, v.TailE, out)
end

local function PullIn(pos, eye, f, out)
    out.x = eye.x + (pos.x - eye.x) * f
    out.y = eye.y + (pos.y - eye.y) * f
    out.z = eye.z + (pos.z - eye.z) * f
    return out
end

local function SmearStrip(head, width, alpha, now, eye, f)
    local n = 0
    for k = 0, histCount - 1 do
        local h = history[(histHead - 1 - k) % HISTORY + 1]
        local age = now - h.t
        if age > EXPOSURE then break end
        n = n + 1
        local pt = stripPts[n]
        if not pt then
            pt = Vector()
            stripPts[n] = pt
        end
        pt:Set(LocalToWorld(WorldToLocal(head, angle_zero, h.pos, h.ang), angle_zero, viewPos, viewAng))
        if f < 1 then PullIn(pt, eye, f, pt) end
        stripAge[n] = age / EXPOSURE
    end
    if n < 2 or stripPts[1]:DistToSqr(stripPts[n]) < width * width then return end

    render.SetMaterial(tracerMat)
    render.StartBeam(n)
    for k = 1, n do
        GLOW.a = 110 * alpha * (1 - stripAge[k])
        render.AddBeam(stripPts[k], width * 2.5, stripAge[k], GLOW)
    end
    render.EndBeam()
    render.StartBeam(n)
    for k = 1, n do
        CORE.a = 255 * alpha * (1 - stripAge[k])
        render.AddBeam(stripPts[k], width, stripAge[k], CORE)
    end
    render.EndBeam()
end

local function DrawTracer(head, tail, width, alpha)
    CORE.a, GLOW.a = 255 * alpha, 110 * alpha
    render.SetMaterial(tracerMat)
    render.DrawBeam(head, tail, width * 2.5, 0, 1, GLOW)
    render.DrawBeam(head, tail, width, 0, 1, CORE)
    render.DrawBeam(head, tail, width, 0, 1, CORE)
end

local function Width(pos, eye, pixel)
    local dist = pos:Distance(eye)
    local pixels = MIN_PIXELS + math.min(dist / (500 * UNITS), 1.5)
    return math.max(TRACER_WIDTH, dist * pixel * pixels)
end

hook.Add("PostDrawTranslucentRenderables", "SandSwep_BallisticsTracers", function(depth, sky)
    if depth or sky or #visuals == 0 or not cvTracers:GetBool() then return end

    local eye = EyePos()
    local setup = render.GetViewSetup and render.GetViewSetup()
    local fov = setup and setup.fov or 90
    local pixel = 2 * math.tan(math.rad(fov) * 0.5) / math.max(ScrH(), 1)

    local smear = eye:DistToSqr(viewPos) < 1
    local now = RealTime()
    local farDraw = math.min(FAR_DRAW, (setup and setup.zfar or 30000) * 0.5)

    local lights = 0
    for i = 1, #visuals do
        local v = visuals[i]
        if v.Tracer then
            local head = v.Pos
            local tail = TracerTail(v, tailPos)
            local heat, thin = Burn(v)
            local width = Width(head, eye, pixel) * thin
            local alpha = math.max(v.Fade, 0) * heat
            local dist = head:Distance(eye)
            local f = dist > farDraw and farDraw / dist or 1
            local realHead = head
            if f < 1 then
                head = PullIn(head, eye, f, nearHead)
                tail = PullIn(tail, eye, f, nearTail)
                width = width * f
            end

            DrawTracer(head, tail, width, alpha)

            if smear then SmearStrip(realHead, width, alpha, now, eye, f) end

            render.SetMaterial(glowMat)
            CORE.a = 200 * alpha
            render.DrawSprite(head, width * 3, width * 3, CORE)

            if lights < MAX_LIGHTS and not v.Stopped and not v.Sky and head:DistToSqr(eye) < 2000 * 2000 then
                lights = lights + 1
                local light = DynamicLight(0x5A000 + i)
                if light then
                    light.pos = head
                    light.r, light.g, light.b = 255, 50, 25
                    light.brightness = 0.6 * heat
                    light.size = 96
                    light.decay = 2000
                    light.dietime = CurTime() + 0.05
                end
            end
        end
    end
end)
