-- Sight editor (client): sandswep_sighteditor

if CLIENT then
    CreateClientConVar("cl_sandswep_ads_toggle", "0", true, true, "Toggle aim")

    concommand.Add("sandswep_sighteditor", function()
        local ply = LocalPlayer()
        local wep = IsValid(ply) and ply:GetActiveWeapon()
        if not IsValid(wep) or not wep.IsSandSwep then
            print("[sandswep] Hold a sandswep weapon first.")
            return
        end

        local sight = wep:GetActiveSight()
        wep.SightDev = { Pos = Vector(sight.Pos), Ang = Angle(sight.Ang.p, sight.Ang.y, sight.Ang.r) }
        RunConsoleCommand("cl_sandswep_sightdev", "1")

        local frame = vgui.Create("DFrame")
        frame:SetTitle("Sight editor - " .. wep:GetPrintName() .. " / " .. (sight.Name or "sight " .. wep:GetSightIndex()))
        frame:SetSize(420, 480)
        frame:SetPos(30, ScrH() / 2 - 240)
        frame:MakePopup()
        frame:SetKeyboardInputEnabled(false)
        frame.OnClose = function()
            RunConsoleCommand("cl_sandswep_sightdev", "0")
        end

        local wide = vgui.Create("DCheckBoxLabel", frame)
        wide:Dock(TOP)
        wide:DockMargin(6, 2, 4, 2)
        wide:SetText("Wide slider range")
        wide:SetValue(0)

        local rows = {}
        wide.OnChange = function()
            for _, refresh in ipairs(rows) do refresh() end
        end

        local function Slider(label, get, set, fine, coarse)
            local row = vgui.Create("DPanel", frame)
            row:Dock(TOP)
            row:DockMargin(4, 2, 4, 2)
            row:SetTall(46)
            row.Paint = nil

            local slider = vgui.Create("DNumSlider", row)
            slider:Dock(TOP)
            slider:SetTall(22)
            slider:SetText(label)
            slider:SetDecimals(3)

            local function Range()
                local current = get()
                if wide:GetChecked() then
                    slider:SetMinMax(-coarse, coarse)
                else
                    slider:SetMinMax(current - fine, current + fine)
                end
                slider:SetValue(current)
            end
            Range()
            rows[#rows + 1] = Range
            slider.OnValueChanged = function(_, v) set(v) end

            local bar = vgui.Create("DPanel", row)
            bar:Dock(FILL)
            bar.Paint = nil

            for _, step in ipairs({ -0.01, -0.001, 0.001, 0.01 }) do
                local button = vgui.Create("DButton", bar)
                button:Dock(LEFT)
                button:SetWide(48)
                button:SetText((step > 0 and "+" or "") .. step)
                button.DoClick = function()
                    local v = math.Round(get() + step, 3)
                    set(v)
                    Range()
                end
            end
        end

        local dev = wep.SightDev
        Slider("Right (x)",   function() return dev.Pos.x end, function(v) dev.Pos.x = v end, 1, 15)
        Slider("Forward (y)", function() return dev.Pos.y end, function(v) dev.Pos.y = v end, 1, 20)
        Slider("Up (z)",      function() return dev.Pos.z end, function(v) dev.Pos.z = v end, 1, 10)
        Slider("Pitch",       function() return dev.Ang.p end, function(v) dev.Ang.p = v end, 1, 20)
        Slider("Yaw",         function() return dev.Ang.y end, function(v) dev.Ang.y = v end, 1, 20)
        Slider("Roll",        function() return dev.Ang.r end, function(v) dev.Ang.r = v end, 1, 60)

        local copy = vgui.Create("DButton", frame)
        copy:Dock(BOTTOM)
        copy:DockMargin(4, 4, 4, 4)
        copy:SetText("Copy sight to clipboard")
        copy.DoClick = function()
            local line = string.format("Pos = Vector(%.3f, %.3f, %.3f), Ang = Angle(%.3f, %.3f, %.3f)",
                dev.Pos.x, dev.Pos.y, dev.Pos.z, dev.Ang.p, dev.Ang.y, dev.Ang.r)
            SetClipboardText(line)
            print("[sandswep] " .. line)
        end

        local save = vgui.Create("DButton", frame)
        save:Dock(BOTTOM)
        save:DockMargin(4, 4, 4, 0)
        save:SetText("Save sight to data/sandswep/sightedits.json")
        save.DoClick = function()
            local path = "sandswep/sightedits.json"
            file.CreateDir("sandswep")

            local all = util.JSONToTable(file.Read(path, "DATA") or "{}") or {}
            local class = wep:GetClass()
            all[class] = all[class] or {}

            local key = sight.AttId or ("sight:" .. (sight.Name or ""))
            if sight.AttId then
                local count = 0
                for _, other in ipairs(wep:GetSights()) do
                    if other.AttId == sight.AttId then count = count + 1 end
                end
                if count > 1 then key = sight.AttId .. ":" .. (sight.Name or "") end
            end

            all[class][key] = {
                slot = sight.AttSlot,
                name = sight.Name,
                pos = { math.Round(dev.Pos.x, 3), math.Round(dev.Pos.y, 3), math.Round(dev.Pos.z, 3) },
                ang = { math.Round(dev.Ang.p, 3), math.Round(dev.Ang.y, 3), math.Round(dev.Ang.r, 3) },
            }

            file.Write(path, util.TableToJSON(all, true))
            print("[sandswep] saved " .. class .. " / " .. key .. " to data/" .. path)
        end
    end)
end

local KEY_BINDS = {
    { "firemode", function(wep) wep:CycleFireMode() end },
    { "safety",   function(wep) wep:ToggleSafety() end },
    { "melee",    function(wep) wep:StartMelee() end },
    { "gl",       function(wep) if wep.ToggleGLMode then wep:ToggleGLMode() end end },
    { "bipod",    function(wep) if wep.ToggleBipod then wep:ToggleBipod() end end },
    { "pointaim", function(wep) if wep.TogglePointAim then wep:TogglePointAim() end end },
}

local function BindKeys(ply, name)
    local primary = ply:GetInfoNum("cl_sandswep_keycode_" .. name, 0)
    local secondary = ply:GetInfoNum("cl_sandswep_keycode_" .. name .. "2", 0)
    if primary <= 0 then primary, secondary = secondary, 0 end

    return primary, secondary
end

local function RunBind(ply, bind)
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and wep.IsSandSwep then bind[2](wep) end
end

local BIND_CACHE_TTL = 1.0

local function PlayerBinds(ply, now)
    local cache = ply.SandSwepBindCache
    if cache and now >= cache.at and now - cache.at < BIND_CACHE_TTL then return cache end

    cache = cache or { primary = {}, secondary = {} }
    ply.SandSwepBindCache = cache
    cache.at = now
    cache.delay = math.Clamp(ply:GetInfoNum("cl_sandswep_doubletap_delay", 0.3), 0.05, 1)

    for i, bind in ipairs(KEY_BINDS) do
        cache.primary[i], cache.secondary[i] = BindKeys(ply, bind[1])
    end

    return cache
end

hook.Add("PlayerButtonDown", "SandSwep_FireModeKeys", function(ply, button)
    if CLIENT and not IsFirstTimePredicted() then return end

    ply.SandSwepHeld = ply.SandSwepHeld or {}
    ply.SandSwepHeld[button] = true

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not wep.IsSandSwep then return end

    local now = CurTime()
    local binds = PlayerBinds(ply, now)
    local delay = binds.delay
    local held = ply.SandSwepHeld

    local combo, double, single1, single2, isTapKey
    for i, bind in ipairs(KEY_BINDS) do
        local primary, secondary = binds.primary[i], binds.secondary[i]
        if primary > 0 and secondary > 0 and primary == secondary then
            if primary == button then
                isTapKey = true
                double = bind
            end
        elseif primary > 0 and secondary > 0 then
            if (button == primary and held[secondary]) or (button == secondary and held[primary]) then
                combo = combo or bind
            end
        elseif primary == button then
            if not single1 then single1 = bind else single2 = bind end
        end
    end

    if combo then
        ply.SandSwepPending = nil
        RunBind(ply, combo)
        return
    end

    if double then
        local tap = ply.SandSwepTap
        if tap and tap.button == button and now - tap.time <= delay then
            ply.SandSwepTap, ply.SandSwepPending = nil, nil
            RunBind(ply, double)
            return
        end

        ply.SandSwepTap = { button = button, time = now }
    end

    if single1 then
        if isTapKey then
            if SERVER then ply.SandSwepPending = { bind = single1, at = now + delay } end
        else
            RunBind(ply, single1)
        end
    end
    if single2 then
        if isTapKey then
            if SERVER then ply.SandSwepPending = { bind = single2, at = now + delay } end
        else
            RunBind(ply, single2)
        end
    end
end)

hook.Add("PlayerButtonUp", "SandSwep_FireModeKeys", function(ply, button)
    if ply.SandSwepHeld then ply.SandSwepHeld[button] = nil end
end)

if SERVER then
    hook.Add("Think", "SandSwep_PendingKeys", function()
        local now = CurTime()
        for _, ply in player.Iterator() do
            local pending = ply.SandSwepPending
            if pending and now >= pending.at then
                ply.SandSwepPending = nil
                RunBind(ply, pending.bind)
            end
        end
    end)
end

-- Admin/cheat command to refill mags on the held weapon

if SERVER then
    concommand.Add("sandswep_resupply", function(ply)
        if not IsValid(ply) then return end
        if not ply:IsAdmin() and not GetConVar("sv_cheats"):GetBool() then return end

        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep.Resupply then
            wep:Resupply()
            wep:SetClip1(wep:GetMagSize())
            wep:SetReloadStage(0)
        end
    end)

    concommand.Add("sandswep_firemode", function(ply)
        if not IsValid(ply) then return end
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep.CycleFireMode then wep:CycleFireMode() end
    end)

    concommand.Add("sandswep_gl", function(ply)
        if not IsValid(ply) then return end
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep.ToggleGLMode then wep:ToggleGLMode() end
    end)

    concommand.Add("sandswep_bipod", function(ply)
        if not IsValid(ply) then return end
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep.ToggleBipod then wep:ToggleBipod() end
    end)

    concommand.Add("sandswep_pointaim", function(ply)
        if not IsValid(ply) then return end
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep.TogglePointAim then wep:TogglePointAim() end
    end)

    concommand.Add("sandswep_melee", function(ply)
        if not IsValid(ply) then return end
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep.StartMelee then wep:StartMelee() end
    end)

    concommand.Add("sandswep_safety", function(ply)
        if not IsValid(ply) then return end
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep.ToggleSafety then wep:ToggleSafety() end
    end)

    local interruptCD = setmetatable({}, { __mode = "k" })

    concommand.Add("sandswep_interruptreload", function(ply)
        if not IsValid(ply) then return end

        local now = SysTime()
        if (interruptCD[ply] or 0) > now then return end
        interruptCD[ply] = now + 0.1

        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or not wep.IsSandSwep or not wep:IsReloading() then return end

        wep:InterruptReload()
        if not wep:IsReloading() then wep:PlayIdleAnim() end
    end)
end

if CLIENT then
    CreateClientConVar("cl_sandswep_doubletap_delay", "0.3", true, true,
        "Double tap window for binds with the same key in both slots", 0.05, 1)

    local function KeyConVar(name, default, help)
        local cv = CreateClientConVar("cl_sandswep_key_" .. name, default, true, false, help)
        local code = CreateClientConVar("cl_sandswep_keycode_" .. name, "0", false, true,
            "internal: key code for cl_sandswep_key_" .. name)

        local function sync()
            local key = string.Trim(string.lower(cv:GetString()))
            local keyCode = (key ~= "" and key ~= "none") and input.GetKeyCode(key) or 0
            if keyCode < 0 then
                print("[sandswep] unknown key '" .. key .. "' for cl_sandswep_key_" .. name)
                keyCode = 0
            end

            RunConsoleCommand("cl_sandswep_keycode_" .. name, tostring(keyCode))
        end

        cvars.AddChangeCallback("cl_sandswep_key_" .. name, sync, "SandSwep_Key")
        hook.Add("InitPostEntity", "SandSwep_Key_" .. name, sync)
        timer.Simple(0, sync)       -- also after a Lua refresh
    end

    local keyDefaults = {
        { "firemode", "x", "Fire mode key" },
        { "safety", "b", "Safety key" },
        { "melee", "mouse3", "Melee key" },
        { "gl", "g", "Grenade launcher key" },
        { "bipod", "h", "Bipod key" },
        { "pointaim", "mouse4", "Point aim key (while aiming)" },
    }

    for _, entry in ipairs(keyDefaults) do
        KeyConVar(entry[1], entry[2], entry[3])
        KeyConVar(entry[1] .. "2", "", entry[3] .. ", second slot (same key = double tap, other key = combo)")
    end
end

function SWEP:OnReloaded()
    if CLIENT then
        self:RemoveVMAttachmentModels()
        self:ResetVMBodygroups()
    end

    local tbl = self:GetTable()
    for k in pairs(tbl) do
        if isstring(k) and (k:match("^_%w+Key$") or k:match("^_%w+Cache$")) then tbl[k] = nil end
    end

    tbl._depSights, tbl._animSets, tbl._attCache, tbl._bgList, tbl._svBgList = nil, nil, nil, nil, nil
    tbl.SandTPIK_Wrapped = nil      -- the merge put the unwrapped PlayAnim back

    self:UpdateHoldType()           -- the merge also put weapon_base's pistol translate table back
    self:SetWeaponHoldType(self:GetHoldType())
end

local function ReloadWeaponFile(class)
    local prev = SWEP
    SWEP = { Folder = "weapons/" .. class, ClassName = class, Primary = {}, Secondary = {} }

    local ok, err = pcall(include, "weapons/" .. class .. ".lua")
    if ok then
        weapons.Register(SWEP, class)
    else
        ErrorNoHalt("[sandswep] reload " .. class .. ": " .. tostring(err) .. "\n")
    end

    SWEP = prev
    return ok
end

function SandSwep.ReloadBase()
    local startTime = SysTime()

    if CLIENT then
        local cmds = concommand.GetTable()
        for _, name in ipairs({ "sandswep_clearshells", "sandswep_clearmags" }) do
            if cmds[name] then cmds[name](LocalPlayer(), name, {}, "") end
        end
    end

    for _, fileName in ipairs((file.Find("autorun/sh_sandswep_*.lua", "LUA"))) do
        include("autorun/" .. fileName)
    end

    if CLIENT then
        for _, fileName in ipairs((file.Find("autorun/client/cl_sandswep_*.lua", "LUA"))) do
            include("autorun/client/" .. fileName)
        end
    end

    local autorefresh
    if CLIENT then
        autorefresh = (hook.GetTable().PreRegisterSWEP or {}).spawnmenu_reload_swep
        if autorefresh then hook.Remove("PreRegisterSWEP", "spawnmenu_reload_swep") end
    end

    local loaded, failed = 0, 0
    if ReloadWeaponFile("weapon_sand_base") then loaded = loaded + 1 else failed = failed + 1 end

    for _, fileName in ipairs((file.Find("weapons/weapon_sand_*.lua", "LUA"))) do
        local class = fileName:sub(1, -5)
        if class ~= "weapon_sand_base" then
            if ReloadWeaponFile(class) then loaded = loaded + 1 else failed = failed + 1 end
        end
    end

    if autorefresh then hook.Add("PreRegisterSWEP", "spawnmenu_reload_swep", autorefresh) end
    if CLIENT and SandSwep.ApplyWepIcons then SandSwep.ApplyWepIcons() end

    print(string.format("[sandswep] %s reloaded %d weapon files (%d failed) in %.0f ms",
        SERVER and "server" or "client", loaded, failed, (SysTime() - startTime) * 1000))
end

if SERVER then
    util.AddNetworkString("sandswep_reloadbase")

    concommand.Add("sandswep_reloadbase", function(ply)
        if IsValid(ply) and not game.SinglePlayer() and not ply:IsSuperAdmin() then return end

        SandSwep.ReloadBase()
        net.Start("sandswep_reloadbase")
        net.Broadcast()
    end)
else
    net.Receive("sandswep_reloadbase", function() SandSwep.ReloadBase() end)
end