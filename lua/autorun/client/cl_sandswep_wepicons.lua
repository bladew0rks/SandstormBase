local ICON_DIR = "sandswep/hud/weapons/"
local mats = {}

local function Icon(class)
    local mat = mats[class]
    if mat == nil then
        local path = ICON_DIR .. class
        mat = file.Exists("materials/" .. path .. ".vmt", "GAME") and Material(path, "smooth") or false
        mats[class] = mat
    end

    return mat
end

local function DrawSelection(self, x, y, w, h, alpha)
    local mat = Icon(self:GetClass())
    if not mat then return end

    local iconW, iconH = mat:Width(), mat:Height()
    local scale = math.min(w / iconW, h / iconH)
    local drawW, drawH = iconW * scale, iconH * scale

    surface.SetMaterial(mat)
    surface.SetDrawColor(255, 255, 255, alpha)
    surface.DrawTexturedRect(x + (w - drawW) * 0.5, y + (h - drawH) * 0.5, drawW, drawH)
end

local spawnIcons = {}

local function SpawnIcon(class)
    local has = spawnIcons[class]
    if has == nil then
        has = file.Exists("materials/" .. ICON_DIR .. "icon/" .. class .. ".vmt", "GAME")
        spawnIcons[class] = has
    end

    return has
end

local function Apply()
    for _, swep in ipairs(weapons.GetList()) do
        local class = swep.ClassName
        if class and string.StartWith(class, "weapon_sand_") then
            local stored = weapons.GetStored(class)
            if stored then
                if Icon(class) then stored.DrawWeaponSelection = DrawSelection end
                if SpawnIcon(class) then stored.IconOverride = ICON_DIR .. "icon/" .. class end
            end
        end
    end

    for class, entry in pairs(list.GetForEdit and list.GetForEdit("Weapon") or list.Get("Weapon")) do
        if string.StartWith(class, "weapon_sand_") and SpawnIcon(class) then
            entry.IconOverride = ICON_DIR .. "icon/" .. class
        end
    end
end

SandSwep = SandSwep or {}
SandSwep.ApplyWepIcons = Apply

hook.Add("InitPostEntity", "SandSwep_WepIcons", Apply)
hook.Add("OnGamemodeLoaded", "SandSwep_WepIcons", Apply)
hook.Add("PopulateWeapons", "SandSwep_WepIcons", Apply)
Apply()

list.Set("ContentCategoryIcons", "Sandstorm SWEPs", "vgui/sandswep_logo.png")
