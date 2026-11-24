local Shared = SandSwep.BaseShared
local STAGE_NONE, STAGE_MAGOUT, STAGE_BOLT = Shared.STAGE_NONE, Shared.STAGE_MAGOUT, Shared.STAGE_BOLT

-- Setup

function SWEP:SetupDataTables()
    self:NetworkVar("String", 0, "MagData")
    self:NetworkVar("String", 1, "AttData")         -- "optic=optic_eotech;tactical=tac_peq15"
    self:NetworkVar("String", 2, "AttSkins")
    self:NetworkVar("Bool",   6, "LaserOn")
    self:NetworkVar("Bool",   7, "LightOn")
    self:NetworkVar("Int",    0, "ReloadState")
    self:NetworkVar("Bool",   0, "ReloadEmpty")
    self:NetworkVar("Float",  2, "ActionStart")

    self:NetworkVar("Int",    1, "FireModeIndex")
    self:NetworkVar("Int",    2, "LastFireModeIndex")  -- restored when leaving safe
    self:NetworkVar("Int",    3, "BurstLeft")
    self:NetworkVar("Bool",   1, "TriggerHeld")
    self:NetworkVar("Float",  3, "ReloadPressTime")    -- 0 = R not being tracked

    self:NetworkVar("Bool",   2, "Aiming")
    self:NetworkVar("Bool",   3, "AimToggled")      -- toggle-mode state
    self:NetworkVar("Float",  4, "AimChangeTime")
    self:NetworkVar("Float",  5, "AimFrom")         -- progress when the last change happened
    self:NetworkVar("Int",    4, "SightIndex")
    self:NetworkVar("Float", 12, "SightSwitchedAt")
    self:NetworkVar("Float", 13, "ReloadChainAt")

    self:NetworkVar("Int",    5, "SoundSet")        -- 0 = none
    self:NetworkVar("Float",  6, "SoundSetStart")
    self:NetworkVar("Float",  7, "SoundSetLast")    -- elapsed time already processed
    self:NetworkVar("Float",  8, "SoundSetScale")

    self:NetworkVar("Float",  9, "IdleTime")
    self:NetworkVar("Bool",   5, "Readied")         -- first draw done

    self:NetworkVar("Bool",   8, "Sprinting")
    self:NetworkVar("Float", 10, "SprintChangeTime")
    self:NetworkVar("Float", 11, "SprintFrom")      -- progress when the last change happened
    self:NetworkVar("Int",    6, "SightPending")    -- sight a toggle anim is switching to
    self:NetworkVar("Float", 15, "ActionUntil")     -- when it's over
    self:NetworkVar("Float", 16, "ActionEvent")
    self:NetworkVar("Bool",  10, "GLMode")          -- underbarrel launcher selected
    self:NetworkVar("Bool",  12, "GLGiven")         -- starting grenades handed out
    self:NetworkVar("Bool",  13, "Focusing")        -- holding breath
    self:NetworkVar("Float", 18, "FocusChange")     -- when Focusing last changed
    self:NetworkVar("Float", 19, "FocusFrom")       -- focus blend (0..1) at that moment
    self:NetworkVar("Float", 20, "FocusBreath")     -- breath (0..1) at that moment
    self:NetworkVar("Bool",  14, "FocusExhausted")  -- ran out; must recover to FocusMinBreath
    self:NetworkVar("Bool",  15, "ReloadKeyHeld")
    self:NetworkVar("Int",    7, "ReloadStage")
    self:NetworkVar("Float", 21, "ReloadSaveTime")
    self:NetworkVar("Float", 23, "AnimOffStart")    -- CurTime it started (0 = none)
    self:NetworkVar("Float", 24, "AnimOffCycle")    -- cycle it started at
    self:NetworkVar("Float", 25, "AnimOffRate")     -- cycles per second
    self:NetworkVar("Int",    8, "AnimOffSeq")
    self:NetworkVar("Float", 26, "IdleSince")
    self:NetworkVar("Float", 27, "ZoomBumpAt")
    self:NetworkVar("Bool",  16, "BipodDeployed")
    self:NetworkVar("Bool",  17, "BipodCrouched")
    self:NetworkVar("Bool",  18, "BipodDuckUp")
    self:NetworkVar("Bool",  19, "DryClicked")
    self:NetworkVar("Float", 28, "BipodChange")
    self:NetworkVar("Float", 29, "BipodYaw")        -- centre of the swivel cone
    self:NetworkVar("Float", 30, "BipodPitch")
    self:NetworkVar("Vector", 0, "BipodPos")        -- where the feet rest (world)
    self:NetworkVar("Vector", 1, "BipodOrigin")
    self:NetworkVar("Vector", 2, "CoverClose")
    self:NetworkVar("Int",   10, "Action")
    self:NetworkVar("Int",   11, "ShotCount")
    self:NetworkVar("Bool",  20, "ReloadResumePending")
    self:NetworkVar("Int",    9, "TacSelect")
    self:NetworkVar("Float", 31, "HolsterAt")
    self:NetworkVar("Entity", 0, "HolsterTo")
    self:NetworkVar("Bool",  23, "NeedsCycle")
    self:NetworkVar("Bool",  24, "InsertStop")
    self:NetworkVar("Bool",  25, "EjectLive")
    self:NetworkVar("Bool",  26, "TubeSwapped")
    self:NetworkVar("Bool",  27, "PointAim")
    self:NetworkVar("Bool",  28, "PointAimPref")
    self:NetworkVar("Float", 17, "CycleAt")
    self:NetworkVar("Float", 22, "EjectAt")
    self:NetworkVar("Int",   14, "InsertPhase")
    self:NetworkVar("Int",   12, "OtherTube")
    self:NetworkVar("Int",   16, "FedShots")

    self:NetworkVarNotify("FireModeIndex", function(ent, _, _, new)
        ent:UpdateHoldType(ent:GetFireModes()[new] == "safe")
    end)
    self:NetworkVarNotify("Sprinting", function(ent, _, _, new)
        ent:UpdateHoldType(nil, new)
    end)
end

function SWEP:Initialize()
    self:SetSightIndex(1)
    if SERVER then
        self:ApplyDefaultAttachments()
        self._sandswepFresh = true
    end

    self.BaseViewModelFOV = self.ViewModelFOV

    local modeIndex = self:FindFireMode(self.DefaultFireMode) or self:FirstFiringMode() or 1
    self:SetFireModeIndex(modeIndex)
    self:SetLastFireModeIndex(modeIndex)
    self:UpdateHoldType(self:IsSafe())

    if SERVER then
        local mags = {}
        local size = self:GetMagSize()
        for i = 1, self.StartingMags do mags[i] = size end

        self:SetMags(mags)
        self._lastMagKey = nil
        self:UpdateMagSize()

        if self.Tubes then self:SetOtherTube(size) end
    end
end

local SAVED_TIMES = {
    "IgniteAt", "ActionStart", "ReloadPressTime", "AimChangeTime", "SightSwitchedAt", "ReloadChainAt",
    "SoundSetStart", "IdleTime", "SprintChangeTime", "ActionUntil", "ActionEvent", "FocusChange",
    "ReloadSaveTime", "AnimOffStart", "IdleSince", "ZoomBumpAt", "BipodChange", "HolsterAt", "CycleAt", "EjectAt",
}

function SWEP:OnRestore()
    local saved, savedAt = self.SandSwepSave, self.SandSwepSaveTime
    self.SandSwepSave, self.SandSwepSaveTime = nil, nil

    if istable(saved) then
        local shift = isnumber(savedAt) and CurTime() - savedAt or 0
        for _, name in ipairs(SAVED_TIMES) do
            local value = saved[name]
            if isnumber(value) and value > 0 then saved[name] = value + shift end
        end

        self:RestoreNetworkVars(saved)
    end

    self:UpdateHoldType(self:IsSafe())
end

function SWEP:GetMagSize()
    local cache = self:AttCache()
    if cache.magSize then return cache.magSize end

    local size = self.Primary.ClipSize
    for _, _, def in self:IterAttachments() do
        if def.MagSize then size = def.MagSize break end
    end

    cache.magSize = size
    return size
end

function SWEP:UpdateMagSize()
    local cache = self:AttCache()
    local size = self:GetMagSize()
    local key = cache.magKey
    if not key then
        key = tostring(size)
        for _, id, def in self:IterAttachments() do
            if def.Slot == "magazine" then key = key .. "|" .. tostring(id) end
        end
        cache.magKey = key
    end

    local last = self._lastMagKey
    self._lastMagKey = key
    if not last or last == key then return end

    if self:IsReloading() then self:CancelReload() end

    local clip = self:Clip1()
    local chambered = (self.ChamberRound and self:IsChambered()) and 1 or 0
    local pool = clip - chambered
    for _, rounds in ipairs(self:GetMags()) do pool = pool + rounds end

    local inGun = 0
    local mags = {}
    while pool > 0 and self:HasMagRoom(#mags) do
        local fill = math.min(pool, size)
        mags[#mags + 1] = fill
        pool = pool - fill
    end

    self:SetMags(mags)
    self:SetClip1(inGun + chambered)
    self:SetReloadStage(STAGE_NONE)
    self:SetReloadSaveTime(0)
end

-- Magazine helpers

function SWEP:GetMags()
    local data = self:GetMagData()
    if self._magStr ~= data then
        local parsed = {}
        for rounds in string.gmatch(data, "%d+") do parsed[#parsed + 1] = tonumber(rounds) end
        self._magStr, self._mags = data, parsed
    end

    return self._mags
end

local cvMagazines = CreateConVar("sv_sandswep_magazines", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY),
    "Track individual magazines (0 = spare rounds pool into full mags; quick reloads still drop the old mag)", 0, 1)

if SERVER then
    cvars.AddChangeCallback("sv_sandswep_magazines", function()
        for _, wep in ipairs(ents.GetAll()) do
            if IsValid(wep) and wep.IsSandSwep and wep.GetMags and wep.SetMags then
                wep:SetMags(table.Copy(wep:GetMags()))
            end
        end
    end, "SandSwep_Magazines")
end

function SWEP:PoolsAmmo()
    if self.Rocket then return false end
    return self.InsertReload or not cvMagazines:GetBool()
end

function SWEP:PoolCap()
    return self.MaxMags > 0 and self.MaxMags * math.max(self:GetMagSize(), 1) or 9999
end

function SWEP:SetMags(mags)
    local list = {}

    if self:PoolsAmmo() then
        local total = 0
        for _, rounds in ipairs(mags) do
            if rounds > 0 then total = total + math.floor(rounds) end
        end

        total = math.min(total, self:PoolCap())
        if total > 0 then list[1] = total end
    else
        local size = math.max(self:GetMagSize(), 1)
        for _, rounds in ipairs(mags) do
            rounds = math.floor(rounds)
            while rounds > 0 and self:HasMagRoom(#list) do
                list[#list + 1] = math.min(rounds, size)
                rounds = rounds - list[#list]
            end
        end
    end

    table.sort(list, function(a, b) return a > b end)
    self:SetMagData(table.concat(list, ","))
end

function SWEP:GetMagCount()
    return #self:GetMags()
end

function SWEP:GetSpareRounds()
    local total = 0
    for _, rounds in ipairs(self:GetMags()) do total = total + rounds end

    return total
end

function SWEP:GetRoundsInMag()
    local clip = self:Clip1()
    local stage = self:GetReloadStage()

    if stage == STAGE_MAGOUT then return 0 end
    if stage == STAGE_BOLT then return clip end
    if self.ChamberRound and clip > 0 then return clip - 1 end
    if self.ChamberBonus then return clip - self:ChamberBonus() end

    return clip
end

function SWEP:IsChambered()
    if self:GetNeedsCycle() then return false end
    return self:Clip1() > 0 and self:GetReloadStage() ~= STAGE_BOLT
end

function SWEP:IsBoltLocked()
    return not self:IsChambered()
end

function SWEP:HasMagInserted()
    return self:GetReloadStage() ~= STAGE_MAGOUT
end

function SWEP:HasMagRoom(count)
    local hardCap = math.floor(480 / (#tostring(self:GetMagSize()) + 1))
    if count >= hardCap then return false end

    return self.MaxMags <= 0 or count < self.MaxMags
end

function SWEP:Resupply()
    local count = self.MaxMags > 0 and self.MaxMags or math.max(self.StartingMags, #self:GetMags())
    local mags = {}
    local size = self:GetMagSize()
    for i = 1, count do mags[i] = size end

    self:SetMags(mags)
end

function SWEP:AbsorbReserveAmmo()
    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() then return end

    local ammoType = self:GetPrimaryAmmoType()
    if ammoType < 0 then return end

    local reserve = owner:GetAmmoCount(ammoType)
    if reserve <= 0 then return end

    local size = self:GetMagSize()
    local mags = table.Copy(self:GetMags())
    local left = reserve

    if self:PoolsAmmo() then
        local have = self:GetSpareRounds()
        local used = math.max(0, math.min(reserve, self:PoolCap() - have))
        if used > 0 then
            owner:RemoveAmmo(used, ammoType)
            self:SetMags({ have + used })
        end
        return
    end

    for i = 1, #mags do
        if left <= 0 then break end

        local give = math.min(size - mags[i], left)
        if give > 0 then
            mags[i] = mags[i] + give
            left = left - give
        end
    end

    while left > 0 and self:HasMagRoom(#mags) do
        local give = math.min(size, left)
        mags[#mags + 1] = give
        left = left - give
    end

    local used = reserve - left
    if used > 0 then
        owner:RemoveAmmo(used, ammoType)
        self:SetMags(mags)
    end
end

function SWEP:EquipAmmo(ply)
    local mine = ply:GetWeapon(self:GetClass())
    if not IsValid(mine) or not mine.GetMags then return end

    local mags = table.Copy(mine:GetMags())
    for _, rounds in ipairs(self:GetMags()) do
        if not mine:HasMagRoom(#mags) then break end
        mags[#mags + 1] = rounds
    end

    mine:SetMags(mags)
end

function SWEP:Equip(ply)
    self:SetReadied(false)      -- new owner gets the first-draw anim

    if self._sandswepFresh then
        self._sandswepFresh = nil
        if SandSwep.RestoreSessionLoadout then SandSwep.RestoreSessionLoadout(self, ply) end
    end

    self:AbsorbReserveAmmo()
end

-- Viewmodel helpers

function SWEP:SetVMPlaybackRate(rate)
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() then return end

    local vm = owner:GetViewModel()
    if IsValid(vm) then vm:SetPlaybackRate(rate) end
end
