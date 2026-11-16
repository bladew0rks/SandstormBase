SandSwep = SandSwep or {}

local WRITABLE = {
    number = true, string = true, boolean = true,
    Entity = true, Weapon = true, Player = true, NPC = true, Vehicle = true,
    Vector = true, Angle = true,
}

local function Writable(value, ancestors)
    local kind = type(value)
    if WRITABLE[kind] then return true end
    if kind ~= "table" or getmetatable(value) ~= nil or ancestors[value] then return false end

    ancestors[value] = true
    for key, child in pairs(value) do
        if not Writable(key, ancestors) or not Writable(child, ancestors) then
            ancestors[value] = nil
            return false
        end
    end
    ancestors[value] = nil

    return true
end

local function SaveTable(wep)
    local out = {}
    for key, value in pairs(wep:GetTable()) do
        local runtime = isstring(key) and string.StartWith(key, "_")
        if not runtime and Writable(key, {}) and Writable(value, {}) then out[key] = value end
    end

    out.SandSwepSave = wep:GetNetworkVars()
    out.SandSwepSaveTime = CurTime()
    return out
end

local function Install()
    if not saverestore or not isfunction(saverestore.SaveEntity) then return false end
    if SandSwep.SaveEntityWrapper and saverestore.SaveEntity == SandSwep.SaveEntityWrapper then return true end

    local downstream = saverestore.SaveEntity
    SandSwep.SaveEntityWrapper = function(ent, save)
        if not IsValid(ent) or not ent.IsSandSwep then return downstream(ent, save) end

        save:StartBlock("EntityTable")
            saverestore.WriteTable(SaveTable(ent), save)
        save:EndBlock()
    end
    saverestore.SaveEntity = SandSwep.SaveEntityWrapper

    return true
end

if not Install() then timer.Simple(0, Install) end
