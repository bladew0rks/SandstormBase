local CATEGORY = "SandSwep"

hook.Add("AddToolMenuCategories", "SandSwep_OptionsCategory", function()
    spawnmenu.AddToolCategory("Options", CATEGORY, "Sandstorm Base")
end)

local function ResetButton(panel, convars)
    local button = panel:Button("Reset")
    button.DoClick = function()
        for _, name in ipairs(convars) do
            local cv = GetConVar(name)
            if cv then RunConsoleCommand(name, cv:GetDefault()) end
        end
    end
end

local function Binder(row, convar, emptyValue)
    local binder = vgui.Create("DBinder", row)
    local cv = GetConVar(convar)
    local current = cv and string.lower(string.Trim(cv:GetString())) or ""
    local code = (current ~= "" and current ~= "none") and input.GetKeyCode(current) or 0
    binder:SetValue(code > 0 and code or 0)

    function binder:OnChange(newCode)
        local name = newCode and newCode > 0 and input.GetKeyName(newCode)
        RunConsoleCommand(convar, name and string.lower(name) or emptyValue)
    end

    function binder:DoRightClick()
        self:SetValue(0)
    end

    return binder
end

local function KeyRow(panel, label, convar, emptyValue, convar2)
    local row = vgui.Create("DPanel", panel)
    row:SetTall(24)
    row:SetPaintBackground(false)

    local text = vgui.Create("DLabel", row)
    text:SetText(label)
    text:SetDark(true)
    text:Dock(LEFT)
    text:SetWide(150)

    local first = Binder(row, convar, emptyValue)
    if convar2 then
        local second = Binder(row, convar2, "")
        first:Dock(LEFT)
        second:Dock(FILL)
        second:DockMargin(4, 0, 0, 0)
        row.PerformLayout = function(self, w)
            first:SetWide(math.floor((w - 154) / 2))
        end
    else
        first:Dock(FILL)
    end

    panel:AddItem(row)
end

local function HasNVG() return SandSwep and SandSwep.NVG ~= nil end

local function Combo(panel, label, convar, choices)
    local combo = panel:ComboBox(label, convar)
    for _, choice in ipairs(choices) do
        combo:AddChoice(choice[1], choice[2])
    end
    return combo
end

local function SequenceStepper(panel)
    panel:Help("Sequence stepper (needs developer 1)")
    panel:CheckBox("Hold sequence frame", "cl_sandswep_debug_seqstep")
    local filter = panel:TextEntry("Filter")
    local combo = panel:ComboBox("Sequence")
    local slider = panel:NumSlider("Frame", "cl_sandswep_debug_frame", 0, 100, 1)

    local function ViewModel()
        local ply = LocalPlayer()
        return IsValid(ply) and ply:GetViewModel()
    end

    local function SetMax(name)
        local vm = ViewModel()
        if IsValid(vm) and SandSwep and SandSwep.SeqStepLastFrame then
            slider:SetMax(SandSwep.SeqStepLastFrame(vm, name))
        end
    end

    local function Fill()
        combo:Clear()

        local vm = ViewModel()
        if not IsValid(vm) then return end

        local want = string.lower(filter:GetValue() or "")
        local current = GetConVar("cl_sandswep_debug_seq"):GetString()

        for i = 0, vm:GetSequenceCount() - 1 do
            local name = vm:GetSequenceName(i)
            if want == "" or string.find(string.lower(name), want, 1, true) then
                combo:AddChoice(name, name)
            end
        end

        if current ~= "" then
            combo:SetValue(current)
            SetMax(current)
        end
    end

    filter:SetUpdateOnType(true)
    filter.OnValueChange = Fill

    function combo:OnSelect(_, value, data)
        local name = data or value
        RunConsoleCommand("cl_sandswep_debug_seq", name)
        RunConsoleCommand("cl_sandswep_debug_frame", "0")
        RunConsoleCommand("cl_sandswep_debug_seqstep", "1")
        SetMax(name)
    end

    panel:Button("Load sequences from viewmodel").DoClick = Fill
    panel:Button("Previous frame", "sandswep_seqstep", "-1")
    panel:Button("Next frame", "sandswep_seqstep", "1")
    Fill()
end

hook.Add("PopulateToolMenu", "SandSwep_Options", function()
    spawnmenu.AddToolMenuOption("Options", CATEGORY, "sandswep_aiming", "Aiming", "", "", function(panel)
        panel:ClearControls()
        panel:CheckBox("Toggle aim", "cl_sandswep_ads_toggle")
        panel:NumSlider("Aim sensitivity", "cl_sandswep_ads_sens", 0.1, 2, 2)
        panel:NumSlider("Scope sensitivity", "cl_sandswep_scope_sens", 0.1, 2, 2)
        panel:NumSlider("Scope zoom compensation", "cl_sandswep_scope_sens_match", 0, 1, 2)

        panel:Help("Free aim (enabled in the server options)")
        panel:NumSlider("Recentre speed", "cl_sandswep_deadzone_recenter", 0, 20, 1)
        panel:NumSlider("Hold breath vignette", "cl_sandswep_focus_vignette", 0, 2, 2)

        ResetButton(panel, {"cl_sandswep_ads_toggle", "cl_sandswep_ads_sens", "cl_sandswep_scope_sens", "cl_sandswep_scope_sens_match",
            "cl_sandswep_deadzone_recenter", "cl_sandswep_focus_vignette"})
    end)

    spawnmenu.AddToolMenuOption("Options", CATEGORY, "sandswep_view", "View & Movement", "", "", function(panel)
        panel:ClearControls()
        panel:NumSlider("Viewmodel FOV offset", "cl_sandswep_vmfov", -30, 40, 0)
        panel:CheckBox("Keep FOV offset while aiming", "cl_sandswep_vmfov_aim")
        panel:NumSlider("Animation camera", "cl_sandswep_cameraanim", 0, 3, 2)
        panel:NumSlider("Walk bob", "cl_sandswep_bob", 0, 3, 2)
        panel:NumSlider("Idle breathing", "cl_sandswep_breath", 0, 3, 2)
        panel:NumSlider("Sprint sway", "cl_sandswep_sprintcam", 0, 3, 2)
        panel:CheckBox("Centred bipod hold", "cl_sandswep_bipod_centered")

        ResetButton(panel, {"cl_sandswep_vmfov", "cl_sandswep_vmfov_aim", "cl_sandswep_cameraanim", "cl_sandswep_bob", "cl_sandswep_breath", "cl_sandswep_sprintcam",
            "cl_sandswep_bipod_centered"})
    end)

    spawnmenu.AddToolMenuOption("Options", CATEGORY, "sandswep_scopes", "Scopes", "", "", function(panel)
        panel:ClearControls()
        panel:NumSlider("Brightness", "cl_sandswep_scope_brightness", 0.2, 1.5, 2)
        panel:NumSlider("Vignette", "cl_sandswep_scope_vignette", 0, 2, 2)
        panel:NumSlider("Resolution", "cl_sandswep_scope_resolution", 0.25, 1, 2)
        panel:NumSlider("Recoil FOV kick", "cl_sandswep_fovkick", 0, 3, 2)

        ResetButton(panel, {"cl_sandswep_scope_brightness", "cl_sandswep_scope_vignette", "cl_sandswep_scope_resolution", "cl_sandswep_fovkick"})
    end)

    spawnmenu.AddToolMenuOption("Options", CATEGORY, "sandswep_hud", "HUD", "", "", function(panel)
        panel:ClearControls()
        panel:CheckBox("Enabled", "cl_sandswep_hud")
        panel:CheckBox("Health and armour", "cl_sandswep_hud_health")
        panel:CheckBox("Always show", "cl_sandswep_hud_always")
        panel:NumSlider("Show time (s)", "cl_sandswep_hud_show_time", 0, 30, 1)
        panel:CheckBox("Show fire mode changes", "cl_sandswep_hud_show_firemode")
        panel:NumSlider("Size", "cl_sandswep_hud_scale", 0.5, 2, 2)
        panel:CheckBox("Aim dot", "cl_sandswep_crosshair")
        panel:CheckBox("Hide default crosshair", "cl_sandswep_hide_crosshair")

        ResetButton(panel, {"cl_sandswep_hud", "cl_sandswep_hud_health", "cl_sandswep_hud_always", "cl_sandswep_hud_show_time",
            "cl_sandswep_hud_show_firemode", "cl_sandswep_hud_scale", "cl_sandswep_crosshair", "cl_sandswep_hide_crosshair"})
    end)

    spawnmenu.AddToolMenuOption("Options", CATEGORY, "sandswep_effects", "Effects", "", "", function(panel)
        panel:ClearControls()
        panel:CheckBox("Casings", "cl_sandswep_shells")
        panel:NumSlider("Casing lifetime (s)", "cl_sandswep_shell_life", 0, 120, 0)
        panel:Button("Clear casings", "sandswep_clearshells")
        panel:CheckBox("Dropped mags", "cl_sandswep_magdrop")
        panel:NumSlider("Mag lifetime (s)", "cl_sandswep_magdrop_life", 1, 300, 0)
        panel:Button("Clear mags", "sandswep_clearmags")

        panel:Help("Muzzle flash")
        panel:CheckBox("Dynamic light", "cl_sandswep_muzzlefx_light")

        panel:Help("Weapon lights")
        panel:NumSlider("Brightness", "cl_sandswep_light_brightness", 0, 10, 2)
        panel:CheckBox("Shadows", "cl_sandswep_light_shadows")

        ResetButton(panel, {"cl_sandswep_shells", "cl_sandswep_shell_life", "cl_sandswep_magdrop", "cl_sandswep_magdrop_life",
            "cl_sandswep_muzzlefx_light", "cl_sandswep_light_brightness", "cl_sandswep_light_shadows"})
    end)

    spawnmenu.AddToolMenuOption("Options", CATEGORY, "sandswep_controls", "Controls", "", "", function(panel)
        panel:ClearControls()
        panel:Help("Bind the same button twice to enable double tap.")
        panel:Help("Press MOUSE2 to unbind.")
        KeyRow(panel, "Fire mode", "cl_sandswep_key_firemode", "none", "cl_sandswep_key_firemode2")
        KeyRow(panel, "Safety", "cl_sandswep_key_safety", "none", "cl_sandswep_key_safety2")
        KeyRow(panel, "Melee", "cl_sandswep_key_melee", "none", "cl_sandswep_key_melee2")
        KeyRow(panel, "Grenade launcher", "cl_sandswep_key_gl", "none", "cl_sandswep_key_gl2")
        KeyRow(panel, "Bipod", "cl_sandswep_key_bipod", "none", "cl_sandswep_key_bipod2")
        KeyRow(panel, "Point aim (while aiming)", "cl_sandswep_key_pointaim", "none", "cl_sandswep_key_pointaim2")
        panel:NumSlider("Double tap delay (s)", "cl_sandswep_doubletap_delay", 0.05, 1, 2)
        KeyRow(panel, "Laser / light", "cl_sandswep_key_tactical", "")
        if HasNVG() then KeyRow(panel, "Night vision", "cl_sandswep_key_nvg", "none") end

        panel:NumSlider("Laser / light menu hold (s)", "cl_sandswep_tacmenu_hold", 0.05, 1, 2)
        if HasNVG() then panel:NumSlider("Night vision menu hold (s)", "cl_sandswep_nvgmenu_hold", 0.05, 1, 2) end
        local fast = panel:ComboBox("Quick reload", "cl_sandswep_fast_reload")
        fast:AddChoice("Double-tap reload", "0")
        fast:AddChoice("Always", "1")
        fast:AddChoice("When empty", "2")

        ResetButton(panel, {"cl_sandswep_key_firemode", "cl_sandswep_key_safety", "cl_sandswep_key_melee", "cl_sandswep_key_gl",
            "cl_sandswep_key_bipod", "cl_sandswep_key_pointaim", "cl_sandswep_key_tactical", "cl_sandswep_key_nvg",
            "cl_sandswep_key_firemode2", "cl_sandswep_key_safety2", "cl_sandswep_key_melee2", "cl_sandswep_key_gl2",
            "cl_sandswep_key_bipod2", "cl_sandswep_key_pointaim2", "cl_sandswep_doubletap_delay", "cl_sandswep_tacmenu_hold", "cl_sandswep_nvgmenu_hold",
            "cl_sandswep_fast_reload"})
    end)

    spawnmenu.AddToolMenuOption("Options", CATEGORY, "sandswep_server", "Server", "", "", function(panel)
        panel:ClearControls()
        panel:CheckBox("Bullets from the barrel", "sv_sandswep_barrelbullets")
        panel:CheckBox("First draw animation", "sv_sandswep_first_draw")
        panel:NumSlider("Recoil multiplier", "sv_sandswep_recoil_mult", 0, 3, 2)
        panel:NumSlider("Crouch recoil multiplier", "sv_sandswep_crouch_recoil", 0, 1, 2)
        panel:NumSlider("Damage multiplier", "sv_sandswep_damage_mult", 0, 5, 2)
        panel:NumSlider("Reload speed multiplier", "sv_sandswep_reload_speed", 0.25, 3, 2)
        panel:CheckBox("Free aim", "sv_sandswep_freeaim")
        panel:NumSlider("Free aim size", "sv_sandswep_freeaim_scale", 0, 3, 2)
        panel:CheckBox("Track individual magazines", "sv_sandswep_magazines")
        panel:CheckBox("Remember attachments until map change", "sv_sandswep_session_loadouts")
        panel:CheckBox("Shotguns breach doors", "sv_sandswep_shotgun_breach")
        panel:CheckBox("Explosives breach doors", "sv_sandswep_explosive_breach")
        panel:NumSlider("Breached door respawn (s)", "sv_sandswep_breach_respawn", 0, 120, 0)
        if HasNVG() then panel:CheckBox("Allow night vision", "sv_sandswep_nvg_allow") end

        ResetButton(panel, {"sv_sandswep_barrelbullets", "sv_sandswep_first_draw", "sv_sandswep_recoil_mult", "sv_sandswep_crouch_recoil", "sv_sandswep_reload_speed", "sv_sandswep_damage_mult",
            "sv_sandswep_freeaim", "sv_sandswep_freeaim_scale", "sv_sandswep_magazines",
            "sv_sandswep_session_loadouts", "sv_sandswep_shotgun_breach", "sv_sandswep_explosive_breach", "sv_sandswep_breach_respawn", "sv_sandswep_nvg_allow"})
    end)

    spawnmenu.AddToolMenuOption("Options", CATEGORY, "sandswep_ballistics", "Ballistics", "", "", function(panel)
        panel:ClearControls()
        panel:CheckBox("Bullet travel time and drop", "sv_sandswep_ballistics")
        panel:NumSlider("Bullet drop", "sv_sandswep_ballistics_gravity", 0, 3, 2)
        panel:NumSlider("Lowest damage at range", "sv_sandswep_ballistics_min_damage", 0, 1, 2)
        panel:CheckBox("Penetration", "sv_sandswep_penetration")
        panel:NumSlider("Penetration strength", "sv_sandswep_penetration_mult", 0, 3, 2)
        panel:NumSlider("Most surfaces per bullet", "sv_sandswep_penetration_max", 0, 10, 0)
        panel:CheckBox("Tracers", "sv_sandswep_bullet_tracers")
        panel:NumSlider("Tracer every Nth round", "sv_sandswep_bullet_tracer_every", 1, 10, 0)
        panel:NumSlider("Tracer burn time (s)", "sv_sandswep_bullet_tracer_time", 0.5, 15, 1)
        panel:CheckBox("Bullet cracks", "sv_sandswep_bullet_cracks")
        panel:NumSlider("Debug drawing", "sv_sandswep_ballistics_debug", 0, 4, 0)
        panel:ControlHelp("1: paths only, 2: short labels, 3: full numbers, 4: full numbers only where bullets stop")
        panel:NumSlider("Debug drawing lifetime (s)", "sv_sandswep_ballistics_debug_time", 1, 600, 0)

        ResetButton(panel, {"sv_sandswep_ballistics", "sv_sandswep_ballistics_gravity", "sv_sandswep_ballistics_min_damage",
            "sv_sandswep_penetration", "sv_sandswep_penetration_mult", "sv_sandswep_penetration_max",
            "sv_sandswep_bullet_tracers", "sv_sandswep_bullet_tracer_every", "sv_sandswep_bullet_tracer_time", "sv_sandswep_bullet_cracks", "sv_sandswep_ballistics_debug", "sv_sandswep_ballistics_debug_time"})
    end)

    spawnmenu.AddToolMenuOption("Options", CATEGORY, "sandswep_developer", "Developer", "", "", function(panel)
        panel:ClearControls()
        panel:Button("Reload base", "sandswep_reloadbase")
        panel:Button("Profile for 30 seconds", "sandswep_profile", "30")
        panel:Button("Sight editor", "sandswep_sighteditor")
        panel:Button("Hand editor", "sandswep_handeditor")
        panel:Button("Attachment editor", "sandswep_atteditor")
        panel:Button("Print pose parameters", "sandswep_posedebug")
        panel:Button("Scope image preview", "sandswep_pipdebug")
        panel:Button("Test casing", "sandswep_testshell")
        panel:CheckBox("Freeze viewmodel", "cl_sandswep_debug_freezevm")
        SequenceStepper(panel)
        if HasNVG() then
            Combo(panel, "NV scope debug stage", "cl_sandswep_nvscope_stage", {
                {"Full", "0"}, {"No lamps", "1"}, {"No image processing", "2"}, {"Nothing", "3"},
                {"Colour only", "4"}, {"+ exposure", "5"}, {"+ halo", "6"}, {"+ grain / tint", "7"},
            })
        end
    end)
end)
