if not CLIENT then return end

local cvPIPRes = CreateClientConVar("cl_sandswep_scope_resolution", "0.75", true, false, "Scope resolution (fraction of screen height)", 0.25, 1)
local STABLE_OVERSCAN = 1.5

local PIP_STEP = 64
local DISC_SEGMENTS = 48
local MASK_SEGMENTS = 40

local matVignette = Material("models/weapons/sandswep/optics/vignette")
local matScreenVig = Material("models/weapons/sandswep/optics/screenvig")
local materials = {}

local function PIPSize()
    local size = math.Round(ScrH() * cvPIPRes:GetFloat() * STABLE_OVERSCAN / PIP_STEP) * PIP_STEP
    return math.Clamp(size, PIP_STEP * 2, math.floor(ScrH() / PIP_STEP) * PIP_STEP)
end
local pipSize = PIPSize()
local pipRT = GetRenderTarget("sandswep_pip_rt_" .. pipSize, pipSize, pipSize)
SandSwep.PIP_RT, SandSwep.PIP_SIZE = pipRT, pipSize
local pipMat = CreateMaterial("sandswep_pip_mat", "UnlitGeneric", {
    ["$basetexture"] = pipRT:GetName(),
    ["$ignorez"] = 1,
    ["$vertexcolor"] = 1,
    ["$vertexalpha"] = 1,
})
local pipAddMat = CreateMaterial("sandswep_pip_add", "UnlitGeneric", {
    ["$basetexture"] = pipRT:GetName(),
    ["$ignorez"] = 1,
    ["$vertexcolor"] = 1,
    ["$additive"] = 1,
})
local pipPreviewMat = CreateMaterial("sandswep_pip_preview", "UnlitGeneric", {
    ["$basetexture"] = pipRT:GetName(),
})

local function UpdatePIPTarget()
    local size = PIPSize()
    if size == pipSize then return end

    pipSize = size
    pipRT = GetRenderTarget("sandswep_pip_rt_" .. size, size, size)
    pipMat:SetTexture("$basetexture", pipRT)
    pipAddMat:SetTexture("$basetexture", pipRT)
    pipPreviewMat:SetTexture("$basetexture", pipRT)
    SandSwep.PIP_RT, SandSwep.PIP_SIZE = pipRT, size
end

local function Mat(path)
    local mat = materials[path]
    if not mat then
        mat = Material(path, "smooth")
        materials[path] = mat
    end
    return mat
end

function SWEP:PrecacheReticles()
    for _, sight in ipairs(self:GetSights() or {}) do
        local reticle = sight.Reticle
        local tex = reticle and (reticle.Texture or (not reticle.FillLens and "sprites/light_glow02_add"))
        if tex then Mat(tex):GetTexture("$basetexture") end
    end
end

local SmoothStep = SandSwep.Math.Smoothstep01

hook.Add("RenderScreenspaceEffects", "SandSwep_FocusVignette", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or ply:ShouldDrawLocalPlayer() then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not wep.IsSandSwep or not wep.GetFocusProgress then return end

    local strength = wep:GetFocusProgress() * (wep.FocusVignette or 0)
    if strength <= 0.004 then return end

    cam.Start2D()
    surface.SetMaterial(matScreenVig)
    surface.SetDrawColor(255, 255, 255, math.min(strength, 1) * 255)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
    if strength > 1 then
        surface.SetDrawColor(255, 255, 255, (strength - 1) * 255)
        surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
    end
    cam.End2D()
end)

local vertex = Vector()
local function Vertex(cx, cy, cz, rx, ry, rz, ux, uy, uz, offRight, offUp)
    vertex:SetUnpacked(
        cx + rx * offRight + ux * offUp,
        cy + ry * offRight + uy * offUp,
        cz + rz * offRight + uz * offUp)
    mesh.Position(vertex)
end

local function DrawQuad(center, right, up, w, h, r, g, b, a)
    local cx, cy, cz = center:Unpack()
    local rx, ry, rz = right:Unpack()
    local ux, uy, uz = up:Unpack()
    local halfW, halfH = w * 0.5, h * 0.5

    mesh.Begin(MATERIAL_QUADS, 1)
    Vertex(cx, cy, cz, rx, ry, rz, ux, uy, uz, -halfW, halfH) mesh.TexCoord(0, 0, 0) mesh.Color(r, g, b, a) mesh.AdvanceVertex()
    Vertex(cx, cy, cz, rx, ry, rz, ux, uy, uz, halfW, halfH) mesh.TexCoord(0, 1, 0) mesh.Color(r, g, b, a) mesh.AdvanceVertex()
    Vertex(cx, cy, cz, rx, ry, rz, ux, uy, uz, halfW, -halfH) mesh.TexCoord(0, 1, 1) mesh.Color(r, g, b, a) mesh.AdvanceVertex()
    Vertex(cx, cy, cz, rx, ry, rz, ux, uy, uz, -halfW, -halfH) mesh.TexCoord(0, 0, 1) mesh.Color(r, g, b, a) mesh.AdvanceVertex()
    mesh.End()
end

local rings = {}
local function Ring(segments, dir)
    local key = segments * dir
    local ring = rings[key]
    if ring then return ring end

    ring = {}
    for i = 0, segments - 1 do
        local theta = dir * (i / segments) * math.pi * 2
        ring[#ring + 1] = math.cos(theta)
        ring[#ring + 1] = math.sin(theta)
    end

    rings[key] = ring
    return ring
end

local function DrawTexDisc(center, right, up, radius, r, g, b, a, uShift)
    uShift = uShift or 0
    local cx, cy, cz = center:Unpack()
    local rx, ry, rz = right:Unpack()
    local ux, uy, uz = up:Unpack()
    local ring = Ring(DISC_SEGMENTS, -1)

    mesh.Begin(MATERIAL_POLYGON, DISC_SEGMENTS)
    for i = 1, DISC_SEGMENTS * 2, 2 do
        local cos, sin = ring[i], ring[i + 1]
        Vertex(cx, cy, cz, rx, ry, rz, ux, uy, uz, cos * radius, sin * radius)
        mesh.TexCoord(0, 0.5 + 0.5 * cos + uShift, 0.5 - 0.5 * sin)
        mesh.Color(r, g, b, a)
        mesh.AdvanceVertex()
    end
    mesh.End()
end

local function DrawShutterEdge(center, right, up, radius, edge, soft, r, g, b)
    local cx, cy, cz = center:Unpack()
    local rx, ry, rz = right:Unpack()
    local ux, uy, uz = up:Unpack()
    local x0, x1, x2, h = (edge - soft) * radius, edge * radius, radius * 2, radius * 1.2

    mesh.Begin(MATERIAL_QUADS, 2)
    Vertex(cx, cy, cz, rx, ry, rz, ux, uy, uz, x0, h) mesh.Color(255, 255, 255, 255) mesh.AdvanceVertex()
    Vertex(cx, cy, cz, rx, ry, rz, ux, uy, uz, x1, h) mesh.Color(r, g, b, 255) mesh.AdvanceVertex()
    Vertex(cx, cy, cz, rx, ry, rz, ux, uy, uz, x1, -h) mesh.Color(r, g, b, 255) mesh.AdvanceVertex()
    Vertex(cx, cy, cz, rx, ry, rz, ux, uy, uz, x0, -h) mesh.Color(255, 255, 255, 255) mesh.AdvanceVertex()
    Vertex(cx, cy, cz, rx, ry, rz, ux, uy, uz, x1, h) mesh.Color(r, g, b, 255) mesh.AdvanceVertex()
    Vertex(cx, cy, cz, rx, ry, rz, ux, uy, uz, x2, h) mesh.Color(r, g, b, 255) mesh.AdvanceVertex()
    Vertex(cx, cy, cz, rx, ry, rz, ux, uy, uz, x2, -h) mesh.Color(r, g, b, 255) mesh.AdvanceVertex()
    Vertex(cx, cy, cz, rx, ry, rz, ux, uy, uz, x1, -h) mesh.Color(r, g, b, 255) mesh.AdvanceVertex()
    mesh.End()
end

local function DrawShutterMask(center, right, up, radius, edge, fringe)
    render.SetColorMaterialIgnoreZ()
    render.OverrideBlend(true, BLEND_DST_COLOR, BLEND_ZERO, BLENDFUNC_ADD)

    local soft = 0.45
    DrawShutterEdge(center, right, up, radius, edge - fringe, soft, 0, 255, 255)
    DrawShutterEdge(center, right, up, radius, edge, soft, 255, 0, 255)
    DrawShutterEdge(center, right, up, radius, edge + fringe, soft, 255, 255, 0)

    render.OverrideBlend(false)
end

local SMEAR_TAPS = { { 0, 0.55 }, { 0.25, 0.27 }, { 0.5, 0.18 } }
local SHARP_TAP = { { 0, 1 } }

local function ShutterState(progress)
    if progress < 0.4 then
        local frac = progress / 0.4
        return 1.45 - 2.9 * frac * frac, 0.35 * frac * frac, 0.35 * frac
    elseif progress < 0.55 then
        return -1.45, 0, 0
    end

    local frac = (progress - 0.55) / 0.45
    local rest = 1 - frac
    return 1.45 - 2.9 * rest * rest, -0.35 * rest * rest, 0.35 * rest
end

local function DrawDisc(center, right, up, radius)
    local cx, cy, cz = center:Unpack()
    local rx, ry, rz = right:Unpack()
    local ux, uy, uz = up:Unpack()
    local ring = Ring(MASK_SEGMENTS, 1)

    mesh.Begin(MATERIAL_POLYGON, MASK_SEGMENTS)
    for i = 1, MASK_SEGMENTS * 2, 2 do
        Vertex(cx, cy, cz, rx, ry, rz, ux, uy, uz, ring[i] * radius, ring[i + 1] * radius)
        mesh.Color(255, 255, 255, 255)
        mesh.AdvanceVertex()
    end
    mesh.End()
end

local function PIPQuadRadius(lens)
    return lens.Radius * (lens.Overscan or 1.03)
end

local function OpticFrame(att)
    local fwd = att.Ang:Up()
    local up = att.Ang:Right()
    local view = EyeAngles()

    if fwd:Dot(view:Forward()) < 0 then fwd = -fwd end
    if up:Dot(view:Up()) < 0 then up = -up end

    return fwd, up, fwd:Cross(up)
end

function SWEP:GetLensData(sight)
    if not sight or not sight.Lens then return end

    local ent
    if sight.AttSlot then
        ent = self._vmAttEnts and self._vmAttEnts[sight.AttSlot]
    else
        local owner = self:GetOwner()
        ent = IsValid(owner) and owner.GetViewModel and owner:GetViewModel()
    end
    if not IsValid(ent) then return end

    local attId = SandSwep.AttachmentId(ent, sight.Lens.Attachment or "lens")
    if not attId then return end

    local att = ent:GetAttachment(attId)
    if not att then return end

    local squash = ent.SandSwepSquash
    if squash and squash.s < 0.999 and squash.lensPos then
        att = { Pos = squash.lensPos, Ang = squash.lensAng }
    end

    local fwd, up, right = OpticFrame(att)
    local shift = sight.Lens.Offset

    return shift and att.Pos + fwd * shift or att.Pos, fwd, up, right
end

function SWEP:GetPIPTarget(sight, lensPos, aimT)
    local toLens = lensPos - EyePos()
    local dist = math.max(toLens:Length(), 0.01)

    local offAxis = math.deg(math.acos(math.Clamp(toLens:GetNormalized():Dot(EyeAngles():Forward()), -1, 1)))
    local lensAngle = math.deg(math.atan((sight.Lens.Radius or 0.5) / dist))
    local align = 1 - SmoothStep((offAxis - lensAngle * 0.6) / math.max(lensAngle * 1.2, 0.5))
    if self:IsInAction("fireselect") then align = 1 end

    local target = self:GetAiming() and align * SmoothStep((aimT - 0.45) / 0.45)
        or align * SmoothStep((aimT - 0.8) / 0.2)

    if self:GetSightSwitchTime() > 0 then
        local pending = self:GetSights()[self:GetSightPending()]
        if pending and not pending.PIP then target = 0 end
    end

    return target
end

function SWEP:UpdatePIPVisibility(target)
    local now = RealTime()
    local gap = now - (self._pipVisT or 0)
    self._pipVisT = now

    local cur = self._pipVis or 0
    if gap > 0.15 then cur = 0 end

    local dt = math.Clamp(gap, 0, 0.1)
    local rate = target > cur and 5 or 20
    cur = cur + (target - cur) * math.min(dt * rate, 1)
    if math.abs(target - cur) < 0.004 then cur = target end

    self._pipVis = cur
    self._pipVisFrame = FrameNumber()
    return cur
end

local function UpdatePIPFov(wep, sight, lens, lensPos)
    local dist = math.max(EyePos():Distance(lensPos), 0.01)
    local vmHalf = math.atan(PIPQuadRadius(lens) / dist)
    local vmFov = math.rad(wep.ViewModelFOV or 62)
    local worldFov = math.rad(LocalPlayer():GetFOV())
    local frac = math.tan(vmHalf) / math.tan(vmFov * 0.5)
    local want = frac * STABLE_OVERSCAN

    local now = RealTime()
    local cur = wep._pipFrac
    if not cur or now - (wep._pipFracT or 0) > 0.25 then
        cur = want
    else
        cur = cur + (want - cur) * math.min((now - wep._pipFracT) * 2, 1)
    end
    wep._pipFrac, wep._pipFracT = cur, now

    frac = cur
    wep._pipQuadTan = cur * math.tan(vmFov * 0.5)

    local kick = wep.GetFOVKick and wep:GetFOVKick() or 0
    local worldHalf = math.atan(frac * math.tan(worldFov * 0.5) * (1 + kick))
    local lean = Lerp(wep:GetFocusProgress(), 1, wep.FocusZoom or 1)
    wep._pipFov = math.Clamp(math.deg(worldHalf * 2) / wep:GetSightMagnification(sight) * lean, 0.5, 60)
end

local function BeginLensStencil(sight, lens, lensPos, toEye, right, up, fwd)
    render.ClearStencil()
    render.SetStencilEnable(true)
    render.SetStencilWriteMask(255)
    render.SetStencilTestMask(255)
    render.SetStencilReferenceValue(1)
    render.SetStencilCompareFunction(STENCIL_ALWAYS)
    render.SetStencilPassOperation(STENCIL_REPLACE)
    render.SetStencilFailOperation(STENCIL_KEEP)
    render.SetStencilZFailOperation(STENCIL_KEEP)

    render.OverrideColorWriteEnable(true, false)
    render.SetColorMaterial()
    local maskPos = lensPos - fwd * (lens.MaskOffset or 0.1)
    if lens.Radius then
        DrawDisc(maskPos, up:Cross(fwd), up, sight.PIP and PIPQuadRadius(lens) or lens.Radius)
    else
        DrawQuad(maskPos, right, up, lens.W or 1, lens.H or 1, 255, 255, 255, 255)
    end
    render.OverrideColorWriteEnable(false)

    render.SetStencilPassOperation(STENCIL_KEEP)
    render.SetStencilZFailOperation(STENCIL_KEEP)
    render.SetStencilCompareFunction(STENCIL_EQUAL)
end

local function DrawPIPImage(wep, sight, lens, lensPos, aimT)
    local target = wep:GetPIPTarget(sight, lensPos, aimT)
    wep._pipTargetLast = target
    local visible = wep:UpdatePIPVisibility(target)

    if visible > 0.002 then
        local radius = PIPQuadRadius(lens)
        local view = EyeAngles()

        if wep._pipQuadTan then
            render.SetColorMaterialIgnoreZ()
            DrawTexDisc(lensPos, view:Right(), view:Up(), radius, 0, 0, 0, 255)

            local fwd = view:Forward()
            local depth = math.max((lensPos - EyePos()):Dot(fwd), 0.01)
            lensPos = EyePos() + fwd * depth
            radius = depth * wep._pipQuadTan
        end

        render.SetMaterial(pipMat)
        local bright = math.Clamp(sight.PIP.Brightness or 1, 0, 1) * 255
        local right, up = view:Right(), view:Up()
        local shutter, dir = wep:GetSightShutter(sight)

        if shutter then
            local edge, uShift, smear = ShutterState(shutter)
            uShift, smear = uShift * dir, smear * dir
            local ease = SmoothStep(shutter / 0.25) * SmoothStep((1 - shutter) / 0.25)

            render.SetColorMaterialIgnoreZ()
            DrawTexDisc(lensPos, right, up, radius, 0, 0, 0, 255)

            if edge > -1.2 then
                render.SetMaterial(pipAddMat)
                local aberration = 0.015 * ease
                local taps = math.abs(smear) > 0.01 and SMEAR_TAPS or SHARP_TAP
                for _, tap in ipairs(taps) do
                    local tapShift, weight = uShift + smear * tap[1], bright * tap[2]
                    DrawTexDisc(lensPos, right, up, radius, weight, 0, 0, 255, tapShift + aberration * dir)
                    DrawTexDisc(lensPos, right, up, radius, 0, weight, 0, 255, tapShift)
                    DrawTexDisc(lensPos, right, up, radius, 0, 0, weight, 255, tapShift - aberration * dir)
                end
            end

            DrawShutterMask(lensPos, right * dir, up, radius, math.max(edge, -1.2), 0.14 * ease)
            render.SetMaterial(pipMat)
        else
            DrawTexDisc(lensPos, right, up, radius, bright, bright, bright, 255)
        end

        if visible < 0.998 then
            render.SetColorMaterialIgnoreZ()
            DrawTexDisc(lensPos, view:Right(), view:Up(), radius, 8, 11, 13, 255 * (1 - visible))
        end
    end

    return visible
end

local function DrawLensVignette(sight, lens, lensPos, pipVisible)
    local reticle = sight.Reticle
    local strength = lens.Vignette
    if strength == nil then
        strength = (sight.PIP or (reticle and reticle.FillLens)) and 1 or 0
    end
    strength = strength * (sight.PIP and pipVisible or 1)
    if strength <= 0 or not lens.Radius then return end

    render.SetMaterial(matVignette)
    local radius = lens.Radius * (lens.VignetteSize or 1.0)
    if sight.PIP then radius = math.max(radius, PIPQuadRadius(lens)) end

    local toEye = (EyePos() - lensPos):GetNormalized()
    local facing = toEye:Angle()
    local pos = lensPos + toEye * (lens.MaskOffset or 0.1)
    DrawTexDisc(pos, facing:Right(), facing:Up(), radius, 0, 0, 0, math.Clamp(strength, 0, 1) * 255)
end

local function DrawReticle(reticle, lens, lensPos, fwd, up, right, alpha)
    local col = reticle.Color or color_white
    local r, g, b, a = col.r, col.g, col.b, (col.a or 255) * alpha

    if reticle.FillLens and lens.Radius then
        render.SetMaterial(Mat(reticle.Texture))
        local size = lens.Radius * 2 * (reticle.Scale or 1)
        DrawQuad(lensPos - fwd * 0.01, right, up, size, size, r, g, b, a)
        return
    end

    local dist = 2000
    local size = 2 * dist * math.tan(math.rad((reticle.Size or 1) * 0.5))
    render.SetMaterial(Mat(reticle.Texture or "sprites/light_glow02_add"))
    cam.IgnoreZ(true)
    DrawQuad(lensPos + fwd * dist, right, up, size, size, r, g, b, a)
    cam.IgnoreZ(false)
end

local lastOverlayErr

local function DrawLens(wep, sight, lens, lensPos, toEye, right, up, fwd, hasPIP, aimT)
    if lens.Backing then
        render.SetColorMaterial()
        local view = EyeAngles()
        DrawTexDisc(lensPos + fwd * (lens.BackingOffset or 0.03), view:Right(), view:Up(), lens.Backing, 6, 6, 6, 255)
    end

    BeginLensStencil(sight, lens, lensPos, toEye, right, up, fwd)

    local reticle = sight.Reticle
    local alpha = math.Clamp((aimT - 0.4) / 0.6, 0, 1)
    local pipVisible = 1
    if hasPIP then
        pipVisible = DrawPIPImage(wep, sight, lens, lensPos, aimT)
        if reticle and reticle.FillLens then alpha = alpha * pipVisible end
    end

    DrawLensVignette(sight, lens, lensPos, pipVisible)
    if reticle and alpha > 0 then DrawReticle(reticle, lens, lensPos, fwd, up, right, alpha) end
end

function SWEP:DrawOpticOverlay(sight, aimT)
    local lensPos, fwd, up, right = self:GetLensData(sight)
    if not lensPos then return end

    local lens = sight.Lens
    local toEye = (EyePos() - lensPos):GetNormalized()
    local hasPIP = sight.PIP and lens.Radius

    self._opticFwd = fwd
    if hasPIP then UpdatePIPFov(self, sight, lens, lensPos) end

    if self._nvPending then
        self._nvPending = false
        local nv = SandSwep.NVScope
        if nv and nv.Process then nv.Process(pipRT) end
    end

    local ok, err = pcall(DrawLens, self, sight, lens, lensPos, toEye, right, up, fwd, hasPIP, aimT)
    render.SetStencilEnable(false)
    render.OverrideColorWriteEnable(false)
    render.OverrideBlend(false)

    if not ok then
        if err ~= lastOverlayErr then
            lastOverlayErr = err
            ErrorNoHalt("[sandswep optic] " .. tostring(err) .. "\n")
        end
    end
end

local CopyBone = SandSwep.Math.CopyBone
local squashRoot, squashMat, squashBone, squashOut = Matrix(), Matrix(), Matrix(), Matrix()

local function SquashBones(ent, numBones)
    local squash = ent.SandSwepSquash
    if not squash or squash.s >= 0.999 then return end

    local root = CopyBone(ent, 0, squashRoot)
    if not root then return end

    local pos, ang = LocalToWorld(squash.pos, squash.ang, root:GetTranslation(), root:GetAngles())
    squash.lensPos, squash.lensAng = pos, ang

    local axis = ang:Up()
    local stretch = squash.s - 1
    local anchor = pos
    if squash.rear then
        local rearDist = axis:Dot(EyeAngles():Forward()) > 0 and squash.rear[1] or squash.rear[2]
        anchor = pos + axis * rearDist
        squash.lensPos = pos + axis * (stretch * axis:Dot(pos - anchor))
    end

    local shift = axis * (-stretch * axis:Dot(anchor))
    squashMat:SetUnpacked(
        1 + stretch * axis.x * axis.x, stretch * axis.x * axis.y, stretch * axis.x * axis.z, shift.x,
        stretch * axis.y * axis.x, 1 + stretch * axis.y * axis.y, stretch * axis.y * axis.z, shift.y,
        stretch * axis.z * axis.x, stretch * axis.z * axis.y, 1 + stretch * axis.z * axis.z, shift.z,
        0, 0, 0, 1)

    for i = 0, numBones - 1 do
        if CopyBone(ent, i, squashBone) then
            squashOut:Set(squashMat)
            squashOut:Mul(squashBone)
            ent:SetBoneMatrix(i, squashOut)
        end
    end
end

function SWEP:SquashOptic(ent, sight, scale)
    local squash = ent.SandSwepSquash

    if squash == nil then
        ent:SetupBones()
        local root = ent:GetBoneMatrix(0)
        local id = ent:LookupAttachment(sight.Lens and sight.Lens.Attachment or "lens")
        local att = root and id and id > 0 and ent:GetAttachment(id)
        if not att then
            ent.SandSwepSquash = false
            return
        end

        local pos, ang = WorldToLocal(att.Pos, att.Ang, root:GetTranslation(), root:GetAngles())
        squash = { pos = pos, ang = ang, s = 1 }

        if sight.SquashAnchor == "rear" then
            local mins, maxs = ent:GetModelBounds()
            local up = att.Ang:Up()
            local lo, hi = math.huge, -math.huge
            local corners = {
                Vector(mins.x, mins.y, mins.z),
                Vector(maxs.x, mins.y, mins.z),
                Vector(mins.x, maxs.y, mins.z),
                Vector(maxs.x, maxs.y, mins.z),
                Vector(mins.x, mins.y, maxs.z),
                Vector(maxs.x, mins.y, maxs.z),
                Vector(mins.x, maxs.y, maxs.z),
                Vector(maxs.x, maxs.y, maxs.z),
            }
            for _, corner in ipairs(corners) do
                local depth = up:Dot(root * corner - att.Pos)
                lo, hi = math.min(lo, depth), math.max(hi, depth)
            end
            squash.rear = { lo, hi }
        end

        ent.SandSwepSquash = squash
        ent:AddCallback("BuildBonePositions", SquashBones)
    end

    if squash then squash.s = scale end
end

hook.Add("PrePlayerDraw", "SandSwep_PIPHideSelf", function(ply)
    if SandSwep.RenderingPIP and ply == LocalPlayer() then return true end
end)

function SWEP:DrawWorldModel(flags)
    if SandSwep.RenderingPIP and self:GetOwner() == LocalPlayer() then return end
    self:DrawModel(flags)
end

function SWEP:DrawWorldModelTranslucent(flags)
    if SandSwep.RenderingPIP and self:GetOwner() == LocalPlayer() then return end
    self:DrawModel(flags)
end

local function PIPHidden(wep)
    return (wep._pipVis or 0) <= 0.002 and wep._pipVisFrame and FrameNumber() - wep._pipVisFrame <= 2
        and wep.GetPIPTarget and (wep._pipTargetLast or 0) <= 0
end

local function RenderPIP(wep, sight, origin, dir, viewAng)
    SandSwep.RenderingPIP = true

    local nv = sight.PIP.NightVision and SandSwep.NVScope
    if nv then
        local ok, err = pcall(nv.Begin, origin, viewAng and viewAng:Forward() or dir, wep._pipFov or 7)
        if not ok then ErrorNoHalt("[sandswep nv] " .. tostring(err) .. "\n") end
    end

    UpdatePIPTarget()
    render.PushRenderTarget(pipRT)
    render.Clear(0, 0, 0, 255, true, true)
    render.RenderView({
        origin = origin,
        angles = viewAng or dir:Angle(),
        fov = wep._pipFov or 7,
        x = 0,
        y = 0,
        w = pipSize,
        h = pipSize,
        aspect = 1,
        zfar = 100000,
        drawviewmodel = false,
        drawhud = false,
        dopostprocess = false,
    })
    render.PopRenderTarget()
    SandSwep.RenderingPIP = false

    if nv then
        pcall(nv.End)
        wep._nvPending = true
    end
end

local renderingPIP = false
hook.Add("RenderScene", "SandSwep_PIP", function(viewOrigin, viewAngles)
    if renderingPIP then return end

    local ply = LocalPlayer()
    if not IsValid(ply) or ply:ShouldDrawLocalPlayer() then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not wep.IsSandSwep or not wep.GetActiveSight then return end

    local sight = wep:GetActiveSight()
    if not sight or not sight.PIP or wep:GetAimProgress() <= 0.05 then return end
    if PIPHidden(wep) then return end

    renderingPIP = true
    local stable = wep._pipQuadTan and (viewAngles or ply:EyeAngles()) or nil
    RenderPIP(wep, sight, viewOrigin or ply:EyePos(), wep._opticFwd or ply:GetAimVector(), stable)
    renderingPIP = false
end)

local pipDebug = false

local function PrintHooks(label, event, prefix)
    print("  " .. label)
    for name in pairs(hook.GetTable()[event] or {}) do print("    " .. prefix .. tostring(name)) end
end

local function DescribeNear()
    local ply = LocalPlayer()
    local eye = ply:EyePos()

    print("[sandswep pip] entities within 80 units of the eye:")
    for _, ent in ipairs(ents.GetAll()) do
        if ent ~= ply and IsValid(ent) and ent:GetPos():Distance(eye) < 80 then
            print(string.format("  %-28s %-60s nodraw=%s owner=%s parent=%s dist=%.1f",
                ent:GetClass(), tostring(ent:GetModel()), tostring(ent:GetNoDraw()),
                tostring(ent:GetOwner()), tostring(ent:GetParent()), ent:GetPos():Distance(eye)))
        end
    end

    local wep = ply:GetActiveWeapon()
    if IsValid(wep) then
        print(string.format("  pipFov=%.2f pipVis=%.2f aim=%.2f", wep._pipFov or -1, wep._pipVis or -1,
            wep.GetAimProgress and wep:GetAimProgress() or -1))
    end

    print("  PrePlayerDraw / PostPlayerDraw / PreDrawOpaqueRenderables hooks:")
    local events = {
        "PrePlayerDraw",
        "PostPlayerDraw",
        "PreDrawOpaqueRenderables",
        "PreDrawTranslucentRenderables",
        "ShouldDrawLocalPlayer",
        "CalcView",
    }
    for _, event in ipairs(events) do
        for name in pairs(hook.GetTable()[event] or {}) do print("    " .. event .. ": " .. tostring(name)) end
    end

    PrintHooks("RenderScene hooks:", "RenderScene", "")

    print("  PostDrawOpaqueRenderables / PostDrawTranslucentRenderables hooks:")
    for name in pairs(hook.GetTable().PostDrawOpaqueRenderables or {}) do print("    opaque: " .. tostring(name)) end
    for name in pairs(hook.GetTable().PostDrawTranslucentRenderables or {}) do print("    transl: " .. tostring(name)) end
end

concommand.Add("sandswep_pipdebug", function()
    pipDebug = not pipDebug
    print("[sandswep pip] preview " .. (pipDebug and "ON" or "OFF"))
    if pipDebug then DescribeNear() end
end)

hook.Add("PostDrawHUD", "SandSwep_PIPDebug", function()
    if not pipDebug then return end

    cam.Start2D()
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(pipPreviewMat)
    surface.DrawTexturedRect(20, 20, 384, 384)
    surface.SetDrawColor(255, 0, 0, 255)
    surface.DrawOutlinedRect(20, 20, 384, 384)
    cam.End2D()
end)
