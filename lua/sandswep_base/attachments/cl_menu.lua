local Internal = SandSwep.AttInternal
local COL_TEXT, COL_DIM, COL_RED, COL_LINE = Internal.COL_TEXT, Internal.COL_DIM, Internal.COL_RED, Internal.COL_LINE
local Fonts, DrawSpaced, Ring, MenuButton = Internal.Fonts, Internal.DrawSpaced, Internal.Ring, Internal.MenuButton
local RemovePreview, AnchorPos = Internal.RemovePreview, Internal.AnchorPos
local RebuildSlots, OpenPresets = Internal.RebuildSlots, Internal.OpenPresets

local function SummaryLayout(h, rows, scale)
    local fixed = (62 + 36 + 16 + 8 + 30) * scale
    local top, bottom = h * 0.60, h * 0.97
    local row = math.Clamp((bottom - top - fixed) / math.max(rows, 1), 19 * scale, 28 * scale)

    local need = fixed + rows * row
    if top + need > bottom then top = math.max(h * 0.30, bottom - need) end

    return top, row
end

local GUN_SPAN, GUN_X, GUN_Y = 0.418, 0.38, 0.49
local MENU_GUN_LENGTH = 34

local menu
local MAT_GRADIENT = Material("gui/center_gradient")

local function ActiveSandSwep()
    local ply = LocalPlayer()
    local wep = IsValid(ply) and ply:GetActiveWeapon()
    if IsValid(wep) and wep.IsSandSwep and wep.GetAttachmentSlots then
        for _, slot in pairs(wep:GetAttachmentSlots()) do
            if not slot.Hidden then return wep end
        end
    end
end

local function CustomizeBlocked(wep)
    if wep:ActionBlocks("customize") then return true end

    local vm = IsValid(LocalPlayer()) and LocalPlayer():GetViewModel()
    local entry = wep.GetAnimEntry and wep:GetAnimEntry("ready")
    if not IsValid(vm) or not entry then return false end
    if vm:GetCycle() >= 0.98 then return false end

    local cur = vm:GetSequenceName(vm:GetSequence())
    local seqs = istable(entry.Seq) and entry.Seq or { entry.Seq }
    for _, name in ipairs(seqs) do
        if name == cur then return true end
    end

    return false
end

function SandSwep.CloseAttachMenu()
    if IsValid(menu) then menu:Remove() end
    menu = nil
end

local SLOT_POS = {
    muzzle = { 0.05, 0.10 }, barrel = { 0.05, 0.10 },
    frontsight = { 0.25, 0.17 },
    optic = { 0.62, 0.17 },
    tactical = { 0.07, 0.63 },
    underbarrel = { 0.19, 0.74 },
    magazine = { 0.36, 0.74 },
    ammo = { 0.36, 0.74 },
    finish = { 0.40, 0.06 },
}
local function LayoutGroups(frame, scale)
    local w, h = frame:GetWide(), frame:GetTall()
    local rightLimit = w * 0.62

    for name, group in pairs(frame.groups) do
        local fixedPos = IsValid(group) and (group.slot.MenuPos or SLOT_POS[name])
        if fixedPos then
            local gx = math.Clamp(w * fixedPos[1], 0, w - group:GetWide())
            local gy = math.Clamp(h * fixedPos[2], 0, h - group:GetTall())
            group:SetPos(gx, gy)
            group.fixed = true
        end
    end

    local pad = 24 * scale

    local ammo, mag = frame.groups.ammo, frame.groups.magazine
    if IsValid(ammo) and IsValid(mag) and not ammo.slot.MenuPos then
        local mx, my = mag:GetPos()
        local gy = my + mag:GetTall() + pad
        if gy + ammo:GetTall() > h then gy = my - ammo:GetTall() - pad end

        ammo:SetPos(mx, gy)
    end

    local function ClearFixed(gx, gy, gw, gt)
        local moved = true
        while moved do
            moved = false
            for _, other in pairs(frame.groups) do
                if IsValid(other) and other.fixed then
                    local ox, oy = other:GetPos()
                    if gx < ox + other:GetWide() + pad and gx + gw + pad > ox and gy < oy + other:GetTall() and gy + gt > oy then
                        gx = ox + other:GetWide() + pad
                        moved = true
                    end
                end
            end
        end
        return gx
    end

    for _, side in ipairs({ true, false }) do
        local list = {}
        for name, group in pairs(frame.groups) do
            if IsValid(group) and not group.fixed and (group.top and true or false) == side then
                local anchor = frame.anchors[name]
                list[#list + 1] = { group = group, anchorX = anchor and anchor.x or w * 0.4 }
            end
        end
        table.sort(list, function(a, b) return a.anchorX < b.anchorX end)

        local gy = function(gt) return side and math.max(h * 0.03, h * 0.27 - gt) or h * 0.70 end

        local x = w * 0.04
        for _, item in ipairs(list) do
            local gw, gt = item.group:GetWide(), item.group:GetTall()
            local gx = ClearFixed(math.max(x, item.anchorX - gw * 0.35), gy(gt), gw, gt)
            item.gx = gx
            x = gx + gw + pad
        end

        local over = math.max(x - pad - rightLimit, 0)
        local minX = w * 0.02
        for _, item in ipairs(list) do
            local gw, gt = item.group:GetWide(), item.group:GetTall()
            local gx = ClearFixed(math.max(item.gx - over, minX), gy(gt), gw, gt)
            item.group:SetPos(gx, gy(gt))
            minX = gx + gw + pad
        end
    end
end

local function DrawPreviewGun(self, preview, wep, w, h)
    local gun = preview.gun
    if not IsValid(gun) then return end

    local cfg = IsValid(wep) and wep.MenuCamera or {}
    local fov = cfg.FOV or 30
    local up = Vector(0, 0, 1)
    local fwd = preview.fwd
    if cfg.Yaw then
        fwd = Vector(fwd.x, fwd.y, 0)
        fwd:Rotate(Angle(0, cfg.Yaw, 0))
    end

    local camFwd = fwd:Cross(up)
    local aspectMul = (w / h) / (4 / 3)
    local halfTan = math.tan(math.rad(fov * 0.5)) * aspectMul
    local gunLen = cfg.Length or math.max(MENU_GUN_LENGTH, (preview.length or MENU_GUN_LENGTH) * 0.8)
    local dist = gunLen / (2 * halfTan * GUN_SPAN) * (cfg.Dist or 1)
    local visW = 2 * dist * halfTan
    local camRight = camFwd:Cross(up)

    local offset = cfg.Offset or vector_origin
    local target = preview.center + fwd * offset.x + camRight * offset.y + up * offset.z
        - camRight * (visW * (GUN_X - 0.5)) - up * (visW * (h / w) * (0.5 - GUN_Y))
    local camPos = target - camFwd * dist
    local ang = camFwd:Angle()

    cam.Start3D(camPos, ang, fov, 0, 0, w, h, 4, 4096)
        render.SuppressEngineLighting(true)
        render.ResetModelLighting(0.32, 0.32, 0.34)
        render.SetModelLighting(BOX_TOP, 0.6, 0.6, 0.58)

        local keyDir = (camFwd - up * 0.8 + camRight * 0.6):GetNormalized()
        local fillDir = (camFwd - up * 0.2 - camRight * 0.9):GetNormalized()
        local rimDir = (-camFwd - up * 0.4 - camRight * 0.5):GetNormalized()
        render.SetLocalModelLights({
            { type = MATERIAL_LIGHT_DIRECTIONAL, color = Vector(2.6, 2.45, 2.25), dir = keyDir },
            { type = MATERIAL_LIGHT_DIRECTIONAL, color = Vector(0.55, 0.6, 0.7), dir = fillDir },
            { type = MATERIAL_LIGHT_DIRECTIONAL, color = Vector(1.2, 1.25, 1.4), dir = rimDir },
        })
        render.SetColorModulation(1, 1, 1)
        render.SetBlend(1)

        gun:SetupBones()
        gun:DrawModel()
        for _, ent in pairs(preview.atts) do
            if not IsValid(ent) then continue end

            if not ent.SandSwepOffset then
                ent:DrawModel()
                continue
            end

            local attOffset = ent.SandSwepOffset
            local framePos, frameAng = SandSwep.OffsetFrame(gun, attOffset)
            if not framePos then continue end

            local attPos, attAng = LocalToWorld(attOffset.Pos or vector_origin, attOffset.Ang or angle_zero, framePos, frameAng)
            ent:SetPos(attPos)
            ent:SetAngles(attAng)
            ent:SetupBones()
            ent:DrawModel()
        end

        render.SetLocalModelLights({})
        render.SuppressEngineLighting(false)

        for name, group in pairs(self.groups) do
            local anchorPos = AnchorPos(preview, group.anchorSlot or name, group.slot)
            if anchorPos then
                local screen = anchorPos:ToScreen()
                local lx, ly = self:ScreenToLocal(screen.x, screen.y)
                self.anchors[name] = { x = lx, y = ly }
            end
        end
    cam.End3D()
end

local function DrawAnchorLines(self, scale)
    surface.SetDrawColor(COL_LINE.r, COL_LINE.g, COL_LINE.b, COL_LINE.a)
    for name, group in pairs(self.groups) do
        local anchor = self.anchors[name]
        if anchor and IsValid(group) then
            local gx, gy = group:GetPos()
            local tx, ty = gx + 10 * scale, gy + 13 * scale
            surface.SetDrawColor(COL_LINE.r, COL_LINE.g, COL_LINE.b, COL_LINE.a)
            surface.DrawLine(anchor.x, anchor.y, tx, ty)
            Ring(anchor.x, anchor.y, 7 * scale, COL_LINE)
            Ring(tx, ty, 7 * scale, COL_LINE)
        end
    end
end

local function DrawSummary(wep, scale, w, h)
    if not IsValid(wep) then return end

    local px, pw = w * 0.635, w * 0.33
    local slots = wep:GetAttachmentSlots()
    local names = {}
    for name, slot in pairs(slots) do
        if not slot.Hidden then names[#names + 1] = name end
    end
    table.sort(names)

    local top, row = SummaryLayout(h, #names, scale)
    local py = top
    DrawSpaced("ATTACHMENTS", "SandAtt_Big", px, py, COL_TEXT, 1)
    py = py + 62 * scale

    surface.SetDrawColor(COL_RED.r, COL_RED.g, COL_RED.b, COL_RED.a)
    surface.DrawRect(px, py, pw, 36 * scale)
    DrawSpaced(string.upper(wep:GetPrintName() or ""), "SandAtt_Bar", px + 10 * scale, py + 4 * scale, COL_TEXT, 1)
    py = py + 36 * scale

    surface.SetDrawColor(20, 20, 20, 200)
    surface.DrawRect(px, py, pw, #names * row + 16 * scale)
    py = py + 10 * scale

    for _, slotName in ipairs(names) do
        local slot = slots[slotName]
        local id = wep:GetSlotAttachment(slotName)
        local def = id and SandSwep.Attachments[id]
        local fallback = slot.Fallback and SandSwep.Attachments[slot.Fallback]
        local value = def and def.Name or slot.NoneName or (fallback and fallback.Name) or "None"
        DrawSpaced(string.upper(slot.Name or slotName), "SandAtt_Small", px + 12 * scale, py, COL_DIM, 2)
        DrawSpaced(string.upper(value), "SandAtt_Small", px + pw - 12 * scale, py, def and COL_TEXT or COL_DIM, 2, true)
        py = py + row
    end
end

local function AddMenuButtons(st, visible)
    local frame, scale, btnH, btnGap = st.frame, st.scale, st.btnH, st.btnGap

    local summaryX, summaryW = math.Round(ScrW() * 0.635), math.Round(ScrW() * 0.33)
    local sumTop, sumRow = SummaryLayout(ScrH(), visible, scale)
    local btnY = math.Round(sumTop + (62 + 36 + 16 + 8) * scale + visible * sumRow)
    local btnW = math.floor((summaryW - btnGap * 2) / 3)
    MenuButton(scale, frame, "PRESETS", summaryX, btnY, btnW, btnH, function() OpenPresets(st) end, function() return IsValid(st.presetPanel) end)
    MenuButton(scale, frame, "SHUFFLE", summaryX + btnW + btnGap, btnY, btnW, btnH, function()
        RunConsoleCommand("sandswep_shuffle")
        SandSwep.UISound("ui_attach")
    end)
    MenuButton(scale, frame, "RESET", summaryX + (btnW + btnGap) * 2, btnY, btnW, btnH, function()
        RunConsoleCommand("sandswep_resetatts")
        SandSwep.UISound("ui_remove")
    end)
end

function SandSwep.OpenAttachMenu(wep)
    SandSwep.CloseAttachMenu()
    if CustomizeBlocked(wep) then return end

    LocalPlayer().SandSwepMenuOpen = true
    RunConsoleCommand("sandswep_menu", "1")
    local scale = Fonts()

    local frame = vgui.Create("DPanel")
    menu = frame
    frame:SetPos(0, 0)
    frame:SetSize(ScrW(), ScrH())
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(false)   -- so releasing C still closes it
    frame.startTime = SysTime()
    frame.pv = { atts = {} }
    frame.groups = {}
    frame.anchors = {}

    local preview = frame.pv
    frame.OnRemove = function()
        RemovePreview(preview)
        LocalPlayer().SandSwepMenuOpen = nil
        RunConsoleCommand("sandswep_menu", "0")
    end

    local st = { frame = frame, wep = wep, preview = preview, scale = scale }
    local function Rebuild() RebuildSlots(st) end
    frame.Rebuild = Rebuild
    Rebuild()

    local visible = 0
    for _, slot in pairs(wep:GetAttachmentSlots()) do
        if not slot.Hidden then visible = visible + 1 end
    end
    st.btnH, st.btnGap = math.Round(30 * scale), math.Round(6 * scale)

    local menuRemove = frame.OnRemove
    frame.OnRemove = function(self)
        if IsValid(st.presetPanel) then st.presetPanel:Remove() end
        if menuRemove then menuRemove(self) end
    end

    AddMenuButtons(st, visible)

    frame.Think = function(self)
        local current = ActiveSandSwep()
        if current ~= wep or CustomizeBlocked(wep) then
            SandSwep.CloseAttachMenu()
            return
        end

        local attKey = wep:GetAttData() .. "|" .. (wep.GetAttSkins and wep:GetAttSkins() or "")
        if attKey ~= self.lastKey then Rebuild() end

        if not self.layoutDone and next(self.anchors) then
            LayoutGroups(frame, scale)
            self.layoutDone = true
        end
    end

    frame.Paint = function(self, w, h)
        Derma_DrawBackgroundBlur(self, self.startTime)
        surface.SetDrawColor(10, 10, 10, 170)
        surface.DrawRect(0, 0, w, h)
        surface.SetMaterial(MAT_GRADIENT)
        surface.SetDrawColor(120, 110, 90, 40)
        surface.DrawTexturedRect(0, 0, w, h)

        DrawPreviewGun(self, preview, wep, w, h)
        DrawAnchorLines(self, scale)
        DrawSummary(wep, scale, w, h)
    end
end

hook.Add("ContextMenuOpen", "SandSwep_AttachMenu", function()
    local wep = ActiveSandSwep()
    if not wep then return end
    if CustomizeBlocked(wep) then return false end

    SandSwep.OpenAttachMenu(wep)
    return false
end)

hook.Add("OnContextMenuClose", "SandSwep_AttachMenu", function()
    if IsValid(menu) and menu.pinned then return end
    SandSwep.CloseAttachMenu()
end)

concommand.Add("sandswep_attachments", function()
    if IsValid(menu) then
        SandSwep.CloseAttachMenu()
        return
    end

    local wep = ActiveSandSwep()
    if wep then
        if not CustomizeBlocked(wep) then SandSwep.OpenAttachMenu(wep) end
        return
    end

    local held = IsValid(LocalPlayer()) and LocalPlayer():GetActiveWeapon()
    if IsValid(held) and held.IsSandSwep then
        print("[sandswep] " .. held:GetClass() .. " has no SWEP.AttachmentSlots, so there is nothing to attach."
            .. " If you have two files for this weapon, check which one is loading.")
    else
        print("[sandswep] Hold a sandswep weapon first.")
    end
end)
