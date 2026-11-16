SandSwep = SandSwep or {}

local holders, wepOf, builtFrame = {}, {}, -1

function SandSwep.Holders()
    local frame = FrameNumber()
    if frame == builtFrame then return holders, wepOf end
    builtFrame = frame

    for i = #holders, 1, -1 do holders[i] = nil end
    for ply in pairs(wepOf) do wepOf[ply] = nil end

    for _, ply in player.Iterator() do
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep.IsSandSwep then
            holders[#holders + 1] = ply
            wepOf[ply] = wep
        end
    end

    return holders, wepOf
end
