SandSwepFX = SandSwepFX or {}
local FX = SandSwepFX

local cvLight = CreateClientConVar("cl_sandswep_muzzlefx_light", "1", true, false, "Muzzle flash dynamic light", 0, 1)

local RIFLE_TP = { "ps_muzzleflash_rifle_tp_01", "ps_muzzleflash_rifle_xshape_tp_01", "ps_muzzleflash_rifle_smoke_tp_01" }
local SIDEARM_TP = { "ps_muzzleflash_sidearm_tp_01", "ps_muzzleflash_sidearm_tp_02", "ps_muzzleflash_m9_03" }
local M16 = { "ps_muzzleflash_m16_01", "ps_muzzleflash_m16_02", "ps_muzzleflash_m16_03" }
local AK47 = { "ps_muzzleflash_ak47_01", "ps_muzzleflash_ak47_02", "ps_muzzleflash_ak47_03", "ps_muzzleflash_ak47_04" }
local GALIL = { "ps_muzzleflash_galil_01", "ps_muzzleflash_galil_02", "ps_muzzleflash_galil_03" }
local LARGE, SMALL = "ps_muzzleflash_suppressed_large", "ps_muzzleflash_suppressed_small"
local SIDEARM = { "ps_muzzleflash_sidearm_01", "ps_muzzleflash_m9_03" }
local PUMP = { "ps_muzzleflash_shotgun_01", "ps_muzzleflash_rifle_smoke_tp_01" }
local SHOTGUN_TP = { "ps_muzzleflash_rifle_starshaped_tp_01" }

FX.Weapons = {
    weapon_sand_m4a1 = { fp = M16, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_m16a2 = { fp = M16, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_m16a4 = { fp = M16, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_mk18 = { fp = M16, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_qbz03 = { fp = M16, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_g36k = { fp = { "ps_muzzleflash_g36_01" }, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_f2000 = { fp = { "ps_muzzleflash_f2000_01", "ps_muzzleflash_f2000_02" }, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_ar7090 = { fp = M16, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_sg552 = { fp = { "ps_muzzleflash_g36_01" }, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_vhs2 = { fp = M16, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_auga3 = { fp = M16, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_qbz97 = { fp = M16, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_qts11 = { fp = M16, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_mcx = { fp = M16, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_asval = { fp = M16, tp = RIFLE_TP, supp = SMALL },
    weapon_sand_famas = { fp = M16, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_honeybadger = { fp = M16, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_m110 = { fp = { "ps_muzzleflash_m16_01", "ps_muzzleflash_m16_02" }, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_ak74 = { fp = { "ps_muzzleflash_ak74_01", "ps_muzzleflash_ak74_02", "ps_muzzleflash_ak74_03" }, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_akm = { fp = AK47, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_akalpha = { fp = AK47, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_aks74u = { fp = { "ps_muzzleflash_aksu_01", "ps_muzzleflash_aksu_02" }, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_galil = { fp = GALIL, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_galil_sar = { fp = GALIL, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_l85a2 = { fp = { "ps_muzzleflash_l85_01", "ps_muzzleflash_l85_02" }, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_m240 = { fp = { "ps_muzzleflash_m240_01" }, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_mg3 = { fp = { "ps_muzzleflash_mg3_01", "ps_muzzleflash_mg3_02" }, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_pkm = { fp = { "ps_muzzleflash_pkm_01" }, tp = RIFLE_TP, supp = LARGE },
    weapon_sand_m249 = { fp = { "ps_muzzleflash_m249_01", "ps_muzzleflash_m249_02" }, tp = { "ps_muzzleflash_rifle_tp_01", "ps_muzzleflash_rifle_xshape_tp_01", "ps_muzzleflash_rifle_smoke_tp_01" }, supp = LARGE },
    weapon_sand_m60 = { fp = { "ps_muzzleflash_m240_01" }, tp = { "ps_muzzleflash_rifle_tp_01", "ps_muzzleflash_rifle_xshape_tp_01", "ps_muzzleflash_rifle_smoke_tp_01" }, supp = LARGE },
    weapon_sand_rpk = { fp = { "ps_muzzleflash_rifle_02", "ps_muzzleflash_rifle_xshape_01" }, tp = { "ps_muzzleflash_rifle_tp_01", "ps_muzzleflash_rifle_smoke_tp_01" }, supp = LARGE },
    weapon_sand_m9 = { fp = { "ps_muzzleflash_m9_02", "ps_muzzleflash_m9_03" }, tp = SIDEARM_TP, supp = SMALL },
    weapon_sand_uzi = { fp = { "ps_muzzleflash_sidearm_01" }, tp = SIDEARM_TP, supp = SMALL },
    weapon_sand_um45 = { fp = { "ps_muzzleflash_sidearm_01", "ps_muzzleflash_sidearm_02" }, tp = SIDEARM_TP, supp = SMALL },
    weapon_sand_rpg7 = { fp = { "ps_muzzleflash_rpg_01" }, tp = { "ps_muzzleflash_rpg_tp_01" } },
    weapon_sand_glock17 = { fp = SIDEARM, tp = SIDEARM_TP, supp = SMALL },
    weapon_sand_m1911 = { fp = SIDEARM, tp = SIDEARM_TP, supp = SMALL },
    weapon_sand_m45a1 = { fp = SIDEARM, tp = SIDEARM_TP, supp = SMALL },
    weapon_sand_makarov = { fp = SIDEARM, tp = SIDEARM_TP, supp = SMALL },
    weapon_sand_pf940 = { fp = SIDEARM, tp = SIDEARM_TP, supp = SMALL },
    weapon_sand_tariq = { fp = SIDEARM, tp = SIDEARM_TP, supp = SMALL },
    weapon_sand_tk33 = { fp = SIDEARM, tp = SIDEARM_TP, supp = SMALL },
    weapon_sand_vanta9 = { fp = SIDEARM, tp = SIDEARM_TP, supp = SMALL },
    weapon_sand_browning = { fp = SIDEARM, tp = SIDEARM_TP, supp = SMALL },
    weapon_sand_l106a1 = { fp = SIDEARM, tp = SIDEARM_TP, supp = SMALL },
    weapon_sand_deagle = { fp = { "ps_muzzleflash_deagle_01" }, tp = SIDEARM_TP, supp = SMALL },
    weapon_sand_m24 = { fp = { "ps_muzzleflash_rifle_large_01" }, tp = { "ps_muzzleflash_rifle_tp_01" }, supp = LARGE },
    weapon_sand_mosin = { fp = { "ps_muzzleflash_mosin_01" }, tp = { "ps_muzzleflash_rifle_tp_01" }, supp = LARGE },
    weapon_sand_m82 = { fp = { "ps_muzzleflash_m82_01" }, tp = { "ps_muzzleflash_rifle_antimaterial_tp_01" }, supp = LARGE },
    weapon_sand_m99 = { fp = { "ps_muzzleflash_m82_01" }, tp = { "ps_muzzleflash_rifle_antimaterial_tp_01" }, supp = LARGE },
    weapon_sand_at4 = { fp = { "ps_muzzleflash_rpg_01" }, tp = { "ps_muzzleflash_rpg_tp_01" } },
    weapon_sand_maaws = { fp = { "ps_muzzleflash_carlg_01" }, tp = { "ps_muzzleflash_rpg_tp_01" } },
    weapon_sand_pzf3 = { fp = { "ps_muzzleflash_carlg_01" }, tp = { "ps_muzzleflash_rpg_tp_01" } },
    weapon_sand_m79 = { fp = { "ps_muzzleflash_grenadelauncher_01" }, tp = { "ps_muzzleflash_rifle_starshaped_tp_01" } },
    weapon_sand_welrod = { fp = SIDEARM, tp = SIDEARM_TP, supp = SMALL },
    weapon_sand_mr73 = { fp = SIDEARM, tp = SIDEARM_TP, supp = SMALL },
    weapon_sand_l96a1 = { fp = { "ps_muzzleflash_rifle_large_01" }, tp = { "ps_muzzleflash_rifle_tp_01" }, supp = LARGE },
    weapon_sand_m320 = { fp = { "ps_muzzleflash_grenadelauncher_01" }, tp = { "ps_muzzleflash_rifle_starshaped_tp_01" } },
    weapon_sand_m870 = { fp = PUMP, tp = SHOTGUN_TP, supp = LARGE },
    weapon_sand_toz194 = { fp = PUMP, tp = SHOTGUN_TP, supp = LARGE },
    weapon_sand_ksg = { fp = PUMP, tp = SHOTGUN_TP, supp = LARGE },
    weapon_sand_ks23 = { fp = PUMP, tp = SHOTGUN_TP, supp = LARGE },
    weapon_sand_m26 = { fp = PUMP, tp = SHOTGUN_TP, supp = LARGE },
    weapon_sand_saiga12 = { fp = { "ps_muzzleflash_shotgun_01" }, tp = SHOTGUN_TP, supp = LARGE },
    weapon_sand_usas12 = { fp = { "ps_muzzleflash_shotgun_01" }, tp = SHOTGUN_TP, supp = LARGE },
}

local SMOKE = {
    ps_muzzleflash_ak47_03 = true,
    ps_muzzleflash_ak47_04 = true,
    ps_muzzleflash_ak74_03 = true,
    ps_muzzleflash_f2000_03 = true,
    ps_muzzleflash_galil_03 = true,
    ps_muzzleflash_m16_03 = true,
    ps_muzzleflash_m9_03 = true,
    ps_muzzleflash_rifle_smoke_01 = true,
    ps_muzzleflash_rifle_smoke_tp_01 = true,
}

local LIGHT_COLOR = Color(255, 160, 70)

game.AddParticles("particles/sandswep_muzzleflash.pcf")

local function SystemName(name)
    return "sandswep_" .. (string.StartWith(name, "ps_") and name:sub(4) or name)
end

local precached = {}

local function PrecacheList(names)
    if isstring(names) then names = { names } end

    for _, name in ipairs(names or {}) do
        if not precached[name] then
            precached[name] = true
            PrecacheParticleSystem(SystemName(name))
        end
    end
end

local function Config(wep)
    return wep.MuzzleFX or FX.Weapons[wep:GetClass()]
end

local function Choose(list)
    local pool = {}

    for _, name in ipairs(list or {}) do
        if not SMOKE[name] then pool[#pool + 1] = name end
    end

    if #pool == 0 then return end

    return pool[math.random(#pool)]
end

local function MuzzleDef(wep)
    for _, _, def in wep:IterAttachments() do
        if def.Slot == "muzzle" then return def end
    end
end

local function DeviceModel(wep, fp)
    local models
    if fp then
        models = wep._vmAttEnts
    else
        local state = wep.SandTPIK_State
        models = state and state.attEnts
    end

    for _, ent in pairs(models or {}) do
        local def = IsValid(ent) and (ent.SandSwepDef or ent.SandTPIK_Def)
        if def and def.Slot == "muzzle" then return ent end
    end
end

local function GunModel(wep, fp)
    local owner = wep:GetOwner()
    if fp then return IsValid(owner) and owner:GetViewModel() or nil end

    local tpik = wep.SandTPIK_Model
    local effects = SANDTPIK and SANDTPIK.CVars and SANDTPIK.CVars.Effects
    if IsValid(tpik) and (not effects or effects:GetBool()) then return tpik end

    return wep
end

local function Attachment(ent, name)
    if not IsValid(ent) then return end

    local id = ent:LookupAttachment(name)
    if id and id > 0 then return id end
end

local function MuzzlePoint(wep, fp)
    local def = MuzzleDef(wep)

    if def and def.Model then
        local device = DeviceModel(wep, fp)
        local id = Attachment(device, "muzzle")
        if id then return device, id end
    end

    local gun = GunModel(wep, fp)
    local name = def and def.MuzzleAttachment or (wep.MuzzleAttachmentName and wep:MuzzleAttachmentName())
    local id = (name and Attachment(gun, name)) or Attachment(gun, "muzzle")
    if id then return gun, id end
end

local function WorldFrame(wep, ent, id, fp)
    local att = ent:GetAttachment(id)
    if not att then return end

    local pos, fwd = att.Pos, att.Ang:Forward()
    if not fp then return pos, fwd:Angle() end

    local vmView = SandSwep.VMView
    local view = vmView.ViewInfo(wep, false)
    local worldPos = vmView.ToWorld(pos, view)
    local ahead = vmView.ToWorld(pos + fwd, view)
    ahead:Sub(worldPos)

    return worldPos, ahead:Angle()
end

local function Light(pos, fp)
    if not cvLight:GetBool() then return end

    local light = DynamicLight(0x5F00 + math.random(0, 63))
    if not light then return end

    light.pos = pos
    light.r, light.g, light.b = LIGHT_COLOR.r, LIGHT_COLOR.g, LIGHT_COLOR.b
    light.brightness = 2
    light.size = fp and 140 or 180
    light.decay = 2400
    light.dietime = CurTime() + 0.06
end

local function PlayFlash(name, ent, id, fp)
    local sys = CreateParticleSystem(ent, SystemName(name), PATTACH_POINT_FOLLOW, id)
    if IsValid(sys) and fp then sys:SetIsViewModelEffect(true) end
end

function FX.Play(wep, name, fp)
    local ent, id = MuzzlePoint(wep, fp)
    if not ent then return end

    local pos = WorldFrame(wep, ent, id, fp)
    if not pos then return end

    PrecacheList(name)
    PlayFlash(name, ent, id, fp)

    return pos
end

function FX.WeaponShot(wep, thirdPerson)
    if not IsValid(wep) then return end

    local cfg = Config(wep)
    if not cfg then return end

    local fp = not thirdPerson
    local suppressed = wep:IsSuppressed()
    local hidden = wep:HasFlashHider()
    local list = fp and cfg.fp or cfg.tp or cfg.fp

    if hidden then return end

    local name = suppressed and cfg.supp or Choose(list)
    if name then
        local pos = FX.Play(wep, name, fp)
        if pos and not suppressed then Light(pos, fp) end
    end
end

function FX.Precache(wep)
    local cfg = Config(wep)
    if not cfg then return end

    PrecacheList(cfg.fp)
    PrecacheList(cfg.tp)
    PrecacheList(cfg.supp)
end

function FX.Uses(wep)
    return IsValid(wep) and Config(wep) ~= nil
end

local shotSeen = setmetatable({}, { __mode = "k" })

local function WatchRemoteShots()
    if not SandSwep.Holders then return end

    local me = LocalPlayer()
    local holders, wepOf = SandSwep.Holders()

    for _, ply in ipairs(holders) do
        local wep = wepOf[ply]
        if wep.GetShotCount then
            local shots = wep:GetShotCount()
            local seen = shotSeen[wep]
            shotSeen[wep] = shots

            if seen and seen ~= shots and ply ~= me then FX.WeaponShot(wep, true) end
        end
    end
end

hook.Add("Think", "SandSwepFX", WatchRemoteShots)
