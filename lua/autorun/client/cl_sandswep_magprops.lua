SandSwep = SandSwep or {}
local MAGPROPS = {
    ["models/weapons/sandswep/v_m110.mdl"] = { [0] = { "models/weapons/sandswep/mags/m110_magazine_10.mdl", "rifle_metal" }, [1] = { "models/weapons/sandswep/mags/m110_magazine_20.mdl", "rifle_metal" } },
    ["models/weapons/sandswep/v_m240.mdl"] = { [0] = { "models/weapons/sandswep/mags/m240_magazine_50.mdl", "lmg_cloth" }, [1] = { "models/weapons/sandswep/mags/m240_magazine_100.mdl", "lmg_cloth" } },
    ["models/weapons/sandswep/v_sand_l96a1.mdl"] = { [0] = { "models/weapons/sandswep/mags/l96_mag5.mdl", "rifle_metal" }, [1] = { "models/weapons/sandswep/mags/l96_mag10.mdl", "rifle_metal" } },
    ["models/weapons/sandswep/v_sand_tac338.mdl"] = { [0] = { "models/weapons/sandswep/mags/tac338_mag5.mdl", "rifle_metal" } },
    ["models/weapons/sandswep/v_sand_m249.mdl"] = { [0] = { "models/weapons/sandswep/mags/m249_magazine_100_nobullets.mdl", "lmg_metal" } },
    ["models/weapons/sandswep/v_sand_m60.mdl"] = { [0] = { "models/weapons/sandswep/mags/m60_mag50.mdl", "lmg_cloth" }, [1] = { "models/weapons/sandswep/mags/m60_mag100.mdl", "lmg_metal" } },
    ["models/weapons/sandswep/v_sand_m82.mdl"] = { [0] = { "models/weapons/sandswep/mags/m82_mag5.mdl", "rifle_metal" }, [1] = { "models/weapons/sandswep/mags/m82_mag10.mdl", "rifle_metal" } },
    ["models/weapons/sandswep/v_sand_m99.mdl"] = { [0] = { "models/weapons/sandswep/mags/m99_mag5.mdl", "rifle_metal" }, [1] = { "models/weapons/sandswep/mags/m99_mag10.mdl", "rifle_metal" } },
    ["models/weapons/sandswep/v_sand_mg3.mdl"] = { [0] = { "models/weapons/sandswep/mags/mg3_mag50.mdl", "lmg_metal" }, [1] = { "models/weapons/sandswep/mags/mg3_mag100.mdl", "lmg_metal" } },
    ["models/weapons/sandswep/v_sand_pkm.mdl"] = { [0] = { "models/weapons/sandswep/mags/pkm_box.mdl", "lmg_metal" } },
    ["models/weapons/sandswep/v_sand_rpk.mdl"] = { [0] = { "models/weapons/sandswep/mags/rpk_mag30.mdl", "rifle_metal" }, [1] = { "models/weapons/sandswep/mags/rpk_mag40.mdl", "rifle_polymer" }, [2] = { "models/weapons/sandswep/mags/rpk_drum.mdl", "rifle_polymer" } },
    ["models/weapons/sandswep/v_sand_um45.mdl"] = { [0] = { "models/weapons/sandswep/mags/um45_magazine_25rd.mdl", "smg_polymer" } },
    ["models/weapons/sandswep/v_sand_uzi.mdl"] = { [0] = { "models/weapons/sandswep/mags/uzi_magazine_32.mdl", "smg_metal" }, [1] = { "models/weapons/sandswep/mags/uzi_magazine_50.mdl", "smg_polymer" } },
}
SandSwep.MagProps = SandSwep.MagProps or {}
for k, v in pairs(MAGPROPS) do SandSwep.MagProps[k] = v end

