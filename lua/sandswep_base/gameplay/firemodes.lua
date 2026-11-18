local FIREMODE_LABELS = SandSwep.BaseShared.FIREMODE_LABELS

-- Fire modes

local DEFAULT_FIREMODES = { "safe", "semi", "auto" }

function SWEP:GetFireModes()
    local cache = self.AttCache and self:AttCache()
    if cache then
        if cache.fireModes == nil then
            cache.fireModes = false
            for _, _, def in self:IterAttachments() do
                if def.FireModes then cache.fireModes = def.FireModes end
            end
        end
        if cache.fireModes then return cache.fireModes end
    end

    return self.FireModes or DEFAULT_FIREMODES
end

function SWEP:GetRPM()
    local cache = self.AttCache and self:AttCache()
    if cache then
        if cache.rpm == nil then
            cache.rpm = false
            for _, _, def in self:IterAttachments() do
                if def.RPM then cache.rpm = def.RPM end
            end
        end
        if cache.rpm then return cache.rpm end
    end

    return self.Primary.RPM
end

function SWEP:GetFireMode()
    return self:GetFireModes()[self:GetFireModeIndex()] or "semi"
end

function SWEP:IsSafe()
    return self:GetFireMode() == "safe"
end

function SWEP:GetFireModeName()
    if self:GetGLMode() then
        local def = self:GetGLDef()
        local name = string.upper((def and (def.GLName or def.Name)) or "Launcher")
        return name .. "  " .. (self:GetGLLoaded() and "1" or "0") .. " + " .. self:GetGLReserve()
    end

    local mode = self:GetFireMode()
    if mode == "burst" then return self.BurstCount .. "-RND BURST" end

    return FIREMODE_LABELS[mode] or string.upper(mode)
end

function SWEP:FindFireMode(name)
    if not name then return end

    for i, mode in ipairs(self:GetFireModes()) do
        if mode == name then return i end
    end
end

function SWEP:FirstFiringMode()
    for i, mode in ipairs(self:GetFireModes()) do
        if mode ~= "safe" then return i end
    end
end

function SWEP:UpdateHoldType(safe, sprinting)
    if safe == nil then safe = self:IsSafe() end
    if sprinting == nil then sprinting = self:GetSprinting() end

    if sprinting then
        self:SetHoldType(self.SprintHoldType or self.SafeHoldType)
    else
        self:SetHoldType(safe and self.SafeHoldType or self.HoldType)
    end
end

function SWEP:CanSwitchFireMode()
    if self:IsReloading() or self:GetBurstLeft() > 0 or self:ActionBlocks("firemode") then return false end
    if self:GetGLMode() or self:IsGLReloading() then return false end

    return self:GetNextSecondaryFire() <= CurTime()
end

function SWEP:ApplyFireMode(idx)
    if idx == self:GetFireModeIndex() or not self:GetFireModes()[idx] then return end

    local ct = CurTime()
    local wasSafe = self:IsSafe()

    if not wasSafe then self:SetLastFireModeIndex(self:GetFireModeIndex()) end
    self:SetFireModeIndex(idx)
    self:SetNextSecondaryFire(ct + self.FireModeSwitchDelay)

    if self.ManualFireModes and not self:IsSafe() and not self:IsBoltAction() then
        self:SetNeedsCycle(false)
        self:SetFedShots(0)
    end

    if wasSafe and not self:IsSafe() then
        self:SetNextPrimaryFire(math.max(self:GetNextPrimaryFire(), ct + self.SafeRaiseTime))
    end

    if not self:IsReloading() and not self:IsMagChecking() and self:GetSprintProgress() <= 0 then
        local aimed = self:GetAimProgress() > 0.5
        local mode = tostring(self:GetFireModes()[idx])

        local name
        for _, candidate in ipairs({ (aimed and "iron_fireselect_" or "fireselect_") .. mode, "fireselect_" .. mode,
                aimed and "iron_fireselect" or "fireselect", "fireselect" }) do
            if self:HasAnim(candidate) then name = candidate break end
        end

        if name and self:PlayAnim(name) then self:BeginAction("fireselect", self:GetAnimLength(name)) end
    end

    self:EmitSound(self.FireModeSound, 60, 100, 0.6)
end

local CYCLE_RANK = { auto = 1, burst = 2, semi = 3 }

function SWEP:CycleFireMode()
    if not self:CanSwitchFireMode() then return end
    if self:IsSafe() then return self:ToggleSafety() end
    if self.Tubes then return self:SwitchTube() end

    local modes = self:GetFireModes()
    local order = {}
    for i, mode in ipairs(modes) do
        if mode ~= "safe" then order[#order + 1] = i end
    end
    if #order < 2 then return end

    table.sort(order, function(a, b)
        local rankA, rankB = CYCLE_RANK[modes[a]] or 2, CYCLE_RANK[modes[b]] or 2
        if rankA ~= rankB then return rankA < rankB end
        return a < b
    end)

    local current = self:GetFireModeIndex()
    for k, idx in ipairs(order) do
        if idx == current then
            self:ApplyFireMode(order[k % #order + 1])
            return
        end
    end

    self:ApplyFireMode(order[1])
end

function SWEP:ToggleSafety()
    if not self:CanSwitchFireMode() then return end

    if self:IsSafe() then
        local last = self:GetLastFireModeIndex()
        if self:GetFireModes()[last] == "safe" or not self:GetFireModes()[last] then last = self:FirstFiringMode() end
        if last then self:ApplyFireMode(last) end
    else
        local safe = self:FindFireMode("safe")
        if safe then self:ApplyFireMode(safe) end
    end
end
