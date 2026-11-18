-- Server: changing attachments

concommand.Add("sandswep_menu", function(ply, _, args)
    if not IsValid(ply) then return end

    ply.SandSwepMenuOpen = args[1] == "1"
    if not ply.SandSwepMenuOpen then return end

    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and wep.IsSandSwep and wep:IsReloading() then
        wep:InterruptReload()
        wep:PlayIdleAnim()
    end
end)

local function LoadoutWeapon(ply)
    if not IsValid(ply) then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not wep.IsSandSwep or not wep.ApplyLoadout then return end
    if wep:ActionBlocks("customize") then return end
    if (ply._sandswepAttachCD or 0) > CurTime() then return end

    ply._sandswepAttachCD = CurTime() + 0.3
    return wep
end

local function ApplyAndSave(ply, wep, att, skins)
    wep:ApplyLoadout(att, skins)
    if SandSwep.SaveSessionLoadout then SandSwep.SaveSessionLoadout(ply, wep) end
end

util.AddNetworkString("SandSwep_Loadout")
net.Receive("SandSwep_Loadout", function(_, ply)
    local att, skins = net.ReadString(), net.ReadString()
    if #att > 1024 or #skins > 512 then return end

    local wep = LoadoutWeapon(ply)
    if wep then ApplyAndSave(ply, wep, att, skins) end
end)

concommand.Add("sandswep_shuffle", function(ply)
    local wep = LoadoutWeapon(ply)
    if not wep then return end

    local parts, skins = {}, {}
    for slotName, slot in pairs(wep:GetAttachmentSlots()) do
        if slot.Hidden then continue end

        local options = {}
        for _, id in ipairs(slot.Attachments or {}) do
            if wep:CanAttach(slotName, id) then options[#options + 1] = id end
        end

        if #options == 0 or math.random() >= 0.75 then continue end

        local id = options[math.random(#options)]
        parts[#parts + 1] = slotName .. "=" .. id

        local def = SandSwep.Attachments[id]
        if def.Skins and #def.Skins > 1 then
            skins[#skins + 1] = slotName .. "=" .. (math.random(#def.Skins) - 1)
        end
    end

    ApplyAndSave(ply, wep, table.concat(parts, ";"), table.concat(skins, ";"))
end)

concommand.Add("sandswep_resetatts", function(ply)
    local wep = LoadoutWeapon(ply)
    if not wep then return end

    local parts = {}
    for slotName, slot in pairs(wep:GetAttachmentSlots()) do
        if slot.Default and wep:CanAttach(slotName, slot.Default) then
            parts[#parts + 1] = slotName .. "=" .. slot.Default
        end
    end

    ApplyAndSave(ply, wep, table.concat(parts, ";"), "")
end)

local function ClearMenuFlag(ply)
    ply.SandSwepMenuOpen = nil
end
hook.Add("PlayerSwitchWeapon", "SandSwep_MenuFlag", ClearMenuFlag)
hook.Add("PlayerDeath", "SandSwep_MenuFlag", ClearMenuFlag)
hook.Add("PlayerSpawn", "SandSwep_MenuFlag", ClearMenuFlag)

concommand.Add("sandswep_attachskin", function(ply, _, args)
    if not IsValid(ply) then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not wep.IsSandSwep or not wep.SetSlotSkin then return end
    if wep:ActionBlocks("customize") then return end

    local slot, skin = args[1], tonumber(args[2] or "")
    if not slot or not skin then return end

    local def = wep:GetSlotAttachmentDef(slot)
    if not def or not def.Skins then return end
    if skin < 0 or skin >= #def.Skins then return end

    wep:SetSlotSkin(slot, math.floor(skin))
    if SandSwep.SaveSessionLoadout then SandSwep.SaveSessionLoadout(ply, wep) end
end)

concommand.Add("sandswep_attach", function(ply, _, args)
    if not IsValid(ply) then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not wep.IsSandSwep or not wep.SetSlotAttachment then
        ply:PrintMessage(HUD_PRINTCONSOLE, "[sandswep] Hold a sandswep weapon first.")
        return
    end

    local slot, id = args[1], args[2]
    if not slot then
        local slots = table.GetKeys(wep:GetAttachmentSlots())
        table.sort(slots)
        ply:PrintMessage(HUD_PRINTCONSOLE, "[sandswep] usage: sandswep_attach <slot> <attachment|none>   slots on "
            .. wep:GetClass() .. ": " .. (#slots > 0 and table.concat(slots, ", ") or "none"))
        return
    end
    if id == "none" or id == "" then id = nil end

    if (ply._sandswepAttachCD or 0) > CurTime() then return end
    if wep:ActionBlocks("customize") then return end
    ply._sandswepAttachCD = CurTime() + 0.15

    if wep:CanAttach(slot, id) then
        wep:SetSlotAttachment(slot, id)
        if SandSwep.SaveSessionLoadout then SandSwep.SaveSessionLoadout(ply, wep) end
    else
        local slotCfg = wep:GetAttachmentSlots()[slot]
        ply:PrintMessage(HUD_PRINTCONSOLE, "[sandswep] Can't fit '" .. tostring(id) .. "' in slot '" .. slot .. "' on "
            .. wep:GetClass() .. ". Allowed: " .. (slotCfg and table.concat(slotCfg.Attachments or {}, ", ") or "(no such slot)"))
    end
end)
