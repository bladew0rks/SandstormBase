AddCSLuaFile()
AddCSLuaFile("sandswep_base/core/math.lua")

SandSwep = SandSwep or {}
include("sandswep_base/core/math.lua")

function SandSwep.VisualFrameTime()
    if FrameTime() <= 0 then return 0 end
    return RealFrameTime() * game.GetTimeScale()
end
