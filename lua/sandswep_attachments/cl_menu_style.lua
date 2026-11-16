local UI = include("sandswep_base/ui/cl_ui.lua")

-- Client: attachment menu (hold C), Insurgency 2 style

local COL_TEXT   = Color(230, 228, 220)
local COL_DIM    = Color(200, 198, 190, 150)
local COL_ROW    = Color(30, 30, 30, 170)
local COL_ROW_HI = Color(60, 60, 58, 200)
local COL_ROW_OFF = Color(22, 22, 22, 120)
local COL_OFF    = Color(200, 198, 190, 55)
local COL_RED    = Color(196, 52, 38)
local COL_LINE   = Color(220, 220, 215, 170)

local fontScale
local function Fonts()
    local scale = ScrH() / 1080
    if fontScale == scale then return scale end
    fontScale = scale

    surface.CreateFont("SandAtt_Big",   { font = "Roboto Condensed", size = math.Round(54 * scale), weight = 800 })
    surface.CreateFont("SandAtt_Bar",   { font = "Roboto Condensed", size = math.Round(26 * scale), weight = 700 })
    surface.CreateFont("SandAtt_Slot",  { font = "Roboto Condensed", size = math.Round(26 * scale), weight = 800 })
    surface.CreateFont("SandAtt_Item",  { font = "Roboto", size = math.Round(15 * scale), weight = 500 })
    surface.CreateFont("SandAtt_Small", { font = "Roboto", size = math.Round(14 * scale), weight = 500 })
    UI.ResetWidths()

    return scale
end

local SpacedWidth = UI.SpacedWidth
local function DrawSpaced(text, font, x, y, col, spacing, alignRight)
    if alignRight then x = x - SpacedWidth(text, font, spacing) end

    surface.SetFont(font)
    surface.SetTextColor(col.r, col.g, col.b, col.a or 255)

    for _, code in utf8.codes(text) do
        local glyph = utf8.char(code)
        surface.SetTextPos(math.Round(x), math.Round(y))
        surface.DrawText(glyph)
        x = x + surface.GetTextSize(glyph) + spacing
    end
end
local function Truncate(text, font, spacing, maxW)
    if SpacedWidth(text, font, spacing) <= maxW then return text end

    while #text > 1 and SpacedWidth(text .. "...", font, spacing) > maxW do
        text = string.sub(text, 1, #text - 1)
    end

    return text .. "..."
end

local function Ring(x, y, radius, col)
    surface.DrawCircle(x, y, radius, col.r, col.g, col.b, col.a)
    surface.DrawCircle(x, y, radius * 0.45, col.r, col.g, col.b, col.a)
end

local function MenuButton(scale, parent, text, x, y, w, h, onClick, isOn)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn.Paint = function(self, pw, ph)
        local on = isOn and isOn()
        surface.SetDrawColor(on and COL_RED or (self:IsHovered() and COL_ROW_HI or COL_ROW))
        surface.DrawRect(0, 0, pw, ph)

        local spacing = math.Round(3 * scale)
        DrawSpaced(text, "SandAtt_Item", (pw - SpacedWidth(text, "SandAtt_Item", spacing)) / 2,
            (ph - draw.GetFontHeight("SandAtt_Item")) / 2, COL_TEXT, spacing)
    end
    btn.DoClick = onClick

    return btn
end

local function CrossIcon(w, h, col)
    surface.SetDrawColor(col.r, col.g, col.b, col.a)
    local inset = math.Round(w * 0.3)
    surface.DrawLine(inset, inset, w - inset, h - inset)
    surface.DrawLine(w - inset, inset, inset, h - inset)
end

SandSwep.AttInternal = {
    COL_TEXT = COL_TEXT, COL_DIM = COL_DIM, COL_ROW = COL_ROW, COL_ROW_HI = COL_ROW_HI,
    COL_ROW_OFF = COL_ROW_OFF, COL_OFF = COL_OFF, COL_RED = COL_RED, COL_LINE = COL_LINE,
    Fonts = Fonts, SpacedWidth = SpacedWidth, DrawSpaced = DrawSpaced, Truncate = Truncate,
    Ring = Ring, MenuButton = MenuButton, CrossIcon = CrossIcon,
}
