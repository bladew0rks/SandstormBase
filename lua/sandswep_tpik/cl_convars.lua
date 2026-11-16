SANDTPIK = SANDTPIK or {}

local function cvar(name, default, help, min, max)
    return CreateClientConVar(name, default, true, false, help, min, max)
end

SANDTPIK.CVars = {
    Enabled        = cvar("sandswep_tpik", "1", "Show the real viewmodel animations on player models in third person", 0, 1),
    Others         = cvar("sandswep_tpik_others", "1", "Apply to other players", 0, 1),
    DistanceOthers = cvar("sandswep_tpik_distance", "2048", "Other players past this distance use the plain world model, 0 = no limit", 0, 16384),
    Effects        = cvar("sandswep_tpik_effects", "1", "Third person muzzle flashes come off the animated gun", 0, 1),
    RateLocal      = cvar("sandswep_tpik_rate_local", "60", "Arm IK solve rate for yourself", 5, 150),
    RateOthers     = cvar("sandswep_tpik_rate_others", "30", "Arm IK solve rate for other players", 5, 150),
    LodDistance    = cvar("sandswep_tpik_lod_distance", "768", "Other players past this distance solve their arms less often, 0 = off", 0, 16384),
    MeshLod1       = cvar("sandswep_tpik_mesh_lod1", "512", "Gun models switch to the half detail mesh past this distance, 0 = off", 0, 16384),
    MeshLod2       = cvar("sandswep_tpik_mesh_lod2", "1024", "Gun models switch to the low detail mesh past this distance, 0 = off", 0, 16384),
    Solver         = cvar("sandswep_tpik_solver", "1", "Arm IK solver: 0 = classic, 1 = pole vector", 0, 1),
}
