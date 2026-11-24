local VisualFrameTime = SandSwep.VisualFrameTime

local cvKey  = CreateClientConVar("cl_sandswep_key_tactical", "", true, false,
    "Laser / light key (empty = flashlight bind)")
local cvHold = CreateClientConVar("cl_sandswep_tacmenu_hold", "0.22", true, false,
    "Hold time for the laser / light menu", 0.05, 1)

local UI = include("sandswep_base/ui/cl_ui.lua")
local COL_TEXT, COL_DIM, COL_BG, COL_BG_HI = UI.COL_TEXT, UI.COL_DIM, UI.COL_BG, UI.COL_BG_HI
local COL_BG_SEL, COL_OUTLINE, COL_RED, COL_CROSS = UI.COL_BG_SEL, UI.COL_OUTLINE, UI.COL_RED, UI.COL_CROSS
local S, SpacedWidth, DrawSpaced, DrawCentered, ThickLine = UI.S, UI.SpacedWidth, UI.DrawSpaced, UI.DrawCentered, UI.ThickLine

local matLaser = Material("models/weapons/sandswep/hud/tac_laser")
local matLight = Material("models/weapons/sandswep/hud/tac_light")

local LASER, LIGHT, VIS, IR, ILLUM = 1, 2, 4, 8, 16
local MAIN, SUB = 3, 28

local MAINS = {
    { bit = LASER, label = "LASER", icon = matLaser },
    { bit = LIGHT, label = "LIGHT", icon = matLight },
}
local SUBS = {
    { bit = VIS,   label = "VIS LASER", short = "VIS" },
    { bit = IR,    label = "IR LASER",  short = "IR" },
    { bit = ILLUM, label = "IR ILLUM",  short = "ILLUM" },
}

SandSwep = SandSwep or {}

local fontKey
local function Fonts()
    local key = ScrH() .. "_" .. S(100)
    if fontKey == key then return end
    fontKey = key

    surface.CreateFont("SandTac_Title", { font = "Roboto Condensed", size = S(24), weight = 800 })
    surface.CreateFont("SandTac_Label", { font = "Roboto", size = S(14), weight = 700 })
    surface.CreateFont("SandTac_Small", { font = "Roboto", size = S(13), weight = 600 })
    UI.ResetWidths()
end

local function Has(mask, flag) return bit.band(mask, flag) ~= 0 end

local function HasIR() return SandSwep.IR ~= nil end

local function ActiveDevice()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not wep.IsSandSwep or not wep.GetTacticalCaps then return end

    return wep
end

local keyCode, keyCodeUntil = KEY_F, 0
cvars.AddChangeCallback("cl_sandswep_key_tactical", function() keyCodeUntil = 0 end, "SandSwep_TacKey")
local function KeyCode()
    if RealTime() < keyCodeUntil then return keyCode end
    keyCodeUntil = RealTime() + 1

    local name = string.Trim(cvKey:GetString())
    if name == "" then name = input.LookupBinding("impulse 100") or "f" end

    local code = input.GetKeyCode(name)
    if not code or code <= 0 then code = KEY_F end

    keyCode = code
    return code
end

local function Clean(mask, caps)
    mask = bit.band(mask, caps)

    local sub = bit.band(mask, SUB)
    if bit.band(sub, VIS + IR) == VIS + IR then sub = sub - VIS end
    if Has(mask, LASER) and sub == 0 then sub = bit.band(VIS, caps) end

    return bit.bor(bit.band(mask, MAIN), sub)
end

-- Menu

if IsValid(SandSwep_TacMenu) then SandSwep_TacMenu:Remove() end
SandSwep_TacMenu = nil

local menu
local wasDown, downAt = false, nil

local function Flush(panel, force)
    if not panel.dirty then return end

    local wait = (panel.nextSend or 0) - RealTime()
    if wait > 0 and not force then return end

    panel.dirty = false
    panel.nextSend = RealTime() + math.max(wait, 0) + 0.06

    local cmd = tostring(bit.bor(panel.sel, 32))   -- 32: picked by the player
    if wait > 0 then
        timer.Simple(wait, function() RunConsoleCommand("sandswep_tacmode", cmd) end)
    else
        RunConsoleCommand("sandswep_tacmode", cmd)
    end
end

local function CloseMenu()
    if IsValid(menu) then
        Flush(menu, true)
        menu:Remove()
    end

    menu = nil
    SandSwep_TacMenu = nil
end

local function OpenMenu(wep)
    CloseMenu()
    Fonts()

    local panel = vgui.Create("DPanel")
    menu = panel
    SandSwep_TacMenu = panel

    panel:SetPos(0, 0)
    panel:SetSize(ScrW(), ScrH())
    panel:MakePopup()
    panel:SetKeyboardInputEnabled(false)

    panel.wep = wep
    panel.opened = RealTime()
    panel.sel = wep:GetTacticalMode()
    panel.branch = 0                       -- 0..1 laser modes branched out
    panel.branchUntil = 0
    input.SetCursorPos(ScrW() / 2, ScrH() / 2)

    function panel:Layout()
        local caps = IsValid(self.wep) and self.wep:GetTacticalCaps() or 0
        local tileW, tileH, gap = S(150), S(132), S(10)
        local total = #MAINS * tileW + (#MAINS - 1) * gap
        local x0, y0 = math.Round(ScrW() / 2 - total / 2), math.Round(ScrH() / 2 - tileH / 2)

        local layout = { caps = caps, x0 = x0, y0 = y0, total = total, th = tileH, mains = {}, subs = {} }
        for i, opt in ipairs(MAINS) do
            layout.mains[i] = { opt = opt, kind = "main", ok = Has(caps, opt.bit),
                x = x0 + (i - 1) * (tileW + gap), y = y0, w = tileW, h = tileH }
        end

        local laserTile = layout.mains[1]
        local subW, subH, subGap = S(150), S(36), S(9)
        local colH = #SUBS * subH + (#SUBS - 1) * subGap
        local subX = laserTile.x - S(48) - subW
        local subY = math.Round(laserTile.y + laserTile.h / 2 - colH / 2)

        for i, opt in ipairs(SUBS) do
            layout.subs[i] = { opt = opt, kind = "sub", ok = Has(caps, opt.bit),
                x = subX, y = subY + (i - 1) * (subH + subGap), w = subW, h = subH }
        end

        layout.branchZone = { x = subX - S(12), y = subY - S(12), w = laserTile.x - subX + S(12), h = colH + S(24) }
        return layout
    end

    local function In(rect, mx, my)
        return mx >= rect.x and mx < rect.x + rect.w and my >= rect.y and my < rect.y + rect.h
    end

    function panel:HoveredItem(layout)
        layout = layout or self:Layout()
        local mx, my = input.GetCursorPos()

        for _, tile in ipairs(layout.mains) do
            if In(tile, mx, my) then return tile end
        end

        if self.branch > 0.5 then
            for _, tile in ipairs(layout.subs) do
                if In(tile, mx, my) then return tile end
            end
        end
    end

    function panel:Think()
        if not IsValid(self.wep) then return end

        local layout = self:Layout()
        local mx, my = input.GetCursorPos()

        local laserOk = layout.mains[1].ok
        local inZone = laserOk and HasIR()
            and (In(layout.mains[1], mx, my) or (self.branch > 0.2 and In(layout.branchZone, mx, my)))
        if inZone then self.branchUntil = RealTime() + 0.3 end

        local want = RealTime() < self.branchUntil and 1 or 0
        self.branch = SandSwep.Math.Lerp(self.branch, want, 0.12)

        local clean = Clean(self.sel, layout.caps)
        if clean ~= self.sel then self.sel = clean end

        Flush(self)
    end

    function panel:ClickItem(item, caps)
        if not item.ok then return end

        local sel, flag = self.sel, item.opt.bit
        if item.kind == "main" then
            sel = bit.bxor(sel, flag)   -- both, one or none can be selected
        elseif not Has(sel, LASER) then
            if flag ~= ILLUM then sel = bit.band(sel, bit.bnot(VIS + IR)) end
            sel = bit.bor(sel, flag, LASER)
        elseif flag == ILLUM then
            sel = bit.bxor(sel, ILLUM)
        else
            if Has(sel, flag) then
                sel = sel - flag
            else
                sel = bit.bor(bit.band(sel, bit.bnot(VIS + IR)), flag, LASER)
            end
        end

        if item.kind == "sub" and bit.band(sel, SUB) == 0 then
            sel = bit.band(sel, bit.bnot(LASER))
        end

        sel = Clean(sel, caps)
        if sel == self.sel then return end

        self.sel = sel
        self.dirty = true
        Flush(self)

        if not (IsValid(self.wep) and self.wep:GetTacticalOn()) then
            SandSwep.UISound("ui_click")
        end
    end

    function panel:OnMousePressed(code)
        if code ~= MOUSE_LEFT then return end

        local layout = self:Layout()
        local item = self:HoveredItem(layout)
        if item then self:ClickItem(item, layout.caps) end
    end

    local function DrawCross(tile, alpha)
        local margin = math.min(S(14), tile.h * 0.25)
        ThickLine(tile.x + margin, tile.y + margin, tile.x + tile.w - margin, tile.y + tile.h - margin, S(3), COL_CROSS, alpha)
        ThickLine(tile.x + tile.w - margin, tile.y + margin, tile.x + margin, tile.y + tile.h - margin, S(3), COL_CROSS, alpha)
    end

    local function ModeSummary(sel)
        if not HasIR() then return "" end

        local parts = {}
        for _, opt in ipairs(SUBS) do
            if Has(sel, opt.bit) then parts[#parts + 1] = opt.short end
        end

        return table.concat(parts, " + ")
    end

    function panel:Paint(w, h)
        local wep = self.wep
        if not IsValid(wep) then return end

        Fonts()

        local alpha = math.Clamp((RealTime() - self.opened) / 0.12, 0, 1)
        local layout = self:Layout()
        local sel = self.sel
        local on = wep:GetTacticalOn()
        local hovered = self:HoveredItem(layout)

        local laserDef, lightDef = wep:GetFeatureDef("Laser"), wep:GetFeatureDef("Light")
        local title = "NO LASER / LIGHT FITTED"
        if laserDef and lightDef and laserDef ~= lightDef then
            title = (laserDef.Name or "LASER") .. " / " .. (lightDef.Name or "LIGHT")
        elseif laserDef or lightDef then
            title = (laserDef or lightDef).Name or title
        end

        surface.SetDrawColor(0, 0, 0, 60 * alpha)
        surface.DrawRect(0, 0, w, h)

        local titleY = layout.y0 - S(46)
        DrawSpaced(string.upper(title), "SandTac_Title", layout.x0, titleY, COL_TEXT, S(3), alpha)

        local state = on and "ON" or "OFF"
        DrawSpaced(state, "SandTac_Small", layout.x0 + layout.total - SpacedWidth(state, "SandTac_Small", S(2)), titleY + S(8),
            on and COL_RED or COL_DIM, S(2), alpha)

        surface.SetDrawColor(COL_OUTLINE.r, COL_OUTLINE.g, COL_OUTLINE.b, COL_OUTLINE.a * alpha)
        surface.DrawRect(layout.x0, layout.y0 - S(12), layout.total, 1)

        for _, tile in ipairs(layout.mains) do
            local opt = tile.opt
            local iconSize = S(60)
            local iconX, iconY = tile.x + tile.w / 2 - iconSize / 2, tile.y + S(16)

            if not tile.ok then
                surface.SetDrawColor(0, 0, 0, 190 * alpha)
                surface.DrawRect(tile.x, tile.y, tile.w, tile.h)

                surface.SetMaterial(opt.icon)
                surface.SetDrawColor(COL_TEXT.r, COL_TEXT.g, COL_TEXT.b, 35 * alpha)
                surface.DrawTexturedRect(math.Round(iconX), math.Round(iconY), iconSize, iconSize)

                DrawCentered(opt.label, "SandTac_Label", tile.x + tile.w / 2, tile.y + tile.h - S(40),
                    Color(COL_TEXT.r, COL_TEXT.g, COL_TEXT.b, 45), S(2), alpha)
                DrawCross(tile, alpha)
                continue
            end

            local isHov = hovered == tile or (opt.bit == LASER and self.branch > 0.5)
            local isSel = Has(sel, opt.bit)

            local bg = isHov and COL_BG_HI or isSel and COL_BG_SEL or COL_BG
            surface.SetDrawColor(bg.r, bg.g, bg.b, bg.a * alpha)
            surface.DrawRect(tile.x, tile.y, tile.w, tile.h)

            if isSel then
                surface.SetDrawColor(COL_RED.r, COL_RED.g, COL_RED.b, 230 * alpha)
                surface.DrawOutlinedRect(tile.x, tile.y, tile.w, tile.h, 2)
            elseif isHov then
                surface.SetDrawColor(COL_OUTLINE.r, COL_OUTLINE.g, COL_OUTLINE.b, COL_OUTLINE.a * alpha)
                surface.DrawOutlinedRect(tile.x, tile.y, tile.w, tile.h, 1)
            end

            local iconCol = (isHov or isSel) and COL_TEXT or COL_DIM
            surface.SetMaterial(opt.icon)
            surface.SetDrawColor(iconCol.r, iconCol.g, iconCol.b, (iconCol.a or 255) * alpha)
            surface.DrawTexturedRect(math.Round(iconX), math.Round(iconY), iconSize, iconSize)
            DrawCentered(opt.label, "SandTac_Label", tile.x + tile.w / 2, tile.y + tile.h - S(40), iconCol, S(2), alpha)

            if opt.bit == LASER then
                local summary = ModeSummary(sel)
                if summary ~= "" then
                    DrawCentered(summary, "SandTac_Small", tile.x + tile.w / 2, tile.y + tile.h - S(22),
                        isSel and COL_RED or COL_DIM, S(2), alpha)
                end
            end

            if isSel then
                surface.SetDrawColor(COL_RED.r, COL_RED.g, COL_RED.b, 255 * alpha)
                surface.DrawRect(tile.x, tile.y + tile.h - S(4), tile.w, S(4))
            end
        end

        local branch = self.branch
        if branch > 0 and layout.mains[1].ok and HasIR() then
            local branchAlpha = alpha * branch
            local ease = math.ease and math.ease.OutCubic(branch) or branch
            local shift = math.Round((1 - ease) * S(24))

            local laserTile = layout.mains[1]
            local midY = laserTile.y + laserTile.h / 2
            local busX = laserTile.x - S(24)
            local lineW = S(2)
            local first, last = layout.subs[1], layout.subs[#layout.subs]

            ThickLine(laserTile.x, midY, busX + shift, midY, lineW, COL_DIM, branchAlpha)
            ThickLine(busX + shift, first.y + first.h / 2, busX + shift, last.y + last.h / 2, lineW, COL_DIM, branchAlpha)

            for _, tile in ipairs(layout.subs) do
                local opt = tile.opt
                local x = tile.x + shift
                local cy = tile.y + tile.h / 2
                local isSel = Has(sel, opt.bit) and Has(sel, LASER)
                ThickLine(busX + shift, cy, x + tile.w, cy, lineW, (isSel and tile.ok) and COL_RED or COL_DIM, branchAlpha)

                if not tile.ok then
                    surface.SetDrawColor(0, 0, 0, 190 * branchAlpha)
                    surface.DrawRect(x, tile.y, tile.w, tile.h)
                    DrawSpaced(opt.label, "SandTac_Label", x + S(30), tile.y + tile.h / 2 - S(8),
                        Color(COL_TEXT.r, COL_TEXT.g, COL_TEXT.b, 45), S(2), branchAlpha)
                    DrawCross({ x = x, y = tile.y, w = tile.w, h = tile.h }, branchAlpha)
                    continue
                end

                local isHov = hovered == tile
                local bg = isHov and COL_BG_HI or isSel and COL_BG_SEL or COL_BG
                surface.SetDrawColor(bg.r, bg.g, bg.b, bg.a * branchAlpha)
                surface.DrawRect(x, tile.y, tile.w, tile.h)

                if isSel then
                    surface.SetDrawColor(COL_RED.r, COL_RED.g, COL_RED.b, 230 * branchAlpha)
                    surface.DrawOutlinedRect(x, tile.y, tile.w, tile.h, 2)
                elseif isHov then
                    surface.SetDrawColor(COL_OUTLINE.r, COL_OUTLINE.g, COL_OUTLINE.b, COL_OUTLINE.a * branchAlpha)
                    surface.DrawOutlinedRect(x, tile.y, tile.w, tile.h, 1)
                end

                local boxSize = S(10)
                local boxX, boxY = x + S(12), math.Round(cy - boxSize / 2)
                if isSel then
                    surface.SetDrawColor(COL_RED.r, COL_RED.g, COL_RED.b, 255 * branchAlpha)
                    surface.DrawRect(boxX, boxY, boxSize, boxSize)
                else
                    surface.SetDrawColor(COL_DIM.r, COL_DIM.g, COL_DIM.b, COL_DIM.a * branchAlpha)
                    surface.DrawOutlinedRect(boxX, boxY, boxSize, boxSize, 1)
                end

                DrawSpaced(opt.label, "SandTac_Label", x + S(30), tile.y + tile.h / 2 - S(8),
                    (isHov or isSel) and COL_TEXT or COL_DIM, S(2), branchAlpha)
            end
        end

        DrawCentered("CLICK TO SELECT   ·   TAP TO SWITCH ON / OFF", "SandTac_Small",
            layout.x0 + layout.total / 2, layout.y0 + layout.th + S(14), COL_DIM, S(2), alpha)
    end

    return panel
end

-- Key: tap / hold

local function Blocked() return UI.InputBlocked(menu) end

hook.Add("Think", "SandSwep_TacticalKey", function()
    local down = input.IsKeyDown(KeyCode())
    local wep = ActiveDevice()

    if IsValid(menu) and (not wep or wep ~= menu.wep or (not down and not wasDown)) then
        CloseMenu()
        downAt = nil
    end

    if down and not wasDown then
        downAt = (wep and not Blocked()) and RealTime() or nil
    elseif down and downAt and not IsValid(menu) and RealTime() - downAt >= cvHold:GetFloat() then
        if wep then OpenMenu(wep) end
    elseif not down and wasDown and downAt then
        if IsValid(menu) then
            CloseMenu()
        elseif wep and wep:GetTacticalCaps() ~= 0 and RealTime() - downAt < cvHold:GetFloat() then
            RunConsoleCommand("sandswep_tactoggle")   -- tap
        end
        downAt = nil
    end

    wasDown = down
end)
