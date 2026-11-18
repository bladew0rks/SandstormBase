-- Client: lasers and lights for every player

local matDot  = Material("sprites/light_glow02_add")
local lights  = {}   -- [ply] = ProjectedTexture
local lightKeys = {}

local function TacticalState(ply, feature)
    if not IsValid(ply) or not ply:Alive() then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not wep.IsSandSwep or not wep.GetFeatureDef then return end

    local on = (feature == "Laser") and (wep.GetVisLaserOn and wep:GetVisLaserOn())
        or (feature == "Light" and wep:GetLightOn())
    if not on then return end

    local def = wep:GetFeatureDef(feature)   -- the device that has this feature
    if not def then return end

    return wep, def
end

local function DeviceRay(ply, feature)
    local beams = SandSwep.TacBeam and SandSwep.TacBeam[ply]
    local ray = beams and beams[feature]
    if not ray or ply ~= LocalPlayer() or ply:ShouldDrawLocalPlayer() then return end

    if RealTime() - beams.time < 0.25 then
        return ray.pos, ray.dir
    end
end

local aimTraces = setmetatable({}, { __mode = "k" })

local function AimTrace(ply)
    local frame = FrameNumber()
    local out = aimTraces[ply]
    if out and out.frame == frame then return out end

    if not out then
        out = {}
        aimTraces[ply] = out
    end

    local pos, dir = DeviceRay(ply, "Laser")
    pos = pos or ply:GetShootPos()
    dir = dir or ply:GetAimVector()
    SandSwep.TraceLine(pos, pos + dir * 4096, ply, MASK_SHOT, out)
    out.frame = frame

    return out
end

local LASER_COLOR = Color(255, 30, 20)

hook.Add("PostDrawTranslucentRenderables", "SandSwep_Lasers", function(depth, sky)
    if depth or sky then return end

    for _, ply in player.Iterator() do
        local wep, def = TacticalState(ply, "Laser")
        if not wep then continue end

        local tr = AimTrace(ply)
        if not tr.Hit then continue end

        local col = def.LaserColor or LASER_COLOR
        render.SetMaterial(matDot)

        local pos = tr.HitPos + tr.HitNormal * 0.5
        local size = 3 + math.Rand(0, 0.6)
        render.DrawSprite(pos, size, size, col)
        render.DrawSprite(pos, size * 0.4, size * 0.4, color_white)
    end
end)

SandSwep.LightDefaults = {
    Texture = "effects/sandswep/flashlight_circles",
    FOV = 77.5, FarZ = 1174, Brightness = 7.5,
    Color = Color(217, 229, 255), Shadows = true,
}
local cvLightBright  = CreateClientConVar("cl_sandswep_light_brightness", "1", true, false, "Weapon light brightness multiplier", 0, 10)
local cvLightShadows = CreateClientConVar("cl_sandswep_light_shadows", "1", true, false, "Weapon lights cast shadows", 0, 1)
local function LightConfig(def)
    local defaults = SandSwep.LightDefaults
    def = def or {}

    return {
        Texture = def.LightTexture or defaults.Texture,
        FOV = def.LightFOV or defaults.FOV,
        FarZ = def.LightFarZ or defaults.FarZ,
        Brightness = (def.LightBrightness or defaults.Brightness) * cvLightBright:GetFloat(),
        Color = def.LightColor or defaults.Color,
        Shadows = (def.LightShadows ~= nil and def.LightShadows or defaults.Shadows) and cvLightShadows:GetBool(),
    }
end

local lightTrace = {}

hook.Add("Think", "SandSwep_Lights", function()
    for ply, light in pairs(lights) do
        local wep = TacticalState(ply, "Light")
        if not wep then
            if IsValid(light) then light:Remove() end
            lights[ply] = nil
            lightKeys[ply] = nil
        end
    end

    for _, ply in ipairs((SandSwep.Holders())) do
        local wep, def = TacticalState(ply, "Light")
        if not wep then continue end

        local light = lights[ply]
        if not IsValid(light) then
            light = ProjectedTexture()
            lights[ply] = light
            lightKeys[ply] = nil
        end

        local bright, shadows = cvLightBright:GetFloat(), cvLightShadows:GetBool()
        local key = lightKeys[ply]
        if not key or key[1] ~= def or key[2] ~= bright or key[3] ~= shadows then
            lightKeys[ply] = { def, bright, shadows }
            local cfg = LightConfig(def)
            light:SetTexture(cfg.Texture)
            light:SetFarZ(cfg.FarZ)
            light:SetFOV(cfg.FOV)
            light:SetBrightness(cfg.Brightness)
            light:SetColor(cfg.Color)
            light:SetEnableShadows(cfg.Shadows)
        end

        local rayPos, rayDir = DeviceRay(ply, "Light")
        if rayPos then
            light:SetPos(rayPos)
            light:SetAngles(rayDir:Angle())
        else
            local ang = ply:EyeAngles()
            local base = ply:GetShootPos() + ang:Right() * 4 - ang:Up() * 3
            local tr = SandSwep.TraceLine(base, base + ang:Forward() * 22, ply, MASK_SHOT, lightTrace)
            light:SetPos(base + ang:Forward() * math.max(tr.Fraction * 22 - 2, 0))   -- never inside a wall
            light:SetAngles(ply:GetAimVector():Angle())
        end

        light:Update()
    end
end)
