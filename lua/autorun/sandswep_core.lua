AddCSLuaFile()

SandSwep = SandSwep or {}

function SandSwep.VisualFrameTime()
    if FrameTime() <= 0 then return 0 end
    return RealFrameTime() * game.GetTimeScale()
end
