local Internal = SandSwep.AttInternal
local COL_TEXT, COL_DIM, COL_ROW, COL_ROW_HI = Internal.COL_TEXT, Internal.COL_DIM, Internal.COL_ROW, Internal.COL_ROW_HI
local COL_ROW_OFF, COL_OFF, COL_RED = Internal.COL_ROW_OFF, Internal.COL_OFF, Internal.COL_RED
local SpacedWidth, DrawSpaced, Truncate = Internal.SpacedWidth, Internal.DrawSpaced, Internal.Truncate
local BuildPreview = Internal.BuildPreview

local TOP_SLOTS      = { optic = true, muzzle = true, barrel = true, frontsight = true, sight = true, finish = true }
local MENU_MAX_ROWS  = 10

local function CollectSlotEntries(wep, slots)
    local names = table.GetKeys(slots)
    table.sort(names)

    local entries, byGroup = {}, {}
    for _, slotName in ipairs(names) do
        local slot = slots[slotName]
        if slot.Hidden or (slot.RequiresSlot and not wep:GetSlotAttachment(slot.RequiresSlot)) then continue end

        if slot.Group then
            local entry = byGroup[slot.Group]
            if not entry then
                entry = { key = slot.Group, tabs = {} }
                byGroup[slot.Group] = entry
                entries[#entries + 1] = entry
            end
            entry.tabs[#entry.tabs + 1] = slotName
        else
            entries[#entries + 1] = { key = slotName, tabs = { slotName } }
        end
    end
    for _, entry in ipairs(entries) do
        table.sort(entry.tabs, function(a, b) return (slots[a].GroupOrder or 0) < (slots[b].GroupOrder or 0) end)
    end

    return entries
end

local function ChooseActiveTab(frame, wep, slots, entry)
    local active = frame.groupTab[entry.key]
    if not active or not slots[active] then
        for _, tabName in ipairs(entry.tabs) do
            if wep:GetSlotAttachment(tabName) then
                active = tabName
                break
            end
        end
        if not active then
            for _, tabName in ipairs(entry.tabs) do
                if slots[tabName].GroupDefault then
                    active = tabName
                    break
                end
            end
        end
        active = active or entry.tabs[1]
    end

    return active
end

local function CountSlotOptions(slots, entry)
    local maxRows, maxSkins = 0, 0
    for _, tabName in ipairs(entry.tabs) do
        local count = 0
        for _, id in ipairs(slots[tabName].Attachments or {}) do
            local def = SandSwep.Attachments[id]
            if def then
                count = count + 1
                if def.Skins and #def.Skins > maxSkins then maxSkins = #def.Skins end
            end
        end
        maxRows = math.max(maxRows, count)
    end

    return maxRows, maxSkins
end

local function AddGroupTabs(ctx, entry, group, tabPanels, ActiveSlot, headH)
    local frame, wep, scale, slots = ctx.frame, ctx.wep, ctx.scale, ctx.slots
    local rowW, rowH, gap = ctx.rowW, ctx.rowH, ctx.gap

    local tabW = math.floor((rowW - gap * (#entry.tabs - 1)) / #entry.tabs)
    for tabIndex, slotName in ipairs(entry.tabs) do
        local slot = slots[slotName]
        local tab = vgui.Create("DButton", group)
        tab:SetText("")
        tab:SetTooltip(slot.Name or slotName)
        tab:SetPos(math.Round(34 * scale) + (tabIndex - 1) * (tabW + gap), headH)
        tab:SetSize(tabW, rowH)
        tab.Paint = function(self, w, h)
            local on = ActiveSlot() == slotName
            surface.SetDrawColor(on and COL_RED or (self:IsHovered() and COL_ROW_HI or COL_ROW))
            surface.DrawRect(0, 0, w, h)

            local label = string.upper(slot.GroupTab or slotName)
            local fitted = IsValid(wep) and wep:GetSlotAttachment(slotName)
            local labelW = SpacedWidth(label, "SandAtt_Item", math.Round(3 * scale))
            DrawSpaced(label, "SandAtt_Item", (w - labelW) / 2, (h - draw.GetFontHeight("SandAtt_Item")) / 2,
                (on or fitted) and COL_TEXT or COL_DIM, math.Round(3 * scale))

            if fitted and not on then          -- something is mounted here
                surface.SetDrawColor(COL_RED.r, COL_RED.g, COL_RED.b, COL_RED.a)
                surface.DrawRect(w - math.Round(7 * scale), math.Round(3 * scale), math.Round(4 * scale), math.Round(4 * scale))
            end
        end
        tab.DoClick = function()
            frame.groupTab[entry.key] = slotName
            group.slotName, group.slot, group.anchorSlot = slotName, slot, slotName
            for tabName, list in pairs(tabPanels) do
                for _, pnl in ipairs(list) do
                    if IsValid(pnl) then pnl:SetVisible(tabName == slotName) end
                end
            end
            SandSwep.UISound("ui_navigate")
        end
    end
end

local function AddSkinButtons(ctx, canvas, slotName, id, def, y)
    local wep, scale = ctx.wep, ctx.scale
    local rowW, rowH, gap = ctx.rowW, ctx.rowH, ctx.gap

    for skinIdx, skin in ipairs(def.Skins or {}) do
        if #def.Skins < 2 then break end

        local skinBtn = vgui.Create("DButton", canvas)
        skinBtn:SetText("")
        skinBtn:SetTooltip(skin.Name)
        skinBtn:SetPos(math.Round(34 * scale) + rowW + gap + (skinIdx - 1) * (rowH + gap), y)
        skinBtn:SetSize(rowH, rowH)
        skinBtn.Paint = function(self, w, h)
            if not IsValid(wep) or not wep.GetSlotSkin then return end
            if wep:GetSlotAttachment(slotName) ~= id then return end

            local chosen = wep:GetSlotSkin(slotName) == skinIdx - 1
            surface.SetDrawColor(self:IsHovered() and COL_ROW_HI or COL_ROW)
            surface.DrawRect(0, 0, w, h)

            local inset = math.Round(w * 0.22)
            surface.SetDrawColor(skin.Color or color_white)
            surface.DrawRect(inset, inset, w - inset * 2, h - inset * 2)

            if chosen then
                surface.SetDrawColor(COL_RED.r, COL_RED.g, COL_RED.b, COL_RED.a)
                surface.DrawOutlinedRect(0, 0, w, h, math.max(1, math.Round(2 * scale)))
            end
        end
        skinBtn.DoClick = function()
            if not IsValid(wep) or wep:GetSlotAttachment(slotName) ~= id then return end
            RunConsoleCommand("sandswep_attachskin", slotName, tostring(skinIdx - 1))
            SandSwep.UISound("ui_select")
        end
    end
end

local function AddOptionRow(ctx, canvas, slotName, id, def, y)
    local wep, scale = ctx.wep, ctx.scale
    local rowW, rowH = ctx.rowW, ctx.rowH

    local btn = vgui.Create("DButton", canvas)
    btn:SetText("")
    btn:SetPos(math.Round(34 * scale), y)
    btn:SetSize(rowW, rowH)
    local function Blocked()
        if not IsValid(wep) or not wep.GetAttachBlock then return nil end
        if wep:GetSlotAttachment(slotName) == id then return nil end
        return wep:GetAttachBlock(slotName, id)
    end
    btn.Think = function(self)
        local reason = Blocked()
        if reason ~= self.blockReason then
            self.blockReason = reason
            self:SetTooltip(reason or false)
        end
    end
    btn.Paint = function(self, w, h)
        if not IsValid(wep) or not wep.GetSlotAttachment then return end

        local fitted = wep:GetSlotAttachment(slotName) == id
        local blocked = self.blockReason ~= nil
        surface.SetDrawColor(blocked and COL_ROW_OFF or (self:IsHovered() and COL_ROW_HI or COL_ROW))
        surface.DrawRect(0, 0, w, h)

        local name = Truncate(string.upper(def.Name or id), "SandAtt_Item", math.Round(3 * scale), w - math.Round(20 * scale))
        DrawSpaced(name, "SandAtt_Item", math.Round(8 * scale), (h - draw.GetFontHeight("SandAtt_Item")) / 2,
            fitted and COL_TEXT or (blocked and COL_OFF or COL_DIM), math.Round(3 * scale))
    end
    btn.DoClick = function()
        if not IsValid(wep) then return end
        if Blocked() then
            SandSwep.UISound("ui_remove")
            return
        end

        local fitted = wep:GetSlotAttachment(slotName) == id
        RunConsoleCommand("sandswep_attach", slotName, fitted and "none" or id)
        SandSwep.UISound(fitted and "ui_remove" or "ui_attach")
    end

    local removeBtn = vgui.Create("DButton", canvas)
    removeBtn:SetText("")
    removeBtn:SetPos(math.Round(6 * scale), y)
    removeBtn:SetSize(rowH, rowH)
    removeBtn.Paint = function(self, w, h)
        if not IsValid(wep) or wep:GetSlotAttachment(slotName) ~= id then return end

        surface.SetDrawColor(self:IsHovered() and Color(225, 70, 52) or COL_RED)
        surface.DrawRect(0, 0, w, h)

        surface.SetDrawColor(COL_TEXT.r, COL_TEXT.g, COL_TEXT.b, COL_TEXT.a)
        local inset = math.Round(w * 0.28)
        surface.DrawLine(inset, inset, w - inset, h - inset)
        surface.DrawLine(w - inset, inset, inset, h - inset)
    end
    removeBtn.DoClick = function()
        if not IsValid(wep) or wep:GetSlotAttachment(slotName) ~= id then return end
        RunConsoleCommand("sandswep_attach", slotName, "none")
        SandSwep.UISound("ui_remove")
    end

    AddSkinButtons(ctx, canvas, slotName, id, def, y)
end

local function AddSlotList(ctx, group, slotName, top, visRows, active, tabPanels)
    local frame, wep, scale, slots = ctx.frame, ctx.wep, ctx.scale, ctx.slots
    local rowH, gap = ctx.rowH, ctx.gap

    local slot = slots[slotName]
    local scroller = vgui.Create("DScrollPanel", group)
    scroller:SetPos(0, top)
    scroller:SetSize(group:GetWide(), visRows * (rowH + gap))

    local vbar = scroller:GetVBar()
    vbar:SetWide(math.Round(4 * scale))
    vbar:SetHideButtons(true)
    vbar.Paint = function(self, w, h)
        surface.SetDrawColor(COL_ROW.r, COL_ROW.g, COL_ROW.b, COL_ROW.a)
        surface.DrawRect(0, 0, w, h)
    end
    vbar.btnGrip.Paint = function(self, w, h)
        surface.SetDrawColor(COL_RED.r, COL_RED.g, COL_RED.b, COL_RED.a)
        surface.DrawRect(0, 0, w, h)
    end
    scroller.Think = function(self) frame.scroll[slotName] = self:GetVBar():GetScroll() end

    local canvas = scroller:GetCanvas()
    local list = { scroller }
    tabPanels[slotName] = list

    local options = {}
    for _, id in ipairs(slot.Attachments or {}) do
        if SandSwep.Attachments[id] then options[#options + 1] = id end
    end

    local fittedRow
    for i, id in ipairs(options) do
        local def = SandSwep.Attachments[id]
        local y = (i - 1) * (rowH + gap)
        if wep:GetSlotAttachment(slotName) == id then fittedRow = i end

        AddOptionRow(ctx, canvas, slotName, id, def, y)
    end

    scroller:InvalidateLayout(true)
    local saved = frame.scroll[slotName]
    if not saved and fittedRow and fittedRow > visRows then
        saved = (fittedRow - math.ceil(visRows / 2)) * (rowH + gap)
    end
    vbar:SetScroll(saved or 0)

    for _, pnl in ipairs(list) do pnl:SetVisible(slotName == active) end
end

local function BuildSlotGroup(ctx, entry)
    local frame, wep, scale, slots = ctx.frame, ctx.wep, ctx.scale, ctx.slots
    local rowW, rowH, gap = ctx.rowW, ctx.rowH, ctx.gap

    local grouped = #entry.tabs > 1 or slots[entry.tabs[1]].Group ~= nil
    local active = ChooseActiveTab(frame, wep, slots, entry)
    frame.groupTab[entry.key] = active

    local maxRows, maxSkins = CountSlotOptions(slots, entry)

    local headH = math.Round(34 * scale)
    local tabH = grouped and (rowH + gap) or 0
    local skinW = maxSkins > 1 and maxSkins * (rowH + gap) + gap or 0
    local visRows = math.min(maxRows, MENU_MAX_ROWS)
    local barW = maxRows > visRows and math.Round(4 * scale) + gap or 0

    local group = vgui.Create("DPanel", frame)
    group:SetSize(rowW + math.Round(34 * scale) + skinW + barW, headH + tabH + visRows * (rowH + gap))
    local function ActiveSlot() return frame.groupTab[entry.key] or active end
    group.slotName, group.slot, group.anchorSlot = active, slots[active], active
    group.top = group.slot.MenuSide and group.slot.MenuSide == "top"
        or (group.slot.MenuSide == nil and TOP_SLOTS[entry.key])
    group.Paint = function(self, w, h)
        local slotName = ActiveSlot()
        local slot = slots[slotName]
        local title = string.upper(grouped and (slot.GroupName or entry.key) or (slot.Name or slotName))
        DrawSpaced(title, "SandAtt_Slot", math.Round(22 * scale), 0, COL_TEXT, 1)

        local cur = IsValid(wep) and wep.GetSlotAttachment and wep:GetSlotAttachment(slotName)
        if not cur then
            local fallback = slot.Fallback and SandSwep.Attachments[slot.Fallback]
            local none = string.upper(slot.NoneName or (fallback and fallback.Name) or "None")
            local titleW = math.Round(22 * scale) + SpacedWidth(title, "SandAtt_Slot", 1)
            if titleW + SpacedWidth(none, "SandAtt_Small", 1) + 12 * scale < w then
                DrawSpaced(none, "SandAtt_Small", w - math.Round(4 * scale), math.Round(9 * scale), COL_DIM, 1, true)
            end
        end
    end

    local tabPanels = {}
    if grouped then AddGroupTabs(ctx, entry, group, tabPanels, ActiveSlot, headH) end

    local top = headH + tabH
    frame.scroll = frame.scroll or {}
    for _, slotName in ipairs(entry.tabs) do
        AddSlotList(ctx, group, slotName, top, visRows, active, tabPanels)
    end

    frame.groups[entry.key] = group
end

local function RebuildSlots(st)
    local frame, wep, preview, scale = st.frame, st.wep, st.preview, st.scale
    if not IsValid(frame) or not IsValid(wep) then return end

    BuildPreview(preview, wep)
    for _, group in pairs(frame.groups) do
        if IsValid(group) then group:Remove() end
    end
    frame.groups = {}

    local slots = wep:GetAttachmentSlots()
    local rowW, rowH, gap = math.Round(250 * scale), math.Round(24 * scale), math.Round(4 * scale)

    local entries = CollectSlotEntries(wep, slots)
    frame.groupTab = frame.groupTab or {}

    local ctx = { frame = frame, wep = wep, scale = scale, slots = slots, rowW = rowW, rowH = rowH, gap = gap }
    for _, entry in ipairs(entries) do
        BuildSlotGroup(ctx, entry)
    end

    frame.lastKey = wep:GetAttData() .. "|" .. (wep.GetAttSkins and wep:GetAttSkins() or "")
    frame.layoutDone = false
end

Internal.RebuildSlots = RebuildSlots
