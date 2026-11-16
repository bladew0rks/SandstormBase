SandSwep = SandSwep or {}
local UI = {}

UI.COL_TEXT    = Color(235, 230, 215)
UI.COL_DIM     = Color(235, 230, 215, 110)
UI.COL_BG      = Color(0, 0, 0, 130)
UI.COL_BG_HI   = Color(60, 60, 58, 200)
UI.COL_BG_SEL  = Color(40, 22, 18, 190)
UI.COL_OUTLINE = Color(235, 230, 215, 150)
UI.COL_RED     = Color(196, 52, 38)
UI.COL_CROSS   = Color(235, 230, 215, 120)

local cvScale
function UI.S(x)
    cvScale = cvScale or GetConVar("cl_sandswep_hud_scale")
    return math.max(1, math.Round(x * (ScrH() / 1080) * (cvScale and cvScale:GetFloat() or 1)))
end

local widths = {}
function UI.ResetWidths() widths = {} end

function UI.SpacedWidth(text, font, spacing)
    local byFont = widths[font]
    if not byFont then
        byFont = {}
        widths[font] = byFont
    end

    local bySpacing = byFont[spacing]
    if not bySpacing then
        bySpacing = {}
        byFont[spacing] = bySpacing
    end

    local w = bySpacing[text]
    if w then return w end

    surface.SetFont(font)
    w = 0
    for _, code in utf8.codes(text) do
        w = w + surface.GetTextSize(utf8.char(code)) + spacing
    end
    w = math.max(w - spacing, 0)

    bySpacing[text] = w
    return w
end

function UI.DrawSpaced(text, font, x, y, col, spacing, alpha)
    surface.SetFont(font)
    surface.SetTextColor(col.r, col.g, col.b, (col.a or 255) * (alpha or 1))

    for _, code in utf8.codes(text) do
        local char = utf8.char(code)
        surface.SetTextPos(math.Round(x), math.Round(y))
        surface.DrawText(char)
        x = x + surface.GetTextSize(char) + spacing
    end
end

function UI.DrawCentered(text, font, cx, y, col, spacing, alpha)
    UI.DrawSpaced(text, font, cx - UI.SpacedWidth(text, font, spacing) / 2, y, col, spacing, alpha)
end

function UI.ThickLine(x1, y1, x2, y2, width, col, alpha)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end

    local nx, ny = -dy / len * width / 2, dx / len * width / 2

    draw.NoTexture()
    surface.SetDrawColor(col.r, col.g, col.b, (col.a or 255) * alpha)

    local quad = {
        { x = x1 + nx, y = y1 + ny }, { x = x2 + nx, y = y2 + ny },
        { x = x2 - nx, y = y2 - ny }, { x = x1 - nx, y = y1 - ny },
    }
    surface.DrawPoly(quad)
    surface.DrawPoly({ quad[4], quad[3], quad[2], quad[1] })
end

function UI.InputBlocked(ownMenu)
    local ply = LocalPlayer()

    if gui.IsGameUIVisible() or gui.IsConsoleVisible() then return true end
    if IsValid(ply) and ply:IsTyping() then return true end
    if IsValid(vgui.GetKeyboardFocus()) then return true end
    if vgui.CursorVisible() and not IsValid(ownMenu) then return true end   -- spawn / attachment menu etc.

    return false
end

SandSwep.UI = UI
return UI
