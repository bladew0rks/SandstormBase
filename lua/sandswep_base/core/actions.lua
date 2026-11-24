local Developer = SandSwep.BaseShared.Developer

-- Actions
SWEP.Actions = {}
local ACTION_NAMES = {}

local function ActionDebug(wep, fmt, ...)
    if not Developer() then return end
    if CLIENT and not IsFirstTimePredicted() then return end   -- predicted code runs again on every resim

    print(string.format("[sandswep %s %s %.2f] " .. fmt, SERVER and "SV" or "CL", wep:GetClass(), CurTime(), ...))
end

local function RegisterAction(name, def)
    ACTION_NAMES[#ACTION_NAMES + 1] = name
    def.Name, def.Id = name, #ACTION_NAMES
    def.Blocks = def.Blocks or {}
    SWEP.Actions[name] = def
end

function SWEP:GetCurrentAction()
    local id = self:GetAction()
    if id <= 0 or CurTime() >= self:GetActionUntil() then return nil end

    return self.Actions[ACTION_NAMES[id]]
end

function SWEP:IsInAction(name)
    local def = self:GetCurrentAction()
    return def ~= nil and def.Name == name
end

function SWEP:ActionBlocks(what)
    local def = self:GetCurrentAction()
    return def ~= nil and def.Blocks[what] == true
end

function SWEP:GetActionProgress()
    local start = self:GetActionStart()
    local duration = math.max(self:GetActionUntil() - start, 0.001)

    return math.Clamp((CurTime() - start) / duration, 0, 1)
end

function SWEP:BeginAction(name, duration, eventDelay)
    local def = self.Actions[name]
    local running = self:GetCurrentAction()

    if running then
        ActionDebug(self, "%s replaced by %s at %d%%", running.Name, name, self:GetActionProgress() * 100)
        self:SetAction(0)
        if running.Stop then running.Stop(self) end
    end

    local ct = CurTime()
    self:SetAction(def.Id)
    self:SetActionStart(ct)
    self:SetActionUntil(ct + duration)
    self:SetActionEvent(eventDelay and ct + eventDelay or 0)
    self._actionSeen = def.Id

    ActionDebug(self, "%s started: %.2fs%s", name, duration,
        eventDelay and string.format(", event at +%.2fs", eventDelay) or "")
end

function SWEP:ClearAction(name)
    if name and self:GetAction() ~= self.Actions[name].Id then return end

    self:SetAction(0)
    self:SetActionUntil(0)
    self:SetActionEvent(0)
    self._actionSeen = 0
end

function SWEP:StartAction(name, ...)
    local def = self.Actions[name]
    if not def then
        ActionDebug(self, "%s: no such action", tostring(name))
        return false
    end

    if self:ActionBlocks(name) then
        ActionDebug(self, "%s refused: %s is running", name, self:GetCurrentAction().Name)
        return false
    end

    if def.CanStart then
        local ok, why = def.CanStart(self, ...)
        if not ok then
            ActionDebug(self, "%s refused: %s", name, why or "can't start")
            return false
        end
    end

    local duration, eventDelay = def.Start(self, ...)
    if not duration then
        ActionDebug(self, "%s refused: didn't play", name)
        return false
    end

    self:BeginAction(name, duration, eventDelay)
    return true
end

function SWEP:StopAction()
    local def = self:GetCurrentAction()
    if def then
        ActionDebug(self, "%s stopped at %d%%", def.Name, self:GetActionProgress() * 100)
        self:SetAction(0)
        if def.Stop then def.Stop(self) end
    end

    self:ClearAction()
end

function SWEP:UpdateAction()
    local id = self:GetAction()

    if CLIENT and id ~= (self._actionSeen or 0) then
        self._actionSeen = id
        ActionDebug(self, "now %s (from the server)", ACTION_NAMES[id] or "none")
    end

    if id <= 0 then return end
    local def = self.Actions[ACTION_NAMES[id]]

    local ct = CurTime()
    local eventAt = self:GetActionEvent()
    if eventAt > 0 and ct >= eventAt then
        self:SetActionEvent(0)
        ActionDebug(self, "%s event", def.Name)
        if def.Event then def.Event(self) end
        if self:GetAction() ~= id then return end
    end

    if ct >= self:GetActionUntil() and self:GetActionEvent() <= 0 then
        ActionDebug(self, "%s finished", def.Name)
        self:ClearAction()
        if def.Finish then def.Finish(self) end
    end
end

local ANIM_BLOCKS = { sprint = true, gl = true, melee = true }

RegisterAction("draw", { Blocks = ANIM_BLOCKS })
RegisterAction("ready", { Blocks = { sprint = true, gl = true, melee = true, customize = true } })
RegisterAction("fireselect", { Blocks = ANIM_BLOCKS })
RegisterAction("tubeswap", { Blocks = ANIM_BLOCKS })
RegisterAction("gltoggle", { Blocks = ANIM_BLOCKS })
RegisterAction("bipod_in", { Blocks = ANIM_BLOCKS })
RegisterAction("bipod_out", { Blocks = ANIM_BLOCKS })
RegisterAction("fidget", {})
RegisterAction("holster", {
    Blocks = {
        aim = true,
        reload = true,
        gl = true,
        firemode = true,
        bipod = true,
        sprint = true,
        fidget = true,
        melee = true,
        magcheck = true,
        customize = true,
    },
})

RegisterAction("sight", {
    Blocks = ANIM_BLOCKS,
    Event = function(wep) wep:ApplySightSwitch(wep:GetSightPending()) end,
    Stop = function(wep)
        if wep:GetActionEvent() > 0 then wep:ApplySightSwitch(wep:GetSightPending()) end
    end,
})

RegisterAction("glreload", {
    Blocks = {
        sprint = true,
        gl = true,
        melee = true,
        reload = true,
        magcheck = true,
        firemode = true,
        fidget = true,
    },
    Event = function(wep) wep:FinishGLReload() end,
})

RegisterAction("reload", {
    Blocks = {
        sprint = true,
        gl = true,
        melee = true,
        reload = true,
        magcheck = true,
        firemode = true,
        fidget = true,
        bipod = true,
    },
    Event = function(wep) wep:InsertReloadEvent() end,
    Finish = function(wep) wep:FinishReload() end,
    Stop = function(wep) wep:InterruptReload() end,
})

-- Melee
RegisterAction("melee", {
    Blocks = {
        aim = true,
        reload = true,
        gl = true,
        firemode = true,
        bipod = true,
        sprint = true,
        fidget = true,
        melee = true,
        magcheck = true,
    },

    CanStart = function(wep)
        if not wep.MeleeEnabled then return false, "melee is off on this gun" end

        local owner = wep:GetOwner()
        if not IsValid(owner) or not owner:IsPlayer() then return false, "no player holding it" end
        if wep:IsReloading() then return false, "reloading" end

        return true
    end,

    Start = function(wep)
        local owner = wep:GetOwner()
        local ct = CurTime()

        wep:ResetSprint()
        wep:SetAimState(false)
        wep:SetAimToggled(false)
        wep:SetBurstLeft(0)

        local played = wep:HasAnim("melee") and wep:PlayAnim("melee")
        local recovery = wep.MeleeRecovery
        if played then recovery = math.min(recovery, wep:GetAnimLength("melee")) end

        wep:SetNextPrimaryFire(math.max(wep:GetNextPrimaryFire(), ct + recovery))

        if wep.MeleeSwingSound then wep:EmitSound(wep.MeleeSwingSound, 65, math.random(92, 100), 0.6) end
        owner:DoAnimationEvent(ACT_GMOD_GESTURE_MELEE_SHOVE_2HAND)

        return recovery, wep.MeleeHitTime
    end,

    Event = function(wep)
        if SERVER then wep:DoMeleeHit() end
    end,
})

function SWEP:StartMelee()
    return self:StartAction("melee")
end

function SWEP:DoMeleeHit()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local start = owner:GetShootPos()
    local dir = self.GetAimDirection and self:GetAimDirection() or owner:GetAimVector()
    local hull = Vector(self.MeleeHullSize, self.MeleeHullSize, self.MeleeHullSize)

    owner:LagCompensation(true)
    local tr = util.TraceHull({
        start = start,
        endpos = start + dir * self.MeleeRange,
        mins = -hull,
        maxs = hull,
        filter = owner,
        mask = MASK_SHOT_HULL,
    })
    owner:LagCompensation(false)

    if not tr.Hit then return end

    local ent = tr.Entity
    local fleshy = IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() or ent:GetClass() == "prop_ragdoll")
    local snd = fleshy and self.MeleeHitFleshSound or self.MeleeHitWorldSound
    if snd then sound.Play(snd, tr.HitPos, 75, math.random(95, 105), 1) end
    owner:ViewPunch(Angle(1.5, math.Rand(-1, 1), 0))

    if not IsValid(ent) then
        if tr.HitWorld then util.Decal("Impact.Concrete", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal, owner) end
        return
    end

    local dmg = DamageInfo()
    dmg:SetDamage(self.MeleeDamage)
    dmg:SetDamageType(DMG_CLUB)
    dmg:SetAttacker(owner)
    dmg:SetInflictor(self)
    dmg:SetDamagePosition(tr.HitPos)
    dmg:SetDamageForce(dir * self.MeleeForce)
    ent:TakeDamageInfo(dmg)

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) and not ent:IsPlayer() and not ent:IsNPC() then
        phys:ApplyForceOffset(dir * self.MeleeForce * 0.5, tr.HitPos)
    end
end

-- Mag check

RegisterAction("magcheck", {
    Blocks = {
        aim = true,
        reload = true,
        gl = true,
        bipod = true,
        sprint = true,
        fidget = true,
        melee = true,
        magcheck = true,
    },

    CanStart = function(wep)
        if wep:IsReloading() then return false, "reloading" end
        if wep:GetGLMode() then return false, "launcher selected" end
        if wep:IsGLReloading() then return false, "launcher reloading" end

        return true
    end,

    Start = function(wep)
        local ct = CurTime()
        local rate = math.max(wep.MagCheckSpeed or 1, 0.01)

        if wep:HasAnim("checkammo") then
            local len = wep:GetAnimLength("checkammo") / rate
            wep:SetNextPrimaryFire(ct + len)
            wep:PlayAnim("checkammo", rate)
            wep:StartSoundSet("magcheck", len)     -- sound times scale with it
            return len
        end

        local len = wep.MagCheckTime / rate
        wep:SetNextPrimaryFire(ct + len)
        wep:StartSoundSet("magcheck", len)

        return len
    end,
})

function SWEP:StartMagCheck()
    if self.NoMagCheck then return false end
    return self:StartAction("magcheck")
end

function SWEP:UsesProceduralMagCheck()
    if self:HasAnim("checkammo") then return false end
    if self.ProceduralMagCheck ~= nil then return self.ProceduralMagCheck end

    return true
end

function SWEP:IsMagChecking()
    return self:IsInAction("magcheck")
end
