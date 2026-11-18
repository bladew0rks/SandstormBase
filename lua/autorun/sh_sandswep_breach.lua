SandSwep = SandSwep or {}

local FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY)
local cvShotgun = CreateConVar("sv_sandswep_shotgun_breach", "1", FLAGS, "Shotguns blow doors off their hinges at close range", 0, 1)
local cvExplosive = CreateConVar("sv_sandswep_explosive_breach", "1", FLAGS, "SandSwep explosives blow doors off their hinges", 0, 1)
local cvRespawn = CreateConVar("sv_sandswep_breach_respawn", "30", FLAGS, "Seconds until a breached door respawns (0 = never)", 0, 600)

SandSwep.BreachShotgunRange = 120
SandSwep.BreachBlastMinDamage = 20

function SandSwep.ShotgunBreachEnabled() return cvShotgun:GetBool() end

if CLIENT then return end

local SOUNDS = { "physics/wood/wood_furniture_break1.wav", "physics/wood/wood_furniture_break2.wav" }

local function restoreDoor(door, prop)
    if not IsValid(door) then return end

    local mins, maxs = door:WorldSpaceAABB()
    for _, blocker in ipairs(ents.FindInBox(mins, maxs)) do
        if blocker:IsPlayer() or blocker:IsNPC() then
            timer.Simple(5, function() restoreDoor(door, prop) end)
            return
        end
    end

    if IsValid(prop) then prop:Remove() end

    door:SetNoDraw(false)
    door:SetNotSolid(false)
    door:Fire("Close")
    door.SandSwepBreached = nil
end

function SandSwep.IsBreachable(door)
    return IsValid(door) and door:GetClass() == "prop_door_rotating" and not door.SandSwepBreached
end

function SandSwep.BreachDoor(door, dir, speed, activator)
    if not SandSwep.IsBreachable(door) then return false end

    local prop = ents.Create("prop_physics")
    if not IsValid(prop) then return false end

    prop:SetModel(door:GetModel())
    prop:SetPos(door:GetPos())
    prop:SetAngles(door:GetAngles())
    prop:SetSkin(door:GetSkin())
    for i = 0, door:GetNumBodyGroups() - 1 do prop:SetBodygroup(i, door:GetBodygroup(i)) end
    prop:Spawn()
    prop:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

    local phys = prop:GetPhysicsObject()
    if not IsValid(phys) then
        prop:Remove()
        door:Fire("Unlock")

        if IsValid(activator) then
            door:Fire("OpenAwayFrom", "!activator", 0, activator)
        else
            door:Fire("Open")
        end

        return true
    end

    door.SandSwepBreached = true
    door:Fire("Unlock")
    door:Fire("Open")
    door:SetNoDraw(true)
    door:SetNotSolid(true)

    phys:Wake()
    phys:SetVelocity(dir * speed + Vector(0, 0, speed * 0.15))
    phys:AddAngleVelocity(VectorRand() * speed * 0.5)
    prop:EmitSound(SOUNDS[math.random(#SOUNDS)], 85, math.random(95, 105))

    local delay = cvRespawn:GetFloat()
    if delay > 0 then
        timer.Simple(delay, function() restoreDoor(door, prop) end)
    end

    return true
end

local function IsSandSwepBlast(inflictor)
    if not IsValid(inflictor) then return false end
    return inflictor.IsSandSwep == true or string.StartWith(inflictor:GetClass(), "sandswep_")
end

hook.Add("EntityTakeDamage", "SandSwep.ExplosiveBreach", function(ent, dmg)
    if not cvExplosive:GetBool() or not dmg:IsDamageType(DMG_BLAST) then return end
    if dmg:GetDamage() < SandSwep.BreachBlastMinDamage or not SandSwep.IsBreachable(ent) then return end

    local inflictor = dmg:GetInflictor()
    if not IsSandSwepBlast(inflictor) then return end

    local from = dmg:GetDamagePosition()
    if inflictor ~= ent then from = inflictor:GetPos() end

    local dir = ent:WorldSpaceCenter() - from
    dir.z = 0
    if dir:LengthSqr() < 1 then dir = ent:GetForward() end
    dir:Normalize()

    local speed = math.Clamp(dmg:GetDamage() * 6, 400, 1200)
    SandSwep.BreachDoor(ent, dir, speed, dmg:GetAttacker())
end)
