SandSwep = SandSwep or {}

local cvSession = CreateConVar("sv_sandswep_session_loadouts", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY),
    "Remember each player's attachments per weapon until the map changes", 0, 1)

if CLIENT then return end

util.AddNetworkString("SandSwep_SpawnPreset")

SandSwep.SessionLoadouts = SandSwep.SessionLoadouts or {}
SandSwep.SpawnPresets = SandSwep.SpawnPresets or {}

local function key(ply)
    return ply:IsBot() and ("bot" .. ply:EntIndex()) or ply:SteamID64()
end

function SandSwep.SaveSessionLoadout(ply, wep)
    if not cvSession:GetBool() then return end
    if not IsValid(ply) or not ply:IsPlayer() or not IsValid(wep) then return end

    local id = key(ply)
    local byClass = SandSwep.SessionLoadouts[id] or {}
    SandSwep.SessionLoadouts[id] = byClass

    byClass[wep:GetClass()] = {
        att = wep:GetAttData(),
        skins = wep:GetAttSkins(),
    }
end

net.Receive("SandSwep_SpawnPreset", function(_, ply)
    if not IsValid(ply) then return end

    local class = net.ReadString()
    local hasPreset = net.ReadBool()
    local att = hasPreset and net.ReadString() or ""
    local skins = hasPreset and net.ReadString() or ""

    if #class == 0 or #class > 64 then return end
    if #att > 1024 or #skins > 512 then return end

    local id = key(ply)
    local byClass = SandSwep.SpawnPresets[id] or {}
    SandSwep.SpawnPresets[id] = byClass

    if hasPreset then
        if not byClass[class] and table.Count(byClass) >= 256 then return end
        byClass[class] = { att = att, skins = skins }
    else
        byClass[class] = nil
    end
end)

function SandSwep.RestoreSessionLoadout(wep, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local class, id = wep:GetClass(), key(ply)
    local saved = SandSwep.SpawnPresets[id] and SandSwep.SpawnPresets[id][class]
    if not saved and cvSession:GetBool() then
        saved = SandSwep.SessionLoadouts[id] and SandSwep.SessionLoadouts[id][class]
    end

    if not saved then return end

    local oldSize = wep:GetMagSize()
    local clip = wep:Clip1()
    wep:ApplyLoadout(saved.att, saved.skins)

    local size = wep:GetMagSize()
    if size ~= oldSize then
        if clip >= oldSize then
            wep:SetClip1(size + clip - oldSize)
        else
            wep:SetClip1(math.min(clip, size))
        end

        if not (wep.PoolsAmmo and wep:PoolsAmmo()) then
            local mags = {}
            for i, rounds in ipairs(wep:GetMags()) do
                mags[i] = rounds >= oldSize and size or math.min(rounds, size)
            end
            wep:SetMags(mags)
        end
    end

    wep._lastMagKey = nil
    wep:UpdateMagSize()
end
