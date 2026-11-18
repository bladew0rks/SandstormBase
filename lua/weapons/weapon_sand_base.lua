AddCSLuaFile()

local cvDeveloper = GetConVar("developer")
local function Developer()
    return cvDeveloper:GetInt() > 0
end

local RELOAD_NONE, RELOAD_TACTICAL, RELOAD_QUICK = 0, 1, 2
local RELOAD_RESUME, RELOAD_BOLT, RELOAD_INSERT = 3, 4, 5
local STAGE_NONE, STAGE_MAGOUT, STAGE_BOLT = 0, 1, 2

local FIREMODE_LABELS = { safe = "SAFE", semi = "SEMI", burst = "BURST", auto = "AUTO", pump = "PUMP" }

local function SinceTime(startTime)
    return math.max(CurTime() - startTime, 0)
end

SandSwep = SandSwep or {}
SandSwep.BaseShared = {
    Developer = Developer,
    RELOAD_NONE = RELOAD_NONE,
    RELOAD_TACTICAL = RELOAD_TACTICAL,
    RELOAD_QUICK = RELOAD_QUICK,
    RELOAD_RESUME = RELOAD_RESUME,
    RELOAD_BOLT = RELOAD_BOLT,
    RELOAD_INSERT = RELOAD_INSERT,
    STAGE_NONE = STAGE_NONE,
    STAGE_MAGOUT = STAGE_MAGOUT,
    STAGE_BOLT = STAGE_BOLT,
    FIREMODE_LABELS = FIREMODE_LABELS,
    SinceTime = SinceTime,
}

local MODULES = {
    "core/config",
    "core/setup",
    "core/mdlevents",
    "core/anims",
    "gameplay/reload",
    "gameplay/boltaction",
    "gameplay/launcher",
    "core/actions",
    "gameplay/sounds",
    "gameplay/firemodes",
    "gameplay/sights",
    "gameplay/movement",
    "core/think",
    "gameplay/firing",
    "render/view",
    "render/attmodels",
    "render/vmgrip",
    "render/vmhandpose",
    "render/vmblend",
    "render/seqstep",
    "render/vmparts",
    "render/optics",
    "render/tactical",
    "render/attrender",
    "core/tools",
    "render/vmview",
    "render/casings",
    "render/belts",
    "gameplay/barrel",
}

for _, name in ipairs(MODULES) do
    local path = "sandswep_base/" .. name .. ".lua"
    AddCSLuaFile(path)
    include(path)
end
