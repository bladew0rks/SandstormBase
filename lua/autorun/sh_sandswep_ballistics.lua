AddCSLuaFile()

SandSwep = SandSwep or {}

local B = SandSwep.Ballistics or {}
SandSwep.Ballistics = B

local FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY)
local cvEnabled = CreateConVar("sv_sandswep_ballistics", "1", FLAGS, "Bullets have travel time and drop (0 = instant hitscan)", 0, 1)
local cvPen = CreateConVar("sv_sandswep_penetration", "1", FLAGS, "Bullets go through walls, props and bodies", 0, 1)

local UNITS = 39.37
local GRAVITY = 9.81 * UNITS
local AIR = 1.225
local SOUND_SPEED = 340.3
local LB_IN2 = 703.07
local CM_PER_UNIT = 2.54

local STEP = 1 / 100
local TABLE_TIME = 6
local LIFETIME = 3
local INSTANT = 0.1
local MIN_SPEED = 60 * UNITS
local MIN_DAMAGE = 0.3
local MAX_FLYING = 512
local MAX_PENS = 3
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

function B.AddCalibre(name, def)
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
    return 0.5 * GRAVITY * t * t
end

B.AddCalibre("556x45",      { Velocity = 920, BC = 0.151, Pen = 40 })
B.AddCalibre("545x39",      { Velocity = 880, BC = 0.168, Pen = 40 })
B.AddCalibre("58x42",       { Velocity = 930, BC = 0.170, Pen = 45 })
B.AddCalibre("762x39",      { Velocity = 715, BC = 0.140, Pen = 50 })
B.AddCalibre("9x39",        { Velocity = 290, BC = 0.170, Pen = 55 })
B.AddCalibre("300blk",      { Velocity = 310, BC = 0.300, Pen = 30 })
B.AddCalibre("762x51",      { Velocity = 840, BC = 0.200, Pen = 70 })
B.AddCalibre("762x51match", { Velocity = 790, BC = 0.243, Pen = 70 })
B.AddCalibre("762x54r",     { Velocity = 830, BC = 0.190, Pen = 70 })
B.AddCalibre("338lapua",    { Velocity = 900, BC = 0.320, Pen = 110 })
B.AddCalibre("50bmg",       { Velocity = 890, BC = 0.330, Pen = 200 })
B.AddCalibre("9x19",        { Velocity = 370, BC = 0.075, Pen = 25 })
B.AddCalibre("45acp",       { Velocity = 255, BC = 0.090, Pen = 20 })
B.AddCalibre("762x25",      { Velocity = 430, BC = 0.060, Pen = 35 })
B.AddCalibre("9x18",        { Velocity = 315, BC = 0.070, Pen = 18 })
B.AddCalibre("357mag",      { Velocity = 435, BC = 0.100, Pen = 32 })
B.AddCalibre("50ae",        { Velocity = 470, BC = 0.120, Pen = 40 })
B.AddCalibre("46x30",       { Velocity = 735, BC = 0.075, Pen = 35 })
B.AddCalibre("57x28",       { Velocity = 715, BC = 0.090, Pen = 32 })

B.AmmoCalibres = B.AmmoCalibres or {
    SMG1 = "556x45",
    AR2 = "762x51",
    Pistol = "9x19",
    ["357"] = "357mag",
    SniperRound = "762x51match",
    SniperPenetratedRound = "50bmg",
}

function B.Enabled() return cvEnabled:GetBool() end

local RESIST = {}
local function Resist(mat, value) if mat then RESIST[mat] = value end end
Resist(MAT_WOOD, 1)
Resist(MAT_FLESH, 1)
Resist(MAT_BLOODYFLESH, 1)
Resist(MAT_ALIENFLESH, 1)
Resist(MAT_ANTLION, 1.5)
Resist(MAT_EGGSHELL, 1)
Resist(MAT_GLASS, 0.6)
Resist(MAT_PLASTIC, 0.8)
Resist(MAT_FOLIAGE, 0.2)
Resist(MAT_SLOSH, 2)
Resist(MAT_COMPUTER, 4)
Resist(MAT_GRATE, 4)
Resist(MAT_VENT, 6)
Resist(MAT_SNOW, 3)
Resist(MAT_DIRT, 7)
Resist(MAT_GRASS, 7)
Resist(MAT_SAND, 9)
Resist(MAT_TILE, 8)
Resist(MAT_CONCRETE, 8)
Resist(MAT_METAL, 12)
Resist(MAT_DEFAULT, 4)
Resist(MAT_CLIP, math.huge)
Resist(MAT_WARPSHIELD, math.huge)
B.Resist = RESIST

local DOWN = Vector(0, 0, -1)

local function PosAt(state, e, out)
    local o, d = state.Origin, state.Dir
    local s = B.DistAt(state.Def, state.Tau + e) - state.Base
    local drop = 0.5 * GRAVITY * e * e
    out.x = o.x + d.x * s
    out.y = o.y + d.y * s
    out.z = o.z + d.z * s - drop
    return out
end
B.PosAt = PosAt

local function Restart(state, pos, speed)
    local d = state.Dir
    local v = B.SpeedAt(state.Def, state.Tau + state.E)
    local fall = GRAVITY * state.E
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

local function FindExit(hit, dir, depth)
    local ent = hit.ent
    local pos = hit.pos

    if IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then
        if depth < BODY_DEPTH then return nil end
        return pos + dir * BODY_DEPTH
    end

    if hit.world or not IsValid(ent) then
        exitTrace.start = pos + dir * 0.5
        exitTrace.endpos = pos + dir * depth
        exitTrace.filter = nil
        exitTrace.ignoreworld = false
        exitTrace.output = exitOut

        local tr = util.TraceLine(exitTrace)
        if not tr.StartSolid then return exitTrace.start end
        if tr.AllSolid then return nil end

        return LerpVector(tr.FractionLeftSolid, exitTrace.start, exitTrace.endpos)
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
    if not cvPen:GetBool() or state.Pens >= MAX_PENS or hit.sky then return false end

    local resist = RESIST[hit.mat] or 4
    if resist == math.huge then return false end

    local def = state.Def
    local power = def.Pen * state.PenMult * hit.speed / state.Muzzle
    local depth = math.min(power / (resist * CM_PER_UNIT), MAX_DEPTH)
    if depth < 0.5 then return false end

    local dir = state.Dir
    local exit = FindExit(hit, dir, depth + 1)
    if not exit then return false end

    local cost = exit:Distance(hit.pos) * CM_PER_UNIT * resist
    local left = 1 - cost / power
    if left <= 0.05 then return false end

    local speed = hit.speed * math.sqrt(left)
    if speed < MIN_SPEED then return false end

    state.Pens = state.Pens + 1
    state.Ignore = IsValid(hit.ent) and not hit.world and hit.ent or nil

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
    hit.mat = tr.MatType
    hit.frac = tr.Fraction

    local speed = B.SpeedAt(cur.Def, cur.Tau + curE + curDur * tr.Fraction)
    hit.speed = speed

    if dmg then dmg:ScaleDamage(math.Clamp(speed / cur.Muzzle, MIN_DAMAGE, 1)) end

    if cur.Callback and IsValid(cur.Weapon) then cur.Callback(attacker, tr, dmg) end
end

local shot = { Num = 1, Spread = Vector(0, 0, 0) }
local p0, p1 = Vector(), Vector()

local function FireSegment(state, e, dur, from, to, tracer)
    local dir = to - from
    local len = dir:Length()
    if len < 0.01 then
        hit.called, hit.hit, hit.sky = true, false, false
        return
    end
    dir:Div(len)

    local b = state.Bullet
    shot.Src = from
    shot.Dir = dir
    shot.Distance = len
    shot.Damage = b.Damage
    shot.Force = b.Force
    shot.AmmoType = b.AmmoType
    shot.Tracer = tracer and 1 or 0
    shot.TracerName = b.TracerName
    shot.IgnoreEntity = state.Ignore
    shot.Callback = OnBullet

    cur, curE, curDur = state, e, dur
    hit.called, hit.hit, hit.sky, hit.ent = false, false, false, nil

    state.Owner:FireBullets(shot)

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
    if not Alive(state) then return end

    if SERVER then
        if #live >= MAX_FLYING then return end
        local s = Copy(state)
        live[#live + 1] = s
        outgoing[#outgoing + 1] = { s.Def.Id, Vector(s.Origin), Vector(s.Dir), s.Tau, s.E, s.Owner, s.Tracer or false }
    elseif IsFirstTimePredicted() then
        B.AddVisual(state.Def.Id, state.Origin, state.Dir, state.Tau, state.E, state.Owner, state.Tracer)
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

    while window > 0.001 do
        PosAt(state, state.E, p0)
        PosAt(state, state.E + window, p1)

        FireSegment(state, state.E, window, p0, p1, first and state.Tracer)
        first = false

        if hit.hit then
            local used = window * hit.frac
            state.Age = state.Age + used
            state.E = state.E + used
            window = window - used
            if not Penetrate(state, hit) then window = -1 end
        elseif hit.sky then
            window = -1
        else
            state.Age = state.Age + window
            state.E = state.E + window
            window = 0
        end
    end

    if window == 0 then Launch(state) end

    Release(state)
end

local function Step(state, dt)
    PosAt(state, state.E, p0)
    PosAt(state, state.E + dt, p1)

    FireSegment(state, state.E, dt, p0, p1, false)

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

local probe, probeOut = { mask = MASK_SHOT }, {}
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

    if tr.HitSky then return nil end
    return not tr.Hit and not tr.StartSolid
end

if SERVER then
    util.AddNetworkString("sandswep_bullets")

    hook.Add("Tick", "SandSwep_Ballistics", function()
        local n = #live
        if n == 0 then return end

        local dt = engine.TickInterval()

        for i = n, 1, -1 do
            local s = live[i]
            local keep = IsValid(s.Owner)

            if keep then
                local clear = Clear(s)
                if clear == nil then
                    keep = false
                elseif clear then
                    s.E = s.E + dt
                    s.Age = s.Age + dt
                    keep = Alive(s)
                else
                    keep = Step(s, dt)
                end
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
        end

        net.Broadcast()

        for i = n, 1, -1 do outgoing[i] = nil end
    end)

    return
end

local visuals = {}
local tracerMat = Material("effects/spark")
local TRACER_COLOR = Color(255, 200, 140)
local CRACK_RADIUS = 160

function B.AddVisual(id, origin, dir, tau, e, owner, tracer)
    local def = B.ById[id]
    if not def or #visuals >= MAX_FLYING then return end

    local v = {
        Def = def,
        Origin = Vector(origin),
        Dir = Vector(dir),
        Tau = tau,
        Base = B.DistAt(def, tau),
        E = e,
        Age = 0,
        Owner = owner,
        Tracer = tracer,
        Pos = Vector(),
        Prev = Vector(),
    }
    PosAt(v, e, v.Pos)
    v.Prev:Set(v.Pos)
    visuals[#visuals + 1] = v
end

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

        if sp or owner ~= me then
            B.AddVisual(id, origin, dir, tau, e, owner, tracer)
        end
    end
end)

local wallTrace, wallOut = { mask = MASK_SOLID_BRUSHONLY }, {}

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

hook.Add("Think", "SandSwep_BallisticsVisuals", function()
    local n = #visuals
    if n == 0 then return end

    local dt = FrameTime()
    if dt <= 0 then return end

    local me = LocalPlayer()
    local eye = IsValid(me) and me:EyePos()

    for i = n, 1, -1 do
        local v = visuals[i]
        v.Prev:Set(v.Pos)
        v.E = v.E + dt
        v.Age = v.Age + dt
        PosAt(v, v.E, v.Pos)

        wallTrace.start = v.Prev
        wallTrace.endpos = v.Pos
        wallTrace.output = wallOut
        local tr = util.TraceLine(wallTrace)

        local dead = tr.Hit or not Alive(v)
        if tr.Hit then v.Pos:Set(tr.HitPos) end

        if eye and not v.Cracked and v.Owner ~= me then NearMiss(v, eye) end

        if dead then
            v.Dead = (v.Dead or 0) + 1
            if v.Dead > 1 then
                visuals[i] = visuals[#visuals]
                visuals[#visuals] = nil
            end
        end
    end
end)

hook.Add("PostDrawTranslucentRenderables", "SandSwep_BallisticsTracers", function(depth, sky)
    if depth or sky or #visuals == 0 then return end

    render.SetMaterial(tracerMat)

    for i = 1, #visuals do
        local v = visuals[i]
        if v.Tracer then
            render.DrawBeam(v.Prev, v.Pos, 2, 0, 1, TRACER_COLOR)
        end
    end
end)
