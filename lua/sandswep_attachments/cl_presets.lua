local Internal = SandSwep.AttInternal
local COL_TEXT, COL_DIM, COL_ROW, COL_ROW_HI = Internal.COL_TEXT, Internal.COL_DIM, Internal.COL_ROW, Internal.COL_ROW_HI
local COL_RED, COL_LINE = Internal.COL_RED, Internal.COL_LINE
local DrawSpaced, Truncate = Internal.DrawSpaced, Internal.Truncate
local MenuButton, CrossIcon = Internal.MenuButton, Internal.CrossIcon

local PRESET_DIR = "sandswep/presets"
local SPAWN_FILE = PRESET_DIR .. "/_spawn.json"
local CODE_PREFIX = "SSW1:"

local function PresetPath(class)
    return PRESET_DIR .. "/" .. class .. ".json"
end

local function ReadJSON(path)
    local raw = file.Read(path, "DATA")
    local data = raw and util.JSONToTable(raw)
    return istable(data) and data or {}
end

local function WriteJSON(path, data)
    file.CreateDir(PRESET_DIR)
    file.Write(path, util.TableToJSON(data, true))
end

local function LoadPresets(class)
    local raw = ReadJSON(PresetPath(class))
    local keys = table.GetKeys(raw)
    table.sort(keys, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)

    local out = {}
    for _, k in ipairs(keys) do
        local preset = raw[k]
        if istable(preset) and isstring(preset.att) then
            local name = isstring(preset.name) and preset.name ~= "" and preset.name or ("Preset " .. (#out + 1))
            out[#out + 1] = {
                name = name,
                att = preset.att,
                skins = isstring(preset.skins) and preset.skins or "",
            }
        end
    end

    return out
end

local function SavePresets(class, list)
    WriteJSON(PresetPath(class), list)
end

local function LoadSpawn()
    return ReadJSON(SPAWN_FILE)
end

local function SendSpawnPreset(class)
    local name = LoadSpawn()[class]
    local found
    if isstring(name) then
        for _, preset in ipairs(LoadPresets(class)) do
            if preset.name == name then
                found = preset
                break
            end
        end
    end

    net.Start("SandSwep_SpawnPreset")
    net.WriteString(class)
    net.WriteBool(found ~= nil)
    if found then
        net.WriteString(found.att)
        net.WriteString(found.skins)
    end
    net.SendToServer()
end

local function SetSpawn(class, name)
    local spawns = LoadSpawn()
    spawns[class] = name
    WriteJSON(SPAWN_FILE, spawns)

    SendSpawnPreset(class)
end

hook.Add("InitPostEntity", "SandSwep_SpawnPresets", function()
    for class in pairs(LoadSpawn()) do SendSpawnPreset(class) end
end)

local function EncodeCode(class, att, skins)
    return CODE_PREFIX .. util.Base64Encode(class .. "|" .. att .. "|" .. skins, true)
end

local function DecodeCode(code)
    code = string.Trim(code or "")
    if string.sub(code, 1, #CODE_PREFIX) ~= CODE_PREFIX then return end

    local raw = util.Base64Decode(string.sub(code, #CODE_PREFIX + 1))
    if not raw then return end

    return string.match(raw, "^([^|]*)|([^|]*)|([^|]*)$")
end

local function SendLoadout(att, skins)
    net.Start("SandSwep_Loadout")
    net.WriteString(att or "")
    net.WriteString(skins or "")
    net.SendToServer()
end

local function PresetLabel(preset)
    local optic, extra = nil, 0
    for slot, id in string.gmatch(preset.att or "", "([%w_]+)=([%w_]+)") do
        local def = SandSwep.Attachments[id]
        if def then
            if slot == "optic" then
                optic = def.Name or id
            else
                extra = extra + 1
            end
        end
    end

    local label = optic or "IRONS"
    if extra > 0 then label = label .. " +" .. extra end

    return string.upper(label)
end

local function PresetTooltip(preset)
    local lines = {}
    for _, id in string.gmatch(preset.att or "", "([%w_]+)=([%w_]+)") do
        local def = SandSwep.Attachments[id]
        if def then lines[#lines + 1] = def.Name or id end
    end

    return #lines > 0 and table.concat(lines, "\n") or "No attachments"
end

local function ClosePresets(st)
    if IsValid(st.presetPanel) then st.presetPanel:Remove() end
    st.presetPanel = nil

    local frame = st.frame
    if not IsValid(frame) then return end

    frame.pinned = nil
    frame:SetMouseInputEnabled(true)

    local bind = input.LookupBinding("+menu_context")
    local code = bind and input.GetKeyCode(bind)
    if not (code and code > 0 and input.IsButtonDown(code)) then SandSwep.CloseAttachMenu() end
end

local function Flash(panel, text)
    panel.flash, panel.flashT = text, RealTime()
end

local function RefreshPresetCombo(ps)
    local combo, class, list = ps.combo, ps.class, ps.list

    ps.refreshing = true
    combo:Clear()

    local cur = LoadSpawn()[class]
    local found = false
    for _, preset in ipairs(list) do
        if preset.name == cur then found = true end
    end
    if cur and not found then
        SetSpawn(class, nil)
        cur = nil
    end

    combo:AddChoice("NONE", false, cur == nil)
    for _, preset in ipairs(list) do combo:AddChoice(string.upper(preset.name), preset.name, preset.name == cur) end
    ps.refreshing = false
end

local function RefreshPresetList(ps)
    local wep, class, list, scroller, scale = ps.wep, ps.class, ps.list, ps.scroller, ps.scale
    local btnGap = ps.st.btnGap

    scroller:Clear()
    local rowH = math.Round(34 * scale)
    for i, preset in ipairs(list) do
        local row = vgui.Create("DButton", scroller)
        row:SetText("")
        row:Dock(TOP)
        row:DockMargin(0, 0, math.Round(8 * scale), btnGap)
        row:SetTall(rowH)
        row:SetTooltip(PresetTooltip(preset))
        row.Paint = function(self, w, h)
            surface.SetDrawColor(self:IsHovered() and COL_ROW_HI or COL_ROW)
            surface.DrawRect(0, 0, w, h)

            if IsValid(wep) and preset.att == wep:GetAttData() and preset.skins == (wep:GetAttSkins() or "") then
                surface.SetDrawColor(COL_RED.r, COL_RED.g, COL_RED.b, COL_RED.a)
                surface.DrawRect(0, 0, math.Round(4 * scale), h)
            end

            local spacing = math.Round(2 * scale)
            local name = Truncate(string.upper(preset.name), "SandAtt_Item", spacing, w * 0.55)
            DrawSpaced(name, "SandAtt_Item", math.Round(12 * scale), (h - draw.GetFontHeight("SandAtt_Item")) / 2, COL_TEXT, spacing)

            local right = w - h - math.Round(8 * scale)
            local label = Truncate(PresetLabel(preset), "SandAtt_Small", spacing, w * 0.4 - h)
            DrawSpaced(label, "SandAtt_Small", right, (h - draw.GetFontHeight("SandAtt_Small")) / 2, COL_DIM, spacing, true)
        end
        row.DoClick = function()
            SendLoadout(preset.att, preset.skins)
            SandSwep.UISound("ui_attach")
        end

        local del = vgui.Create("DButton", row)
        del:SetText("")
        del:Dock(RIGHT)
        del:SetWide(rowH)
        del:SetTooltip("Delete preset")
        del.Paint = function(self, w, h)
            if self:IsHovered() then
                surface.SetDrawColor(COL_RED.r, COL_RED.g, COL_RED.b, COL_RED.a)
                surface.DrawRect(0, 0, w, h)
            end
            CrossIcon(w, h, self:IsHovered() and COL_TEXT or COL_DIM)
        end
        del.DoClick = function()
            table.remove(list, i)
            SavePresets(class, list)
            SandSwep.UISound("ui_remove")
            RefreshPresetList(ps)
        end
    end
    RefreshPresetCombo(ps)
end

local function SavePresetAs(ps, name)
    local wep, class, list = ps.wep, ps.class, ps.list
    if not IsValid(wep) then return end

    name = string.sub(string.Trim(name or ""), 1, 48)
    if name == "" then name = PresetLabel({ att = wep:GetAttData() }) end

    local entry = { name = name, att = wep:GetAttData(), skins = wep:GetAttSkins() or "" }
    local replaced
    for i, preset in ipairs(list) do
        if preset.name == name then
            list[i] = entry
            replaced = true
            break
        end
    end
    if not replaced then list[#list + 1] = entry end

    SavePresets(class, list)
    if LoadSpawn()[class] == name then SendSpawnPreset(class) end

    SandSwep.UISound("ui_select")
    Flash(ps.panel, replaced and "PRESET UPDATED" or "PRESET SAVED")
    RefreshPresetList(ps)
end

local function AddPresetActions(ps)
    local st, wep, panel, scale = ps.st, ps.wep, ps.panel, ps.scale
    local panelW, pad, inner, closeSz = ps.panelW, ps.pad, ps.inner, ps.closeSz
    local btnH, btnGap = st.btnH, st.btnGap

    local close = vgui.Create("DButton", panel)
    close:SetText("")
    close:SetPos(panelW - pad - closeSz, pad)
    close:SetSize(closeSz, closeSz)
    close.Paint = function(self, w, h)
        surface.SetDrawColor(self:IsHovered() and COL_ROW_HI or COL_ROW)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(COL_LINE.r, COL_LINE.g, COL_LINE.b, COL_LINE.a)
        surface.DrawOutlinedRect(0, 0, w, h)
        CrossIcon(w, h, COL_TEXT)
    end
    close.DoClick = function() ClosePresets(st) end

    local y = pad + closeSz + math.Round(14 * scale)
    local half = math.floor((inner - btnGap) / 2)
    MenuButton(scale, panel, "COPY CODE", pad, y, half, btnH, function()
        if not IsValid(wep) then return end
        SetClipboardText(EncodeCode(wep:GetClass(), wep:GetAttData(), wep:GetAttSkins() or ""))
        SandSwep.UISound("ui_select")
        Flash(panel, "CODE COPIED")
    end)
    MenuButton(scale, panel, "PASTE CODE", pad + half + btnGap, y, half, btnH, function()
        Derma_StringRequest("Paste code", "Paste a sandswep attachment code", "", function(text)
            local _, att, skins = DecodeCode(text)
            if not att then
                if IsValid(panel) then Flash(panel, "INVALID CODE") end
                return
            end

            SendLoadout(att, skins)
            SandSwep.UISound("ui_attach")
        end)
    end)
    y = y + btnH + btnGap

    MenuButton(scale, panel, "+  SAVE CURRENT SETUP", pad, y, inner, btnH, function()
        if not IsValid(wep) then return end
        Derma_StringRequest("Save preset", "Preset name (an existing name gets overwritten)", PresetLabel({ att = wep:GetAttData() }),
            function(text) if IsValid(panel) then SavePresetAs(ps, text) end end)
    end, function() return true end)

    return y + btnH + math.Round(14 * scale)
end

local function AddPresetBrowser(ps, y, footerY)
    local panel, class, scale = ps.panel, ps.class, ps.scale
    local pad, inner, btnH = ps.pad, ps.inner, ps.st.btnH

    local scroller = vgui.Create("DScrollPanel", panel)
    scroller:SetPos(pad, y)
    scroller:SetSize(inner, footerY - pad - y)
    ps.scroller = scroller

    local vbar = scroller:GetVBar()
    vbar:SetWide(math.Round(4 * scale))
    vbar:SetHideButtons(true)
    vbar.Paint = function() end
    vbar.btnGrip.Paint = function(_, w, h)
        surface.SetDrawColor(COL_LINE.r, COL_LINE.g, COL_LINE.b, COL_LINE.a)
        surface.DrawRect(0, 0, w, h)
    end

    local labelW = math.Round(150 * scale)
    local combo = vgui.Create("DComboBox", panel)
    combo:SetPos(pad + labelW, footerY)
    combo:SetSize(inner - labelW, btnH)
    combo:SetFont("SandAtt_Item")
    combo:SetTextColor(COL_TEXT)
    combo.Paint = function(_, w, h)
        surface.SetDrawColor(COL_ROW.r, COL_ROW.g, COL_ROW.b, COL_ROW.a)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(COL_ROW_HI.r, COL_ROW_HI.g, COL_ROW_HI.b, COL_ROW_HI.a)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
    ps.combo = combo

    ps.refreshing = false
    combo.OnSelect = function(_, _, _, data)
        if ps.refreshing then return end
        SetSpawn(class, data or nil)
        SandSwep.UISound("ui_select")
    end
end

local function OpenPresets(st)
    if IsValid(st.presetPanel) then
        ClosePresets(st)
        return
    end

    local frame, wep, scale, btnH = st.frame, st.wep, st.scale, st.btnH
    if not IsValid(wep) then return end

    frame.pinned = true
    frame:SetMouseInputEnabled(false)

    local class = wep:GetClass()
    local list = LoadPresets(class)
    local panelW, panelH = math.Round(ScrW() * 0.33), math.Round(ScrH() * 0.92)
    local pad = math.Round(16 * scale)
    local inner = panelW - pad * 2
    local closeSz = math.Round(30 * scale)

    local panel = vgui.Create("DPanel")
    st.presetPanel = panel
    panel:MakePopup()
    panel:SetPos(math.Round(ScrW() * 0.635), math.Round(ScrH() * 0.04))
    panel:SetSize(panelW, panelH)

    local ps = {
        st = st, wep = wep, scale = scale, class = class, list = list, panel = panel,
        panelW = panelW, pad = pad, inner = inner, closeSz = closeSz,
    }

    local y = AddPresetActions(ps)
    local sepY = y - math.Round(7 * scale)

    local footerY = panelH - pad - btnH
    AddPresetBrowser(ps, y, footerY)
    RefreshPresetList(ps)

    panel.Paint = function(_, w, h)
        surface.SetDrawColor(14, 14, 14, 240)
        surface.DrawRect(0, 0, w, h)
        DrawSpaced("PRESETS", "SandAtt_Slot", pad, pad, COL_TEXT, 1)

        if panel.flash and RealTime() - panel.flashT < 2 then
            DrawSpaced(panel.flash, "SandAtt_Small", w - pad - closeSz - math.Round(12 * scale), pad + math.Round(9 * scale), COL_DIM, 2, true)
        end

        surface.SetDrawColor(COL_LINE.r, COL_LINE.g, COL_LINE.b, COL_LINE.a)
        surface.DrawRect(pad, sepY, inner, math.max(1, math.Round(scale)))
        if #list == 0 then
            DrawSpaced("NO PRESETS YET", "SandAtt_Small", pad, sepY + math.Round(16 * scale), COL_DIM, 2)
        end

        DrawSpaced("SPAWN WITH:", "SandAtt_Item", pad, footerY + (btnH - draw.GetFontHeight("SandAtt_Item")) / 2, COL_TEXT, math.Round(2 * scale))
    end
end

Internal.OpenPresets = OpenPresets
