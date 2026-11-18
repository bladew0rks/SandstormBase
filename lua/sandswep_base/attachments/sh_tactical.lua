hook.Add("PlayerSwitchFlashlight", "SandSwep_Tactical", function(ply, enabled)
    if not enabled then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not wep.IsSandSwep then return end

    return false
end)

hook.Add("PlayerSwitchWeapon", "SandSwep_SuitLightOff", function(ply, _, newWep)
    if SERVER and IsValid(newWep) and newWep.IsSandSwep and ply:FlashlightIsOn() then
        ply:Flashlight(false)
    end
end)

if SERVER then
    local function TacticalSound(wep, light)
        local device = light and "flashlaser" or "laser"
        local state = wep:GetTacticalOn() and "on" or "off"
        wep:EmitSound(("SandSwep.SS.%s_%s_1p"):format(device, state))
    end

    local function TacticalCommand(fnName)
        return function(ply)
            if not IsValid(ply) then return end

            local wep = ply:GetActiveWeapon()
            if not IsValid(wep) or not wep.IsSandSwep or not wep[fnName] then return end
            if (ply._sandswepTacToggleCD or 0) > CurTime() then return end
            ply._sandswepTacToggleCD = CurTime() + 0.1

            local hadLight = wep:GetLightOn()
            if wep[fnName](wep) then
                TacticalSound(wep, hadLight or wep:GetLightOn())
            else
                ply:PrintMessage(HUD_PRINTCONSOLE, "[sandswep] No device with that function fitted.")
            end
        end
    end
    concommand.Add("sandswep_laser", TacticalCommand("ToggleLaser"))
    concommand.Add("sandswep_light", TacticalCommand("ToggleLight"))
    concommand.Add("sandswep_tactical", TacticalCommand("CycleTactical"))   -- old F cycle
    concommand.Add("sandswep_tactoggle", TacticalCommand("ToggleTactical"))

    concommand.Add("sandswep_tacmode", function(ply, _, args)
        if not IsValid(ply) then return end

        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or not wep.IsSandSwep or not wep.SetTacticalMode then return end
        if (ply._sandswepTacCD or 0) > CurTime() then return end
        ply._sandswepTacCD = CurTime() + 0.03

        local wasOn, hadLight = wep:GetTacticalOn(), wep:GetLightOn()
        if wep:SetTacticalMode(args[1]) and wasOn then
            TacticalSound(wep, hadLight or wep:GetLightOn())
        end
    end)
end

local TRACER_AMMO = { SMG1 = true, AR2 = true, Pistol = true, ["357"] = true, SniperRound = true, SniperPenetratedRound = true }

hook.Add("PreRegisterSWEP", "SandSwep_TracerAmmo", function(swep)
    local slots, primary = swep.AttachmentSlots, swep.Primary
    if not istable(slots) or slots.ammo or not istable(primary) then return end
    if not TRACER_AMMO[primary.Ammo] or (primary.NumShots or 1) > 1 then return end

    slots.ammo = {
        Name = "Ammo",
        NoneName = "Ball",
        Attachments = { "ammo_tracer" },
        MenuAnchor = "b_wpn",
    }
    swep.TracerAmmo = true
end)

hook.Add("PreRegisterSWEP", "SandSwep_GLSecondaryAmmo", function(swep, class)
    if not istable(swep.AttachmentSlots) then return end

    for _, slot in pairs(swep.AttachmentSlots) do
        for _, id in ipairs(slot.Attachments or {}) do
            local def = SandSwep.Attachments[id]
            if def and def.GL then
                local ammo = (istable(def.GL) and def.GL.Ammo) or "SMG1_Grenade"
                swep.Secondary = { ClipSize = 1, DefaultClip = 0, Ammo = ammo, Automatic = false }
                return
            end
        end
    end
end)
