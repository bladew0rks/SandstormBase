-- Underbarrel grenade launcher

function SWEP:GetGLDef()
    return (self:GetFeatureDef("GL"))
end

function SWEP:GetGLConfig()
    local def = self:GetGLDef()
    if not def then return end

    if self._glCfgDef ~= def then
        local cfg = table.Copy(self.GLDefaults)
        if istable(def.GL) then table.Merge(cfg, def.GL) end
        self._glCfgDef, self._glCfg = def, cfg

        local ammoType = game.GetAmmoID(cfg.Ammo or "")
        if ammoType >= 0 then self._glAmmoType = ammoType end
    end

    return self._glCfg
end

function SWEP:IsGLReloading()
    return self:IsInAction("glreload") and self:GetActionEvent() > 0
end

function SWEP:GetGLAmmoType()
    local ammoType = self:GetSecondaryAmmoType()
    if ammoType and ammoType >= 0 then return ammoType end

    local cfg = self:GetGLConfig()
    return cfg and game.GetAmmoID(cfg.Ammo) or -1
end

function SWEP:GetGLLoaded()
    return self:Clip2() > 0
end

function SWEP:GetGLReserve()
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() or not self:GetGLConfig() then return 0 end

    local ammoType = self:GetGLAmmoType()
    return ammoType >= 0 and owner:GetAmmoCount(ammoType) or 0
end

function SWEP:ToggleGLMode()
    local ct = CurTime()
    local on = not self:GetGLMode()
    if on and not self:GetGLDef() then return end
    if self:IsReloading() or self:IsGLReloading() or self:ActionBlocks("gl") then return end

    self:SetBurstLeft(0)
    self:SetGLMode(on)

    local anim = on and "gl_in" or "gl_out"
    if self:HasAnim(anim) then
        local len = self:GetAnimLength(anim)
        self:PlayAnim(anim)
        self:BeginAction("gltoggle", len * 0.8)
        self:SetNextPrimaryFire(ct + len * 0.8)
        self:StartSoundSet(anim, len)
    else
        self:PlayIdleAnim()
        self:SetNextPrimaryFire(ct + 0.3)
    end
end

function SWEP:FireGL()
    local owner = self:GetOwner()
    local cfg = self:GetGLConfig()
    if not cfg or not IsValid(owner) then return end

    local ct = CurTime()
    local aimed = self:GetAimProgress() > 0.5

    if not self:GetGLLoaded() then
        if cfg.DrySound then self:EmitSound(cfg.DrySound) end
        self:PlayAnim(aimed and self:HasAnim("iron_dryfire") and "iron_dryfire" or "dryfire")
        self:SetNextPrimaryFire(ct + 0.4)
        return
    end

    self:SetClip2(self:Clip2() - 1)
    self:SetNextPrimaryFire(ct + cfg.FireDelay)
    self:PlayAnim(aimed and self:HasAnim("iron_fire") and "iron_fire" or "fire")
    if cfg.Sound then self:EmitSound(cfg.Sound) end
    owner:SetAnimation(PLAYER_ATTACK1)

    local recoil = cfg.Recoil * self:GetRecoilScale()
    owner:ViewPunch(Angle(-recoil, util.SharedRandom("sandswep_glrecoil", -1, 1) * recoil * 0.3, 0))

    if cfg.Pellets then
        local spread = cfg.Spread or 0.06
        local src, dir = owner:GetShootPos(), self:GetAimDirection()
        owner:FireBullets({
            Num = cfg.Pellets,
            Src = src,
            Dir = dir,
            Spread = Vector(spread, spread, 0),
            Tracer = 1,
            Force = 2,
            Damage = (cfg.PelletDamage or 12) * self:GetDamageMult(),
            AmmoType = cfg.Ammo,
        })
        self:TryBreach(src, dir, true)
        return
    end

    if SERVER then
        local dir = self:GetAimDirection()
        local start = owner:GetShootPos()
        local spawnPos = start + dir * 18 - owner:EyeAngles():Up() * 3 + owner:EyeAngles():Right() * 2
        local tr = SandSwep.TraceLine(start, spawnPos, owner, MASK_SHOT)

        local nade = ents.Create("sandswep_40mm")
        if IsValid(nade) then
            nade:SetPos(tr.Hit and (tr.HitPos - dir * 2) or spawnPos)
            nade:SetAngles(dir:Angle())
            nade:SetOwner(owner)
            nade.Attacker = owner
            nade.Damage, nade.Radius = cfg.Damage, cfg.Radius
            nade.ArmDistance, nade.DudDamage = cfg.ArmDistance, cfg.DudDamage
            nade:Spawn()
            nade.StartPos = owner:GetShootPos()      -- arming distance counts from the shooter
            nade:Launch(dir * cfg.Velocity + owner:GetVelocity() * 0.5)
        end
    end
end

function SWEP:StartGLReload()
    local cfg = self:GetGLConfig()
    if not cfg or self:GetGLLoaded() or self:IsGLReloading() then return end
    if self:GetGLReserve() <= 0 then return end

    local ct = CurTime()
    if self:ActionBlocks("gl") then return end

    self:SetAimToggled(false)

    local speed = self:GetReloadSpeed()
    local commit, len = self:GetAnimCommit("reload")
    if self:HasAnim("reload") then
        self:PlayAnim("reload", speed)
    else
        commit, len = 1.5, 1.5
    end
    commit, len = commit / speed, len / speed

    self:BeginAction("glreload", len, commit)
    self:SetNextPrimaryFire(ct + len)
    self:StartSoundSet("gl_reload", len)
end

function SWEP:FinishGLReload()
    local owner = self:GetOwner()
    if not self:GetGLConfig() or not IsValid(owner) or not owner:IsPlayer() then return end

    local ammoType = self:GetGLAmmoType()
    if ammoType < 0 or owner:GetAmmoCount(ammoType) <= 0 then return end

    owner:RemoveAmmo(1, ammoType)
    self:SetClip2(1)
end

function SWEP:UpdateGLState()
    local key = self:GetAttData()
    if self._idleAttKey ~= key then
        local first = self._idleAttKey == nil
        self._idleAttKey = key
        if not first and not self:IsActionBusy() and not self:GetSprinting() then self:PlayIdleAnim() end
    end

    local cfg = self:GetGLConfig()
    local owner = self:GetOwner()

    if not cfg then
        if self:GetGLMode() then
            self:SetGLMode(false)
            self:PlayIdleAnim()
        end
        self:ClearAction("glreload")

        if self:Clip2() > 0 then
            local ammoType = self:GetSecondaryAmmoType()
            if ammoType < 0 then ammoType = self._glAmmoType or -1 end
            if IsValid(owner) and owner:IsPlayer() and ammoType >= 0 then owner:GiveAmmo(self:Clip2(), ammoType, true) end
            self:SetClip2(0)
        end
        return
    end

    if not self:GetGLGiven() then
        self:SetGLGiven(true)
        self:SetClip2(1)
        if IsValid(owner) and owner:IsPlayer() and (cfg.StartAmmo or 0) > 0 then
            owner:GiveAmmo(cfg.StartAmmo, self:GetGLAmmoType(), true)
        end
    end
end