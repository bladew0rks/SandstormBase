AddCSLuaFile()

SandSwep = SandSwep or {}

function SandSwep.AddSound(name, paths, opts)
    opts = opts or {}

    sound.Add({
        name    = name,
        channel = opts.channel or CHAN_AUTO,
        volume  = opts.volume or 1,
        level   = opts.level or 75,
        pitch   = opts.pitch or { 95, 105 },
        sound   = paths,
    })

    return name
end

local cloth = {}
for i = 1, 4 do cloth[i] = "physics/body/body_medium_impact_soft" .. i .. ".wav" end

SandSwep.AddSound("SandSwep.Foley",      cloth, { volume = 0.25, level = 60, pitch = { 100, 115 } })
SandSwep.AddSound("SandSwep.FoleyLight", cloth, { volume = 0.12, level = 55, pitch = { 105, 120 } })
SandSwep.AddSound("SandSwep.ADS.RifleIn", { "sandstorm/shared/foley/ads_in_01.ogg", "sandstorm/shared/foley/ads_in_02.ogg", "sandstorm/shared/foley/ads_in_03.ogg", "sandstorm/shared/foley/ads_in_04.ogg", "sandstorm/shared/foley/ads_in_05.ogg", "sandstorm/shared/foley/ads_in_06.ogg" }, { volume = 0.71, level = 60, pitch = { 98, 102 } })
SandSwep.AddSound("SandSwep.ADS.RifleOut", { "sandstorm/shared/foley/ads_out_01.ogg", "sandstorm/shared/foley/ads_out_02.ogg", "sandstorm/shared/foley/ads_out_03.ogg", "sandstorm/shared/foley/ads_out_04.ogg", "sandstorm/shared/foley/ads_out_05.ogg", "sandstorm/shared/foley/ads_out_06.ogg" }, { volume = 0.71, level = 60, pitch = { 98, 102 } })
SandSwep.AddSound("SandSwep.ADS.SidearmIn", { "sandstorm/shared/foley/ads_in_sidearm_01.ogg", "sandstorm/shared/foley/ads_in_sidearm_02.ogg", "sandstorm/shared/foley/ads_in_sidearm_03.ogg", "sandstorm/shared/foley/ads_in_sidearm_04.ogg", "sandstorm/shared/foley/ads_in_sidearm_05.ogg", "sandstorm/shared/foley/ads_in_sidearm_06.ogg" }, { volume = 0.71, level = 60, pitch = { 98, 102 } })
SandSwep.AddSound("SandSwep.ADS.SidearmOut", { "sandstorm/shared/foley/ads_out_sidearm_01.ogg", "sandstorm/shared/foley/ads_out_sidearm_02.ogg", "sandstorm/shared/foley/ads_out_sidearm_03.ogg", "sandstorm/shared/foley/ads_out_sidearm_04.ogg", "sandstorm/shared/foley/ads_out_sidearm_05.ogg", "sandstorm/shared/foley/ads_out_sidearm_06.ogg" }, { volume = 0.71, level = 60, pitch = { 98, 102 } })
SandSwep.AddSound("SandSwep.Dry.Rifle", { "sandstorm/shared/foley/rifle_dry_fire_01.ogg", "sandstorm/shared/foley/rifle_dry_fire_02.ogg", "sandstorm/shared/foley/rifle_dry_fire_03.ogg" }, { volume = 0.7, level = 60, channel = CHAN_ITEM })
SandSwep.AddSound("SandSwep.Dry.Carbine", { "sandstorm/shared/foley/carbine_dry_fire_01.ogg", "sandstorm/shared/foley/carbine_dry_fire_02.ogg", "sandstorm/shared/foley/carbine_dry_fire_03.ogg" }, { volume = 0.7, level = 60, channel = CHAN_ITEM })
SandSwep.AddSound("SandSwep.Dry.LMG", { "sandstorm/shared/foley/lmg_dry_fire_01.ogg", "sandstorm/shared/foley/lmg_dry_fire_02.ogg", "sandstorm/shared/foley/lmg_dry_fire_03.ogg" }, { volume = 0.7, level = 60, channel = CHAN_ITEM })
SandSwep.AddSound("SandSwep.Dry.Pistol", { "sandstorm/shared/foley/pistol_dry_fire_01.ogg", "sandstorm/shared/foley/pistol_dry_fire_02.ogg", "sandstorm/shared/foley/pistol_dry_fire_03.ogg" }, { volume = 0.7, level = 60, channel = CHAN_ITEM })
SandSwep.AddSound("SandSwep.Dry.SMG", { "sandstorm/shared/foley/smg_dry_fire_01.ogg", "sandstorm/shared/foley/smg_dry_fire_02.ogg", "sandstorm/shared/foley/smg_dry_fire_03.ogg" }, { volume = 0.7, level = 60, channel = CHAN_ITEM })
SandSwep.AddSound("SandSwep.Dry.Launcher", { "sandstorm/shared/foley/launcher_dry_fire_01.ogg", "sandstorm/shared/foley/launcher_dry_fire_02.ogg", "sandstorm/shared/foley/launcher_dry_fire_03.ogg" }, { volume = 0.7, level = 60, channel = CHAN_ITEM })
SandSwep.AddSound("SandSwep.LowAmmo", "weapons/pistol/pistol_empty.wav",
    { volume = 0.35, level = 60, pitch = 100 })
