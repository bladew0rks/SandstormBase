local CATEGORY = "SandSwep"

local function ResetButton(panel, label, convars)
    local button = panel:Button(label or "Reset")
    button.DoClick = function()
        for _, name in ipairs(convars) do
            local cv = GetConVar(name)
            if cv then RunConsoleCommand(name, cv:GetDefault()) end
        end
    end
end

hook.Add("AddToolMenuCategories", "SandTPIK.Category", function()
    spawnmenu.AddToolCategory("Options", CATEGORY, "Sandstorm Base")
end)

hook.Add("PopulateToolMenu", "SandTPIK.Settings", function()
    spawnmenu.AddToolMenuOption("Options", CATEGORY, "sandswep_tpik_settings", "Third Person", "", "", function(panel)
        panel:ClearControls()

        panel:CheckBox("Third person viewmodel animations", "sandswep_tpik")
        panel:CheckBox("Show on other players", "sandswep_tpik_others")
        panel:CheckBox("Muzzle flashes from the animated gun", "sandswep_tpik_effects")
        ResetButton(panel, "Reset", { "sandswep_tpik", "sandswep_tpik_others", "sandswep_tpik_effects" })

        panel:Help("Performance")
        panel:NumSlider("Draw distance (others)", "sandswep_tpik_distance", 0, 8192, 0)
        panel:NumSlider("Reduced IK rate past", "sandswep_tpik_lod_distance", 0, 4096, 0)
        panel:NumSlider("Half detail gun past", "sandswep_tpik_mesh_lod1", 0, 4096, 0)
        panel:NumSlider("Low detail gun past", "sandswep_tpik_mesh_lod2", 0, 4096, 0)
        ResetButton(panel, "Reset performance", { "sandswep_tpik_distance", "sandswep_tpik_lod_distance",
            "sandswep_tpik_mesh_lod1", "sandswep_tpik_mesh_lod2" })
    end)
end)
