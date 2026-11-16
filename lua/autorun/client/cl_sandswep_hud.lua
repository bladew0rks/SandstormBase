local VisualFrameTime = SandSwep.VisualFrameTime

local cvEnable = CreateClientConVar("cl_sandswep_hud", "1", true, false, "Sandstorm HUD")
local cvHealth = CreateClientConVar("cl_sandswep_hud_health", "1", true, false, "Health and armour bars")
local cvShow   = CreateClientConVar("cl_sandswep_hud_show_time", "3", true, false, "Seconds the HUD stays up", 0, 30)
local cvMode   = CreateClientConVar("cl_sandswep_hud_show_firemode", "1", true, false, "Show fire mode changes")
local cvAlways = CreateClientConVar("cl_sandswep_hud_always", "0", true, false, "Never hide the HUD")
local cvScale  = CreateClientConVar("cl_sandswep_hud_scale", "1", true, false, "HUD size multiplier", 0.5, 2)

-- Palette

local COL_TEXT    = Color(255, 255, 255)
local COL_LABEL   = Color(228, 228, 224)
local COL_DIM     = Color(255, 255, 255, 150)
local COL_SHADOW  = Color(0, 0, 0, 120)
local COL_ICON    = Color(255, 255, 255, 245)
local COL_FILL    = Color(255, 255, 255, 140)
local COL_EXTLINE = Color(0, 0, 0, 70)
local COL_CELL    = Color(0, 0, 0, 140)
local COL_CELLSEL = Color(255, 255, 255, 50)
local COL_LOW     = Color(215, 75, 60)
local COL_BG      = Color(0, 0, 0, 110)
local COL_ARMOR   = Color(120, 170, 215)

local PANEL_ALPHA = 0.55

-- Scaling / fonts

local hudScale = 1

local function UpdateScale()
    hudScale = (ScrH() / 1080) * cvScale:GetFloat()
end

local function S(x)
    return math.max(1, math.Round(x * hudScale))
end

local FONT = "SandSwep HUD"
local ASCENT = 1325 / 1702

local function CreateFonts()
    UpdateScale()
    surface.CreateFont("SandHUD_Label",   { font = FONT, size = S(40), weight = 400, antialias = true })
    surface.CreateFont("SandHUD_Count",   { font = FONT, size = S(61), weight = 400, antialias = true })
    surface.CreateFont("SandHUD_Reserve", { font = FONT, size = S(46), weight = 400, antialias = true })
    surface.CreateFont("SandHUD_Small",   { font = FONT, size = S(26), weight = 400, antialias = true })
end
CreateFonts()
hook.Add("OnScreenSizeChanged", "SandSwepHUD_Fonts", CreateFonts)
cvars.AddChangeCallback("cl_sandswep_hud_scale", CreateFonts, "SandSwepHUD_Fonts")

local function Mat(name) return Material("sandswep/hud/" .. name .. ".png", "smooth mips") end

local MAT = {
    drum = Mat("drum_rim"), drumMissing = Mat("drum_missing"), drumFill = Mat("drum_fill"),
    grenade = Mat("grenade"), grenadeMissing = Mat("grenade_missing"), rocket = Mat("rocket"),
    semi = Mat("fm_semi"), burst = Mat("fm_burst"), burst2 = Mat("fm_burst2"), auto = Mat("fm_auto"),
    brackets = Mat("fm_brackets"),
}

-- Helpers

local activeWep, activeFrame
local function ActiveSandSwep()
    local frame = FrameNumber()
    if activeFrame == frame then return activeWep end
    activeFrame, activeWep = frame, nil

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and wep.IsSandSwep and wep.IsReloading then activeWep = wep end

    return activeWep
end

local function WithAlpha(col, alpha)
    return col.r, col.g, col.b, (col.a or 255) * alpha
end


local function TextBaseline(text, font, x, baseline, col, alpha, align)
    surface.SetFont(font)
    local w, h = surface.GetTextSize(text)
    local y = math.Round(baseline - h * ASCENT)

    if align == TEXT_ALIGN_RIGHT then
        x = x - w
    elseif align == TEXT_ALIGN_CENTER then
        x = x - w / 2
    end

    surface.SetTextColor(WithAlpha(COL_SHADOW, alpha))
    surface.SetTextPos(math.ceil(x + 1), math.ceil(y + 1))
    surface.DrawText(text)

    surface.SetTextColor(WithAlpha(col, alpha))
    surface.SetTextPos(math.ceil(x), math.ceil(y))
    surface.DrawText(text)

    return w
end

local function TexRect(mat, x, y, w, h, col, alpha)
    surface.SetMaterial(mat)
    surface.SetDrawColor(WithAlpha(col, alpha))
    surface.DrawTexturedRect(x, y, w, h)
end

-- Hide the HL2 elements we replace

local HIDE_AMMO   = { CHudAmmo = true, CHudSecondaryAmmo = true }
local HIDE_HEALTH = { CHudHealth = true, CHudBattery = true }

hook.Add("HUDShouldDraw", "SandSwepHUD_Hide", function(name)
    if not HIDE_AMMO[name] and not HIDE_HEALTH[name] then return end

    if name == "CHudSecondaryAmmo" then
        local wep = ActiveSandSwep()
        if wep and wep.GetGLDef and not wep:GetGLDef() then return false end
    end

    if not cvEnable:GetBool() or not ActiveSandSwep() then return end
    if HIDE_AMMO[name] then return false end
    if cvHealth:GetBool() then return false end
end)

-- Ammo kinds

local LABELS = {
    mag = "MAGS", ext = "MAGS", drum = "DRUMS", box = "BOXES",
    grenade = "ROUNDS", gl = "ROUNDS", rocket = "ROCKETS", rounds = "ROUNDS", shells = "SHELLS",
}

local function MagAttachment(wep)
    if not wep.IterAttachments then return end
    for _, _, def in wep:IterAttachments() do
        if def.MagSize and (def.Slot == nil or def.Slot == "magazine") then return def end
    end
end

local function IsShotgun(wep)
    local ammo = string.lower(wep.Primary.Ammo or "")
    return ammo == "buckshot" or (wep.Primary.NumShots or 1) > 1
end

local function AmmoKind(wep)
    if wep.GetGrenadeCount or wep.CountCharges then return "count" end
    if wep.GetGLMode and wep:GetGLMode() then return "gl" end
    if wep.PoolsAmmo and wep:PoolsAmmo() then return IsShotgun(wep) and "shells" or "rounds" end
    if wep.HUDAmmoType then return wep.HUDAmmoType end
    if wep.Rocket then return wep.Grenade and "grenade" or "rocket" end
    if wep.InsertReload then return IsShotgun(wep) and "shells" or "rounds" end

    local def = MagAttachment(wep)
    if def and def.HUDIcon then return def.HUDIcon end
    if wep.BeltBodygroup or wep.LiveBelt then return "box" end
    if def and string.find(string.lower(def.Name or ""), "drum", 1, true) then return "drum" end
    if def and def.MagSize > (wep.Primary.ClipSize or 0) then return "ext" end

    return "mag"
end

local kindCache = setmetatable({}, { __mode = "k" })
local function CachedKind(wep)
    local attData = wep.GetAttData and wep:GetAttData() or ""
    local gl = (wep.GetGLMode and wep:GetGLMode()) and true or false
    local pool = (wep.PoolsAmmo and wep:PoolsAmmo()) and true or false

    local cached = kindCache[wep]
    if cached and cached.attData == attData and cached.gl == gl and cached.pool == pool then
        return cached.kind
    end

    local kind = AmmoKind(wep)
    kindCache[wep] = { attData = attData, gl = gl, pool = pool, kind = kind }

    return kind
end

local function GrenadeCount(wep)
    if wep.GetGrenadeCount then return wep:GetGrenadeCount() end
    return wep:CountCharges()
end

-- Visibility + smoothing state

local FADE_IN, FADE_OUT = 0.15, 0.4   -- seconds

local SLOT_KEYS = setmetatable({}, { __index = function(keys, i)
    local key = "slot" .. i
    keys[i] = key
    return key
end })

local state = {
    wep = NULL,
    showUntil = 0,
    alpha = 0,
    modeUntil = 0,
    modeAlpha = 0,
    mode = nil,
    gl = nil,
    count = nil,
    smooth = {},
}

local function UpdateVisibility(wep)
    local now = CurTime()
    local hold = cvShow:GetFloat()
    local gl = wep.GetGLMode and wep:GetGLMode() or false

    if wep ~= state.wep then
        state.wep = wep
        state.smooth = {}
        state.mode = wep:GetFireModeIndex()
        state.gl = gl
        state.count = nil
        state.showUntil = now + hold
    end

    if wep:IsReloading() or wep:IsMagChecking() or (wep.IsGLReloading and wep:IsGLReloading()) then
        state.showUntil = now + hold
    end

    if gl ~= state.gl then
        state.gl = gl
        state.showUntil = now + hold
    end

    local mode = wep:GetFireModeIndex()
    if mode ~= state.mode then
        state.mode = mode
        if cvMode:GetBool() then state.modeUntil = now + hold end
    end

    if wep.GetGrenadeCount or wep.CountCharges then
        local count = GrenadeCount(wep)
        if count ~= state.count then
            if state.count then state.showUntil = now + hold end
            state.count = count
        end
    end

    local visible = cvAlways:GetBool() or now < state.showUntil
    state.alpha = math.Approach(state.alpha, visible and 1 or 0,
        VisualFrameTime() / (visible and FADE_IN or FADE_OUT))

    local modeVisible = now < state.modeUntil
    state.modeAlpha = math.Approach(state.modeAlpha, modeVisible and 1 or 0,
        VisualFrameTime() / (modeVisible and FADE_IN or FADE_OUT))

    return state.alpha, state.modeAlpha
end

local function Smooth(key, target)
    local cur = state.smooth[key]
    if not cur then
        state.smooth[key] = target
        return target
    end

    cur = Lerp(math.min(VisualFrameTime() * 14, 1), cur, target)
    if math.abs(cur - target) < 0.002 then cur = target end
    state.smooth[key] = cur

    return cur
end

-- Icons

local ICONS = {
    mag     = { w = 20, h = 36, pitch = 26, top = 52, bar = 1 },
    ext     = { w = 20, h = 43, pitch = 26, top = 52, bar = 1, line = 0.77 },
    box     = { w = 34, h = 29, pitch = 40, top = 52, bar = 1 },
    drum    = { w = 27, h = 27, pitch = 35, top = 54, bar = 2 },
    grenade = { w = 16, h = 34, pitch = 26, top = 53, bar = 3 },
    rocket  = { w = 15, h = 38, pitch = 25, top = 53, bar = 0 },
}
ICONS.gl = ICONS.grenade

local function DashedRect(x, y, w, h, thick, alpha)
    surface.SetDrawColor(WithAlpha(COL_ICON, alpha))
    local dash, gap = S(4), S(3)

    for dx = 0, w - 1, dash + gap do
        local len = math.min(dash, w - dx)
        surface.DrawRect(x + dx, y, len, thick)
        surface.DrawRect(x + dx, y + h - thick, len, thick)
    end

    for dy = 0, h - 1, dash + gap do
        local len = math.min(dash, h - dy)
        surface.DrawRect(x, y + dy, thick, len)
        surface.DrawRect(x + w - thick, y + dy, thick, len)
    end
end

local function DrawBoxIcon(x, y, w, h, frac, missing, line, alpha)
    local thick = S(2)
    if missing then
        DashedRect(x, y, w, h, thick, alpha)
        return
    end

    local innerH = h - thick * 2
    local fillH = math.Round(innerH * math.Clamp(frac, 0, 1))
    if fillH > 0 then
        surface.SetDrawColor(WithAlpha(COL_FILL, alpha))
        surface.DrawRect(x + thick, y + thick + innerH - fillH, w - thick * 2, fillH)
    end

    if line then
        surface.SetDrawColor(WithAlpha(COL_EXTLINE, alpha))
        surface.DrawRect(x + thick, y + math.Round(h * line), w - thick * 2, S(2))
    end

    surface.SetDrawColor(WithAlpha(COL_ICON, alpha))
    surface.DrawOutlinedRect(x, y, w, h, thick)
end

local function DrawDrumIcon(x, y, w, h, frac, missing, alpha)
    if missing then
        TexRect(MAT.drumMissing, x, y, w, h, COL_ICON, alpha)
        return
    end

    frac = math.Clamp(frac, 0, 1)
    if frac > 0 then
        local top = y + math.Round(h * (1 - frac))
        render.SetScissorRect(x, top, x + w, y + h, true)
        TexRect(MAT.drumFill, x, y, w, h, COL_FILL, alpha)
        render.SetScissorRect(0, 0, 0, 0, false)
    end

    TexRect(MAT.drum, x, y, w, h, COL_ICON, alpha)
end

local function DrawIcon(kind, x, y, w, h, slot, alpha)
    local def = ICONS[kind]

    if kind == "drum" then
        DrawDrumIcon(x, y, w, h, slot.frac, slot.missing, alpha)
    elseif kind == "grenade" or kind == "gl" then
        TexRect(slot.missing and MAT.grenadeMissing or MAT.grenade, x, y, w, h, COL_ICON, alpha)
    elseif kind == "rocket" then
        TexRect(MAT.rocket, x, y, w, h, COL_ICON, alpha * (slot.missing and 0.3 or 1))
    else
        DrawBoxIcon(x, y, w, h, slot.frac, slot.missing, def.line, alpha)
    end
end

-- Slots: [1] is the round / mag in the weapon, then the spares, fullest first

local slots = {}
local function SetSlot(i, frac, missing, current)
    local slot = slots[i]
    if not slot then
        slot = {}
        slots[i] = slot
    end

    slot.frac, slot.missing, slot.current = frac, missing, current
end

local function BuildSlots(wep, kind)
    local count, total

    if kind == "gl" then
        local loaded = wep:GetGLLoaded()
        local reserve = wep:GetGLReserve()

        SetSlot(1, 1, not loaded, true)
        count = 1
        for i = 1, math.min(reserve, 2) do
            count = count + 1
            SetSlot(count, 1, false, false)
        end

        total = reserve + (loaded and 1 or 0)
    elseif kind == "grenade" or kind == "rocket" then
        local loaded = wep:Clip1() > 0
        local spare = #wep:GetMags()

        count = 0
        if loaded or kind == "grenade" or spare == 0 then
            count = 1
            SetSlot(1, 1, not loaded, kind == "grenade")
        end
        for i = 1, math.min(spare, 3 - count) do
            count = count + 1
            SetSlot(count, 1, false, false)
        end

        total = spare + (loaded and 1 or 0)
    else
        local size = math.max(wep.GetMagSize and wep:GetMagSize() or wep.Primary.ClipSize, 1)
        local mags = wep:GetMags()
        local inserted = not wep.HasMagInserted or wep:HasMagInserted()

        local frac = 0
        if inserted then
            frac = wep:GetRoundsInMag() / size
            if wep.HideExactAmmo and not wep:IsMagChecking() then frac = math.ceil(frac * 4) / 4 end
        end

        SetSlot(1, Smooth(SLOT_KEYS[1], frac), not inserted, true)
        count = 1
        for i = 1, math.min(#mags, 2) do
            count = count + 1
            SetSlot(count, Smooth(SLOT_KEYS[count], mags[i] / size), false, false)
        end

        total = #mags + (inserted and 1 or 0)
    end

    return count, total
end

-- Panels

local MAT_PANEL = Mat("panel_grad")
local function DrawPanelBG(right, top, alpha, flip)
    local w, h = S(176), S(98)
    surface.SetMaterial(MAT_PANEL)
    surface.SetDrawColor(0, 0, 0, 255 * PANEL_ALPHA * alpha)

    if flip then
        surface.DrawTexturedRectUV(right - w, top, w, h, 1, 0, 0, 1)
    else
        surface.DrawTexturedRect(right - w, top, w, h)
    end
end

local function FireModeIcon(wep, mode)
    if mode == "burst" then return (wep.BurstCount or 3) == 2 and MAT.burst2 or MAT.burst end
    if mode == "auto" then return MAT.auto end

    return MAT.semi
end

local fmList = {}
local FM_RANK = { auto = 1, burst = 2, semi = 3 }
local fmModes, fmFrame, fmWep
local function FireModeOrder(a, b)
    local rankA, rankB = FM_RANK[fmModes[a]] or 2, FM_RANK[fmModes[b]] or 2
    if rankA ~= rankB then return rankA < rankB end

    return a > b
end
local function FireModeList(wep)
    local frame = FrameNumber()
    if fmFrame == frame and fmWep == wep then return fmList, fmModes end
    fmFrame, fmWep = frame, wep

    for i = #fmList, 1, -1 do fmList[i] = nil end

    local modes = wep.GetFireModes and wep:GetFireModes() or {}
    for i = #modes, 1, -1 do
        if modes[i] ~= "safe" then fmList[#fmList + 1] = i end
    end

    fmModes = modes
    table.sort(fmList, FireModeOrder)

    return fmList, modes
end

local function DrawFireModes(wep, right, top, alpha)
    local order, modes = FireModeList(wep)
    local cell = S(33)
    local x = right - cell
    local current = wep:GetFireModeIndex()
    local iconSize = S(26)
    local inset = math.floor((cell - iconSize) / 2)

    for row, idx in ipairs(order) do
        local y = top + (row - 1) * cell
        local selected = idx == current

        surface.SetDrawColor(WithAlpha(COL_CELL, alpha))
        surface.DrawRect(x, y, cell, cell)
        if selected then
            surface.SetDrawColor(WithAlpha(COL_CELLSEL, alpha))
            surface.DrawRect(x, y, cell, cell)
        end

        TexRect(FireModeIcon(wep, modes[idx]), x + inset, y + inset, iconSize, iconSize,
            COL_ICON, alpha * (selected and 1 or 0.3))
        if selected then TexRect(MAT.brackets, x, y, cell, cell, COL_ICON, alpha * 0.85) end
    end
end

local function HasFireModeColumn(wep, kind)
    if kind == "gl" or kind == "count" then return false end

    return #FireModeList(wep) > 1
end

local function DrawAmmoPanel(wep, kind, right, top, alpha)
    DrawPanelBG(right, top, alpha)
    TextBaseline(wep.HUDAmmoLabel or LABELS[kind] or "MAGS", "SandHUD_Label",
        right - S(13), top + S(30), COL_LABEL, alpha, TEXT_ALIGN_RIGHT)

    local baseline = top + S(80)

    if kind == "rounds" or kind == "shells" then
        local loaded = wep.Tubes and (wep:Clip1() .. " / " .. wep:GetOtherTube()) or tostring(wep:Clip1())
        local countW = TextBaseline(loaded, "SandHUD_Count", right - S(12), baseline, COL_TEXT, alpha, TEXT_ALIGN_RIGHT)
        local sepX = right - S(12) - countW - S(20)

        surface.SetDrawColor(WithAlpha(COL_DIM, alpha))
        surface.DrawRect(sepX - S(1), top + S(59), S(2), S(24))

        TextBaseline(tostring(wep.GetSpareRounds and wep:GetSpareRounds() or 0), "SandHUD_Reserve",
            sepX - S(17), baseline, COL_DIM, alpha, TEXT_ALIGN_RIGHT)

        return
    end

    local def = ICONS[kind] or ICONS.mag
    local count, total = BuildSlots(wep, kind)
    local overflow = total > 3

    local iconsRight = right - S(20)
    if overflow then
        local countW = TextBaseline(tostring(total), "SandHUD_Count", right - S(12), baseline, COL_TEXT, alpha, TEXT_ALIGN_RIGHT)
        iconsRight = right - S(12) - countW - S(21)
    end

    local w, h = S(def.w), S(def.h)
    local y = top + S(def.top)
    local pitch = S(def.pitch)
    local x = iconsRight - w

    for i = 1, count do
        local slot = slots[i]
        DrawIcon(kind, x, y, w, h, slot, alpha)

        if slot.current and def.bar > 0 then
            surface.SetDrawColor(WithAlpha(COL_ICON, alpha))
            surface.DrawRect(x - S(def.bar), top + S(47), w + S(def.bar) * 2, S(3))
        end

        if i < count then x = x - pitch end
    end

    if overflow then
        local plusSize, plusThick = S(12), S(2)
        local plusX, plusY = x - S(3) - plusSize, top + S(75)

        surface.SetDrawColor(WithAlpha(COL_ICON, alpha))
        surface.DrawRect(plusX, plusY - math.floor(plusThick / 2), plusSize, plusThick)
        surface.DrawRect(plusX + math.floor((plusSize - plusThick) / 2), plusY - math.floor(plusSize / 2), plusThick, plusSize)
    end
end

local function DrawWeaponPanel(wep, alpha, modeAlpha)
    local right = ScrW() - S(44)
    local top = ScrH() - S(33) - S(98)
    local kind = CachedKind(wep)

    if kind == "count" then
        if alpha > 0.01 then
            TextBaseline(tostring(GrenadeCount(wep)), "SandHUD_Count", right - S(12), top + S(80),
                COL_TEXT, alpha, TEXT_ALIGN_RIGHT)
        end
        return
    end

    if HasFireModeColumn(wep, kind) then
        local fmAlpha = math.max(alpha, modeAlpha)
        if fmAlpha > 0.01 then DrawFireModes(wep, right, top, fmAlpha) end
        right = right - S(38)
    end

    if alpha > 0.01 then DrawAmmoPanel(wep, kind, right, top, alpha) end
end

local function DrawHealthPanel(ply, alpha)
    local left = S(44)
    local top = ScrH() - S(33) - S(98)

    DrawPanelBG(left + S(176), top, alpha, true)

    local hp = math.max(ply:Health(), 0)
    local maxHp = math.max(ply:GetMaxHealth(), 1)
    local frac = Smooth("hp", math.Clamp(hp / maxHp, 0, 1))
    local low = frac <= 0.3

    local x = left + S(16)
    local baseline = top + S(52)
    local textW = TextBaseline(tostring(hp), "SandHUD_Count", x, baseline, low and COL_LOW or COL_TEXT, alpha, TEXT_ALIGN_LEFT)

    local plusSize, plusThick = S(16), S(4)
    local plusX = x + textW + S(8)
    local plusY = baseline - math.Round(S(61) / 1.702 * 0.81 / 2)

    surface.SetDrawColor(WithAlpha(COL_ICON, alpha))
    surface.DrawRect(plusX, plusY - math.floor(plusThick / 2), plusSize, plusThick)
    surface.DrawRect(plusX + math.floor((plusSize - plusThick) / 2), plusY - math.floor(plusSize / 2), plusThick, plusSize)

    local w, h, thick = S(136), S(10), S(2)
    local y = top + S(66)
    local fillW = math.Round((w - thick * 2) * frac)
    if fillW > 0 then
        surface.SetDrawColor(WithAlpha(COL_FILL, alpha))
        surface.DrawRect(x + thick, y + thick, fillW, h - thick * 2)
    end

    surface.SetDrawColor(WithAlpha(COL_ICON, alpha))
    surface.DrawOutlinedRect(x, y, w, h, thick)

    local armor = ply:Armor()
    if armor > 0 then
        local armorY = y + h + S(5)
        local maxArmor = math.max(ply.GetMaxArmor and ply:GetMaxArmor() or 100, 1)
        local armorFrac = Smooth("armor", math.Clamp(armor / maxArmor, 0, 1))

        surface.SetDrawColor(WithAlpha(COL_BG, alpha))
        surface.DrawRect(x, armorY, w, S(3))
        surface.SetDrawColor(WithAlpha(COL_ARMOR, alpha))
        surface.DrawRect(x, armorY, math.Round(w * armorFrac), S(3))
    end
end

local lastPaintFrame, lastPaintTime, lastPaintVia = -1, 0, "never"
local cvDrawHUD = GetConVar("cl_drawhud")
local function PaintHUD()
    if not cvEnable:GetBool() then return end
    if not cvDrawHUD:GetBool() then return end

    UpdateScale()

    local wep = ActiveSandSwep()
    if not (IsValid(wep) and wep.IsReloading and wep.GetFireModeIndex) then
        state.wep = NULL
        state.alpha = 0
        state.modeAlpha = 0
        return
    end

    local ply = LocalPlayer()
    local alpha, modeAlpha = UpdateVisibility(wep)
    if alpha <= 0.01 and modeAlpha <= 0.01 then return end

    DrawWeaponPanel(wep, alpha, modeAlpha)

    if alpha > 0.01 and cvHealth:GetBool() then DrawHealthPanel(ply, alpha) end
end

local lastErr
SandSwep = SandSwep or {}
function SandSwep.PaintHUD(via)
    local frame = FrameNumber()
    if frame == lastPaintFrame then return end
    lastPaintFrame, lastPaintTime, lastPaintVia = frame, RealTime(), via

    local ok, err = pcall(PaintHUD)
    if not ok then
        render.SetScissorRect(0, 0, 0, 0, false)
        if err ~= lastErr then
            lastErr = err
            ErrorNoHalt("[sandswep HUD] " .. tostring(err) .. "\n")
        end
    end
end
hook.Add("HUDPaint", "SandSwepHUD_Paint", function() SandSwep.PaintHUD("HUDPaint hook") end)

concommand.Add("sandswep_hudinfo", function()
    local wep = ActiveSandSwep()

    print(string.format("[sandswep HUD] enabled %s, cl_drawhud %s, sandswep weapon %s, kind %s, alpha %.2f, always %s, last error: %s",
        tostring(cvEnable:GetBool()), tostring(GetConVar("cl_drawhud"):GetBool()), tostring(wep ~= nil),
        wep and CachedKind(wep) or "-", state.alpha or 0, tostring(cvAlways:GetBool()), tostring(lastErr)))
    print(string.format("[sandswep HUD] last drawn %.2f s ago via %s", RealTime() - lastPaintTime, lastPaintVia))

    local names = {}
    for name in pairs(hook.GetTable().HUDPaint or {}) do names[#names + 1] = tostring(name) end
    print("[sandswep HUD] HUDPaint hooks: " .. table.concat(names, ", "))
end)
concommand.Add("sandswep_hudtest", function()
    state.showUntil = CurTime() + 5
    state.modeUntil = CurTime() + 5
    print("[sandswep HUD] forcing the HUD up for 5 s")
end)
