local SHARED = {
    "sandswep_base/tpik/sh_tracker.lua",
    "sandswep_base/tpik/sh_ik.lua",
}

local CLIENTSIDE = {
    "sandswep_base/tpik/cl_convars.lua",
    "sandswep_base/tpik/cl_attachments.lua",
    "sandswep_base/tpik/cl_solver.lua",
    "sandswep_base/tpik/cl_menu.lua",
}

if SERVER then
    for _, path in ipairs(SHARED) do AddCSLuaFile(path) end
    for _, path in ipairs(CLIENTSIDE) do AddCSLuaFile(path) end
end

if not (SandSwep and SandSwep.VisualFrameTime) then include("autorun/sandswep_core.lua") end

for _, path in ipairs(SHARED) do include(path) end

if CLIENT then
    for _, path in ipairs(CLIENTSIDE) do include(path) end
end
