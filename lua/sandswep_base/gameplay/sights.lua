local VisualFrameTime = SandSwep.VisualFrameTime

local SinceTime = SandSwep.BaseShared.SinceTime

-- Attachments

local NO_SLOTS = {}

function SWEP:GetAttachmentSlots()
    return self.AttachmentSlots or NO_SLOTS
end

local function OverrideDef(wep, id, def)
    local override = wep.AttachmentOverrides and wep.AttachmentOverrides[id]
    if not override then return def end

    local cache = wep._attOverrideDefs or {}
    wep._attOverrideDefs = cache

    local merged = cache[id]
    if not merged or merged._base ~= def then
        merged = setmetatable({ _base = def }, { __index = def })
        for k, v in pairs(override) do merged[k] = v end
        cache[id] = merged
    end

    return merged
end

function SWEP:AttCache()
    local key, rev = self:GetAttData(), SandSwep.AttRev
    local cache = self._attCache
    if cache and cache.key == key and cache.rev == rev then return cache end

    local atts = {}
    for slot, id in string.gmatch(key, "([%w_]+)=([%w_]+)") do atts[slot] = id end

    local slots = self:GetAttachmentSlots()
    local names = {}
    for name, slot in pairs(slots) do
        if (atts[name] or slot.Fallback) and not (slot.RequiresSlot and not atts[slot.RequiresSlot]) then
            names[#names + 1] = name
        end
    end
    table.sort(names)

    local list, pos = {}, {}
    for _, name in ipairs(names) do
        local id = atts[name] or slots[name].Fallback
        local def = SandSwep.Attachments[id]
        if def then
            def = OverrideDef(self, id, def)
            list[#list + 1] = { name, id, def, slots[name] }
            pos[name] = #list
        end
    end

    cache = {
        key = key,
        rev = rev,
        atts = atts,
        list = list,
        pos = pos,
        stats = {},
        feat = {},
    }
    self._attCache = cache

    return cache
end

function SWEP:GetSlotAttachments()
    return self:AttCache().atts
end

function SWEP:GetSlotAttachment(slot)
    return self:GetSlotAttachments()[slot]
end

function SWEP:GetSlotSkins()
    local data = self:GetAttSkins()

    if self._skinStr ~= data then
        local skins = {}
        for slot, skin in string.gmatch(data, "([%w_]+)=(%d+)") do skins[slot] = tonumber(skin) end
        self._skinStr, self._skins = data, skins
    end

    return self._skins
end

function SWEP:GetSlotSkin(slot)
    return self:GetSlotSkins()[slot] or 0
end

function SWEP:SetSlotSkin(slot, skin)
    local skins = table.Copy(self:GetSlotSkins())
    skins[slot] = (skin and skin > 0) and math.floor(skin) or nil

    local parts = {}
    for k, v in pairs(skins) do parts[#parts + 1] = k .. "=" .. v end
    table.sort(parts)

    self:SetAttSkins(table.concat(parts, ";"))
end

function SWEP:GetAttachmentSkin(slot, def)
    local option = def and def.Skins and def.Skins[self:GetSlotSkin(slot) + 1]
    return option and option.Skin or 0
end

function SWEP:GetSlotAttachmentDef(slot)
    return SandSwep and SandSwep.GetAttachmentDef(self:GetSlotAttachment(slot))
end

local function NextAtt(cache, name)
    local entry = cache.list[(name and cache.pos[name] or 0) + 1]
    if entry then return entry[1], entry[2], entry[3], entry[4] end
end

function SWEP:IterAttachments()
    return NextAtt, self:AttCache(), nil
end

function SWEP:CanAttach(slotName, id)
    local slot = self:GetAttachmentSlots()[slotName]
    if not slot then return false end
    if id == nil then return true end
    if slot.RequiresSlot and not self:GetSlotAttachment(slot.RequiresSlot) then return false end
    if not (SandSwep and SandSwep.Attachments[id]) then return false end

    for _, allowed in ipairs(slot.Attachments or {}) do
        if allowed == id then
            if self:GetAttachBlock(slotName, id) ~= nil then return false end
            return hook.Run("SandSwep_CanAttach", self, slotName, id) ~= false
        end
    end

    return false
end

function SWEP:GetAttachBlock(slotName, id)
    local def = id and SandSwep.Attachments[id]
    local slot = self:GetAttachmentSlots()[slotName]

    for _, need in ipairs({ slot and slot.RequiresAttachment, def and def.RequiresAttachment }) do
        if need and not self:GetSlotAttachment(need.Slot) then
            return need.Reason or "Requires another attachment"
        end
    end
end

function SWEP:SetSlotAttachment(slotName, id)
    local current = self:GetSights()[self:GetSightIndex()]
    local keepSlot, keepName = current and current.AttSlot, current and current.Name
    local atts = table.Copy(self:GetSlotAttachments())
    local prevMode = self:GetFireMode()

    atts[slotName] = id
    local parts = {}
    for slot, att in pairs(atts) do parts[#parts + 1] = slot .. "=" .. att end
    table.sort(parts)
    self:SetAttData(table.concat(parts, ";"))
    hook.Run("SandSwep_AttachmentsChanged", self)

    local newDef = id and SandSwep.Attachments[id]
    local mode = self:FindFireMode((newDef and newDef.DefaultFireMode) or prevMode) or self:FirstFiringMode()
    if mode and mode ~= self:GetFireModeIndex() then self:SetFireModeIndex(mode) end

    local idx = 1
    if keepSlot and keepSlot ~= slotName then
        for i, sight in ipairs(self:GetSights()) do
            if sight.AttSlot == keepSlot and sight.Name == keepName then
                idx = i
                break
            end
        end
    end

    self:SetSightIndex(idx)
    self:ClearAction("sight")
    if not self:GetFeatureDef("Laser") then self:SetLaserOn(false) end
    if not self:GetFeatureDef("Light") then self:SetLightOn(false) end
    if self:GetBipodDeployed() and not self:HasBipod() then self:StowBipod(false) end

    if id then return end

    for other, att in pairs(self:GetSlotAttachments()) do
        if other ~= slotName and self:GetAttachBlock(other, att) then
            self:SetSlotAttachment(other, nil)
            return
        end
    end
end

function SWEP:ApplyLoadout(attStr, skinStr)
    local slots = self:GetAttachmentSlots()
    local atts = {}

    for slot, id in string.gmatch(attStr or "", "([%w_]+)=([%w_]+)") do
        if slots[slot] and not slots[slot].Hidden and self:CanAttach(slot, id) then atts[slot] = id end
    end
    for slotName, slot in pairs(slots) do
        if slot.Hidden then atts[slotName] = self:GetSlotAttachment(slotName) end
    end

    local parts = {}
    for slot, att in pairs(atts) do parts[#parts + 1] = slot .. "=" .. att end
    table.sort(parts)
    self:SetAttData(table.concat(parts, ";"))
    hook.Run("SandSwep_AttachmentsChanged", self)

    local skins = {}
    for slot, skin in string.gmatch(skinStr or "", "([%w_]+)=(%d+)") do
        local def = atts[slot] and SandSwep.Attachments[atts[slot]]
        skin = tonumber(skin)
        if def and def.Skins and skin and skin > 0 and skin < #def.Skins then
            skins[#skins + 1] = slot .. "=" .. math.floor(skin)
        end
    end
    table.sort(skins)
    self:SetAttSkins(table.concat(skins, ";"))

    self:SetSightIndex(1)
    self:ClearAction("sight")
    if not self:GetFeatureDef("Laser") then self:SetLaserOn(false) end
    if not self:GetFeatureDef("Light") then self:SetLightOn(false) end
    if self:GetBipodDeployed() and not self:HasBipod() then self:StowBipod(false) end
end

function SWEP:ApplyDefaultAttachments()
    for slotName, slot in pairs(self:GetAttachmentSlots()) do
        if slot.Default and self:CanAttach(slotName, slot.Default) then
            self:SetSlotAttachment(slotName, slot.Default)
        end
    end
end

function SWEP:GetDesiredPoseParams()
    local cache = self:AttCache()
    if cache.poses then return cache.poses end

    local poses = {}
    for _, slot in pairs(self:GetAttachmentSlots()) do
        for _, id in ipairs(slot.Attachments or {}) do
            local def = SandSwep.Attachments[id]
            for name in pairs(def and def.PoseParams or {}) do poses[name] = 0 end
        end
    end
    for _, _, def in self:IterAttachments() do
        for name, value in pairs(def.PoseParams or {}) do poses[name] = value end
    end

    cache.poses = poses
    return poses
end

local function BaseBodygroups(wep)
    local cache = wep:AttCache()
    if cache.bodygroups then return cache.bodygroups end

    local groups = {}
    for _, slot in pairs(wep:GetAttachmentSlots()) do
        for name in pairs(slot.Bodygroups or {}) do groups[name] = 0 end
        for name in pairs(slot.GripBodygroups or {}) do groups[name] = 0 end

        for _, id in ipairs(slot.Attachments or {}) do
            local def = SandSwep.Attachments[id]
            for name in pairs(def and def.Bodygroups or {}) do groups[name] = 0 end
        end

        local fallback = slot.Fallback and SandSwep.Attachments[slot.Fallback]
        for name in pairs(fallback and fallback.Bodygroups or {}) do groups[name] = 0 end
    end

    for name, value in pairs(wep.Bodygroups or {}) do groups[name] = value end

    for _, _, def, slot in wep:IterAttachments() do
        for name, value in pairs(slot.Bodygroups or {}) do groups[name] = value end
        if slot.GripBodygroups and def.AnimSet and def.AnimSet ~= "gl" then
            for name, value in pairs(slot.GripBodygroups) do groups[name] = value end
        end
        for name, value in pairs(def.Bodygroups or {}) do groups[name] = value end
    end

    cache.bodygroups = groups
    return groups
end

function SWEP:GetDesiredBodygroups()
    local groups = {}
    for name, value in pairs(BaseBodygroups(self)) do groups[name] = value end

    if self.MagOutBodygroups and self:IsMagHidden() then
        for name, value in pairs(self.MagOutBodygroups) do groups[name] = value end
    end

    if self.BeltBodygroup then
        groups[self.BeltBodygroup.Name] = self:GetLiveBelt() and 0 or self:GetBeltLinks()
    end
    if self.BeltLinksBodygroup then groups[self.BeltLinksBodygroup] = self:GetBeltLinksShown() end

    return groups
end

function SWEP:GetDesiredSkin()
    local cache = self:AttCache()
    if cache.skin then return cache.skin end

    local skin, offset = self.ViewSkin or 0, 0
    for _, _, def in self:IterAttachments() do
        if def.ViewSkin then skin = def.ViewSkin end
        if def.ViewSkinOffset then offset = offset + def.ViewSkinOffset end
    end

    cache.skin = skin + offset
    return cache.skin
end

function SWEP:GetVMBodygroupList(vm)
    local cached = self._bgList
    local att, model, noMag = self:GetAttData(), vm:GetModel(), self:IsMagHidden()
    local belt = self.BeltBodygroup and self:GetBeltLinks() or 0
    local links = self.BeltLinksBodygroup and self:GetBeltLinksShown() or 0

    if cached and cached.att == att and cached.model == model and cached.noMag == noMag
        and cached.belt == belt and cached.links == links then
        return cached.list, cached.skin
    end

    local list = {}
    for name, value in pairs(self:GetDesiredBodygroups()) do
        local id = vm:FindBodygroupByName(name)
        if id and id >= 0 then
            list[#list + 1] = id
            list[#list + 1] = value
        end
    end

    cached = {
        att = att,
        model = model,
        noMag = noMag,
        belt = belt,
        links = links,
        list = list,
        skin = self:GetDesiredSkin(),
    }
    self._bgList = cached

    return list, cached.skin
end

function SWEP:ApplyVMBodygroups(vm)
    vm.SandSwepBodygroups = true

    local list, skin = self:GetVMBodygroupList(vm)
    for i = 1, #list, 2 do
        if vm:GetBodygroup(list[i]) ~= list[i + 1] then vm:SetBodygroup(list[i], list[i + 1]) end
    end

    if vm:GetSkin() ~= skin then vm:SetSkin(skin) end
end

function SWEP:UpdateVMBodygroups(reset)
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() then return end

    local vm = owner:GetViewModel()
    if not IsValid(vm) then return end

    if reset then
        if vm.SandSwepBodygroups then
            for i = 0, vm:GetNumBodyGroups() - 1 do vm:SetBodygroup(i, 0) end
            vm:SetSkin(0)
            vm.SandSwepBodygroups = nil
        end
        self._svBgList = nil
        return
    end

    if SERVER then
        local list = self:GetVMBodygroupList(vm)
        if self._svBgList == list and self._svBgVM == vm then return end
        self._svBgList, self._svBgVM = list, vm
    end

    self:ApplyVMBodygroups(vm)
end

local FIREMODE_POSE = { safe = 0, semi = 1, burst = 2, auto = 3 }

function SWEP:ApplyVMFireModePose(vm)
    if vm:LookupPoseParameter("firemode") < 0 then return end
    vm:SetPoseParameter("firemode", FIREMODE_POSE[self:GetFireMode()] or 1)
end

function SWEP:UpdateVMPoseParams(reset)
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() then return end

    local vm = owner:GetViewModel()
    if not IsValid(vm) then return end

    if reset then
        if vm:LookupPoseParameter("firemode") >= 0 then vm:SetPoseParameter("firemode", 0) end
        self._svModeKey, self._svModeModel = nil, nil
    else
        local mode, model = self:GetFireMode(), vm:GetModel()
        if self._svModeKey ~= mode or self._svModeModel ~= model then
            self._svModeKey, self._svModeModel = mode, model
            self:ApplyVMFireModePose(vm)
        end
    end

    local want = self:GetDesiredPoseParams()
    if not next(want) then return end

    if reset then
        for name in pairs(want) do vm:SetPoseParameter(name, 0) end
        self._svPoseKey, self._svPoseModel = nil, nil
        return
    end

    local att, model = self:GetAttData(), vm:GetModel()
    if self._svPoseKey == att and self._svPoseModel == model then return end
    self._svPoseKey, self._svPoseModel = att, model

    for name, target in pairs(want) do vm:SetPoseParameter(name, target) end
end

function SWEP:GetStatMult(stat)
    local stats = self:AttCache().stats
    local cached = stats[stat]
    if cached then return cached end

    local mult = 1
    for _, _, def in self:IterAttachments() do
        if def.Stats and def.Stats[stat] then mult = mult * def.Stats[stat] end
    end

    local override = hook.Run("SandSwep_StatMult", self, stat, mult)
    if isnumber(override) then mult = override end

    stats[stat] = mult
    return mult
end

function SWEP:IsIntegratedBlocked()
    for slot in pairs(self.Integrated and self.Integrated.BlockedBy or {}) do
        if self:GetSlotAttachment(slot) then return true end
    end
    return false
end

function SWEP:GetFeatureDef(feature)
    local feat = self:AttCache().feat
    local found = feat[feature]

    if found == nil then
        found = false
        for slotName, _, def in self:IterAttachments() do
            if def[feature] then
                found = { def, slotName }
                break
            end
        end

        if not found and self.Integrated and self.Integrated[feature] and not self:IsIntegratedBlocked() then
            found = { self.Integrated }
        end

        feat[feature] = found
    end

    if found then return found[1], found[2] end
end

function SWEP:GetTacticalDef()
    local cache = self:AttCache()

    if cache.tac == nil then
        cache.tac = false
        for slotName, _, def in self:IterAttachments() do
            if def.Laser or def.Light then
                cache.tac = { def, slotName }
                break
            end
        end
    end

    if cache.tac then return cache.tac[1], cache.tac[2] end
end

function SWEP:GetTacticalOn()
    return self:GetLaserOn() or self:GetLightOn()
end

function SWEP:CycleTactical()
    local caps = self:GetTacticalCaps()
    if caps == 0 then return false end

    local hasLaser, hasLight = bit.band(caps, 1) ~= 0, bit.band(caps, 2) ~= 0
    local modes = { { false, false } }
    if hasLaser then modes[#modes + 1] = { true, false } end
    if hasLight then modes[#modes + 1] = { false, true } end
    if hasLaser and hasLight then modes[#modes + 1] = { true, true } end

    local laser, light = self:GetLaserOn(), self:GetLightOn()
    local current = 1
    for i, mode in ipairs(modes) do
        if mode[1] == laser and mode[2] == light then current = i end
    end

    local nextMode = modes[current % #modes + 1]
    self:SetLaserOn(nextMode[1])
    self:SetLightOn(nextMode[2])

    return true
end

SWEP.TAC_LASER, SWEP.TAC_LIGHT = 1, 2
SWEP.TAC_VIS, SWEP.TAC_IR, SWEP.TAC_ILLUM = 4, 8, 16
local TAC_MAIN, TAC_SUB = 3, 28
local TAC_PICKED = 32

function SWEP:GetTacticalCaps()
    local laserDef = self:GetFeatureDef("Laser")
    local caps = (laserDef and 1 or 0) + (self:GetFeatureDef("Light") and 2 or 0)

    if laserDef then
        local ir = SandSwep.IR ~= nil      -- night vision / IR add-on installed
        caps = caps + 4
            + ((ir and laserDef.IRLaser) and 8 or 0)
            + ((ir and laserDef.IRIllum) and 16 or 0)
    end

    return caps
end

local function CleanTacMode(mode, caps)
    mode = bit.band(tonumber(mode) or 0, caps)

    local sub = bit.band(mode, TAC_SUB)
    if bit.band(sub, 12) == 12 then sub = sub - 4 end
    if bit.band(mode, 1) ~= 0 and sub == 0 then sub = bit.band(4, caps) end

    return bit.bor(bit.band(mode, TAC_MAIN), sub)
end

function SWEP:GetTacticalMode()
    local caps = self:GetTacticalCaps()
    local raw = self:GetTacSelect()

    local main = bit.band(raw, caps, TAC_MAIN)
    if main == 0 and bit.band(raw, TAC_PICKED) == 0 then main = bit.band(caps, TAC_MAIN) end

    return CleanTacMode(bit.bor(main, bit.band(raw, TAC_SUB)), caps)
end

function SWEP:GetLaserModeBits()
    if not self:GetLaserOn() then return 0 end
    return bit.band(self:GetTacticalMode(), TAC_SUB)
end
function SWEP:GetVisLaserOn() return bit.band(self:GetLaserModeBits(), 4) ~= 0 end
function SWEP:GetIRLaserOn() return bit.band(self:GetLaserModeBits(), 8) ~= 0 end
function SWEP:GetIRIllumOn() return bit.band(self:GetLaserModeBits(), 16) ~= 0 end

function SWEP:SetTacticalMode(mode)
    local caps = self:GetTacticalCaps()
    mode = CleanTacMode(mode, caps)
    self:SetTacSelect(bit.bor(mode, TAC_PICKED))

    if self:GetTacticalOn() then
        self:SetLaserOn(bit.band(mode, 1) ~= 0)
        self:SetLightOn(bit.band(mode, 2) ~= 0)
    end

    return true
end

function SWEP:ToggleTactical()
    if self:GetTacticalCaps() == 0 then return false end

    if self:GetTacticalOn() then
        self:SetLaserOn(false)
        self:SetLightOn(false)
    else
        local mode = self:GetTacticalMode()
        if bit.band(mode, TAC_MAIN) == 0 then return false end   -- nothing selected
        self:SetLaserOn(bit.band(mode, 1) ~= 0)
        self:SetLightOn(bit.band(mode, 2) ~= 0)
    end

    return true
end

function SWEP:ToggleLaser()
    if not self:GetFeatureDef("Laser") then return false end
    self:SetLaserOn(not self:GetLaserOn())
    return true
end

function SWEP:ToggleLight()
    if not self:GetFeatureDef("Light") then return false end
    self:SetLightOn(not self:GetLightOn())
    return true
end

local POSE_FAMILIES = { eotech = true, kobra = true, aimpoint = true, elcan = true, eotech2x = true }
local EOTECH_POSE_LENS_Z = 1.443

local function LensAlignedPos(pos, sight, slot, family)
    local eotech = slot.SightPoses and slot.SightPoses.eotech
    local lensZ = sight.Lens and sight.Lens.Z
    if not (eotech and lensZ and family) then return pos end

    return Vector(pos.x, pos.y, eotech.z + EOTECH_POSE_LENS_Z - lensZ)
end

function SWEP:GetSights()
    local cache = self:AttCache()
    if cache.sights then return cache.sights end

    local list = {}
    for slotName, id, def, slot in self:IterAttachments() do
        if def.Sights then
            local overrides = slot.Overrides
            local pose = def.SightPose and slot.SightPoses and slot.SightPoses[def.SightPose]
            local poseFamily = pose and POSE_FAMILIES[def.SightPose]
            if not pose and def.SightOffset and slot.SightPoses and slot.SightPoses.eotech then
                pose = slot.SightPoses.eotech + def.SightOffset
                poseFamily = true
            end

            for _, sight in ipairs(def.Sights) do
                local entry = table.Copy(sight)
                local override = overrides and (overrides[id .. ":" .. (sight.Name or "")] or overrides[id])

                local ownPose = sight.SightPose and slot.SightPoses and slot.SightPoses[sight.SightPose]
                local ownFamily = ownPose and POSE_FAMILIES[sight.SightPose]
                if not ownPose and sight.SightOffset and slot.SightPoses and slot.SightPoses.eotech then
                    ownPose = slot.SightPoses.eotech + sight.SightOffset
                    ownFamily = true
                end

                if override and override.Pos then
                    entry.Pos = override.Pos
                elseif ownPose then
                    entry.Pos = LensAlignedPos(ownPose, sight, slot, ownFamily)
                elseif pose then
                    entry.Pos = LensAlignedPos(pose, sight, slot, poseFamily)
                else
                    entry.Pos = sight.Pos or Vector(0, 0, 0)
                end

                local shift = slot.SightShift and slot.SightShift[id]
                if shift and not (override and override.Pos) then entry.Pos = entry.Pos + shift end

                if override and override.Ang then
                    entry.Ang = override.Ang
                else
                    entry.Ang = (sight.Ang or Angle(0, 0, 0)) + (slot.SightAng or Angle(0, 0, 0))
                end

                entry.AttSlot = slotName
                entry.AttId = id
                list[#list + 1] = entry
            end
        end
    end

    if #list == 0 then list = self.Sights end

    cache.sights = list
    return list
end

local DEFAULT_SIGHT = { Name = "HIP", Pos = Vector(0, 0, 0), Ang = Angle(0, 0, 0), Zoom = 1 }

function SWEP:GetActiveSight()
    if self:GetGLMode() then
        local def = self:GetGLDef()
        local glSight = (def and def.GLSight) or self.GLSight
        if glSight then return glSight end
    end

    local sights = self:GetSights()
    local sight = sights[self:GetSightIndex()] or sights[1] or DEFAULT_SIGHT
    local deployed = self.DeployedSight

    if deployed and self:GetBipodDeployed() then
        local iron = self.Sights and self.Sights[1]
        if not iron or sight == iron then return deployed end

        self._depSights = self._depSights or setmetatable({}, { __mode = "k" })
        local shifted = self._depSights[sight]
        if not shifted then
            shifted = table.Copy(sight)
            shifted.Pos = (sight.Pos or Vector(0, 0, 0)) + (deployed.Pos - iron.Pos)
            shifted.Ang = (sight.Ang or Angle(0, 0, 0)) + (deployed.Ang - iron.Ang)
            self._depSights[sight] = shifted
        end

        return shifted
    end

    return sight
end

function SWEP:AttachmentsBlockAim()
    local cache = self:AttCache()
    if cache.noAim == nil then
        cache.noAim = false
        for _, _, def in self:IterAttachments() do
            if def.NoAim then cache.noAim = true break end
        end
    end
    return cache.noAim
end

function SWEP:CanAim()
    if self:IsSafe() or self:ActionBlocks("aim") or self:AttachmentsBlockAim() then return false end
    if self:GetSprintProgress() > 0 then return false end      -- sprinting or still coming out of it
    if self:IsBipodBusy() then return false end                -- bipod going down / coming up
    if self:IsReloading() and not self.AimDuringReload then return false end
    return true
end

function SWEP:GetAimProgress()
    local now, frame = CurTime(), FrameNumber()
    local memo = self._aimMemo
    if memo and memo.t == now and memo.frame == frame then return memo.v end

    local target = self:GetAiming() and 1 or 0
    local elapsed = SinceTime(self:GetAimChangeTime())
    local duration = math.max(self.AimTime * self:GetStatMult("AimTime"), 0.01)
    local progress = math.Approach(self:GetAimFrom(), target, elapsed / duration)

    if not memo then
        memo = {}
        self._aimMemo = memo
    end
    memo.t, memo.frame, memo.v = now, frame, progress

    return progress
end

function SWEP:SetAimState(aim)
    if aim == self:GetAiming() then return end

    self:SetAimFrom(self:GetAimProgress())
    self:SetAimChangeTime(CurTime())
    self:SetAiming(aim)
    self._aimMemo = nil

    local snd = aim and self.AimInSound or self.AimOutSound
    if snd then self:EmitSound(snd) end
end

local ADS_TOGGLE_POLL = 0.25
local cvAdsToggle

function SWEP:WantsAimToggle(owner)
    if CLIENT then
        cvAdsToggle = cvAdsToggle or GetConVar("cl_sandswep_ads_toggle")
        return cvAdsToggle ~= nil and cvAdsToggle:GetBool()
    end

    local ct, last = CurTime(), self._adsToggleAt
    if self._adsToggleOwner ~= owner or not last or math.abs(ct - last) >= ADS_TOGGLE_POLL then
        self._adsToggleOwner, self._adsToggleAt = owner, ct
        self._adsToggle = owner:GetInfoNum("cl_sandswep_ads_toggle", 0) ~= 0
    end

    return self._adsToggle
end

function SWEP:UpdateAimInput(owner)
    if CLIENT and game.SinglePlayer() then return end

    local rmb = owner:KeyDown(IN_ATTACK2)

    local want
    if self:WantsAimToggle(owner) then
        if owner:KeyPressed(IN_ATTACK2) then
            self:SetAimToggled(not self:GetAimToggled())
        end
        want = self:GetAimToggled()
    else
        want = rmb
    end

    if not self:CanAim() then want = false end
    self:SetAimState(want)

    if not want then
        if self:GetPointAim() then self:SetPointAim(false) end
    elseif self:GetPointAimPref() and not self:GetPointAim()
        and not self:GetGLMode() and not self:GetBipodDeployed() then
        self:SetPointAim(true)
    end

    if self:GetAiming() and owner:KeyPressed(IN_USE) then
        self:CycleSight()
    end
end

function SWEP:TogglePointAim()
    if not self:GetAiming() or self:GetGLMode() or self:GetBipodDeployed() then return end

    self:SetPointAim(not self:GetPointAim())
    self:SetPointAimPref(self:GetPointAim())

    local snd = self:GetPointAim() and self.AimInSound or self.AimOutSound
    if snd then self:EmitSound(snd) end
end

function SWEP:GetPointAimProgress()
    if CLIENT and self._pointProg then return math.Clamp(self._pointProg, 0, 1) end
    return (self:GetPointAim() and self:GetAiming()) and 1 or 0
end

function SWEP:UpdatePointAimProgress()
    local target = (self:GetPointAim() and self:GetAiming()) and 1 or 0
    local now = RealTime()
    local dt = math.min(now - (self._pointLast or now), 0.1)
    self._pointLast = now

    if not self._pointProg then
        self._pointRamp, self._pointProg, self._pointVel = target, target, 0
        return target
    end

    local time = self.PointAimTime or 0
    local ramp = time > 0 and math.Approach(self._pointRamp, target, dt / time) or target
    self._pointRamp = ramp
    local goal = ramp * ramp * (3 - 2 * ramp)

    local spring = self.PointAimSpring or 10
    local damping = self.PointAimDamping or 0.75
    local prog, vel = self._pointProg, self._pointVel
    local steps = math.max(1, math.ceil(dt / 0.004))
    local step = dt / steps

    for _ = 1, steps do
        vel = vel + (spring * spring * (goal - prog) - 2 * damping * spring * vel) * step
        prog = prog + vel * step
    end

    if ramp == target and math.abs(prog - target) < 0.0005 and math.abs(vel) < 0.005 then
        prog, vel = target, 0
    end

    self._pointProg, self._pointVel = prog, vel
    return prog
end

function SWEP:CycleSight()
    if self:GetGLMode() then return end

    local sights = self:GetSights()
    if #sights < 2 or self:GetSightSwitchTime() > 0 then return end
    if CurTime() - self:GetSightSwitchedAt() < 0.3 then return end

    local idx = self:GetSightIndex() % #sights + 1
    local toggle = sights[idx] and sights[idx].Toggle

    if toggle and toggle.Anim and self:HasAnim(toggle.Anim) then
        if self:IsActionBusy() then return end

        if self:PlayAnim(toggle.Anim) then
            self:SetSightSwitchedAt(CurTime())
            self:BeginAction("sight", self:GetAnimLength(toggle.Anim), toggle.Commit or 0)
            self:SetSightPending(idx)
            if toggle.Sounds then self:StartSoundSet("sight") end
            return
        end
    end

    self:SetSightSwitchedAt(CurTime())
    self:SetZoomBumpAt(CurTime())
    self:ApplySightSwitch(idx)
end

function SWEP:GetSightSwitchTime()
    if self:GetAction() ~= self.Actions.sight.Id then return 0 end
    return self:GetActionEvent()
end

function SWEP:ApplySightSwitch(idx)
    local sights = self:GetSights()
    if not sights[idx] then return end

    self:SetSightIndex(idx)

    local toggle = sights[idx].Toggle
    if toggle and toggle.Sounds and self:GetAction() == self.Actions.sight.Id then return end

    local snd = (toggle and toggle.Sounds and toggle.Sounds[1] and toggle.Sounds[1].s) or sights[idx].SwitchSound
    if snd then
        self:EmitSound(snd)
    else
        self:EmitSound(self.SightSwitchSound, 55, 110, 0.5)
    end
end

function SWEP:GetSightFlipAnim(slotName)
    if self:GetSightSwitchTime() <= 0 then return end

    local pending = self:GetSights()[self:GetSightPending()]
    local toggle = pending and pending.AttSlot == slotName and pending.Toggle
    if not toggle or not toggle.Flip or not toggle.Anim then return end

    local len = self:GetAnimLength(toggle.Anim)
    if len <= 0 then return end

    return toggle.Flip == 1 and "open" or "close", math.Clamp((CurTime() - self:GetActionStart()) / len, 0, 1)
end

function SWEP:GetSightFlip(slotName, flipTime)
    local sights = self:GetSights()
    local current = sights[self:GetSightIndex()] or sights[1]
    local value = (current and current.AttSlot == slotName and current.Toggle and current.Toggle.Flip) or 0

    local switchTime = self:GetSightSwitchTime()
    if switchTime > 0 then
        local pending = sights[self:GetSightPending()]
        local toggle = pending and pending.AttSlot == slotName and pending.Toggle
        if toggle and toggle.Flip then
            local flipStart = switchTime - (toggle.Commit or 0) + (toggle.FlipStart or 0)
            local duration = math.max(toggle.FlipTime or flipTime or 0.25, 0.01)
            local frac = math.Clamp((CurTime() - flipStart) / duration, 0, 1)
            value = Lerp(frac * frac * (3 - 2 * frac), value, toggle.Flip)
        end
    end

    return value
end

function SWEP:GetCurrentSpread()
    local aimMult = self.AimSpreadMult
    local point = self:GetPointAimProgress()

    if point > 0 then
        aimMult = Lerp(point, aimMult, self.PointAimSpreadMult or Lerp(0.75, 1, aimMult))
    end

    return self.Primary.Spread * Lerp(self:GetAimProgress(), 1, aimMult) * self:GetStatMult("Spread")
end

local cvFOVKick = CLIENT and CreateClientConVar("cl_sandswep_fovkick", "1", true, false, "Camera FOV kick when firing while aiming", 0, 3)

function SWEP:GetFOVKick()
    local kickStart = self._fovKickT
    if not kickStart or not cvFOVKick then return 0 end

    local elapsed = RealTime() - kickStart
    if elapsed > 0.5 then return 0 end

    local amount = (self.FOVKick or 0.012) * math.Clamp(self.Primary.Recoil or 1, 0.3, 4) * cvFOVKick:GetFloat()
    amount = amount * self:GetAimProgress()
    if self.GetBipodDeployed and self:GetBipodDeployed() then amount = amount * 0.4 end

    return amount * math.min(elapsed / 0.012, 1) * math.exp(-elapsed * 11)
end

function SWEP:TranslateFOV(fov)
    local blend = self:GetAimProgress()
    if blend <= 0 then return fov end

    local kick = self:GetFOVKick()
    if kick > 0 then
        fov = math.deg(2 * math.atan(math.tan(math.rad(fov) * 0.5) * (1 + kick)))
    end

    local zoom = (self:GetActiveSight().Zoom or 1) * Lerp(self:GetFocusProgress(), 1, self.FocusZoom)
    local point = self:GetPointAimProgress()
    if point > 0 then
        zoom = Lerp(point * point * (3 - 2 * point), zoom, self.PointAimZoom or 1)
    end

    blend = blend * blend * (3 - 2 * blend)
    return fov / Lerp(blend, 1, zoom)
end

local cvAdsSens, cvScopeSens, cvScopeMatch
if CLIENT then
    cvAdsSens    = CreateClientConVar("cl_sandswep_ads_sens", "1", true, false, "Aim sensitivity", 0.1, 2)
    cvScopeSens  = CreateClientConVar("cl_sandswep_scope_sens", "1", true, false, "Scope sensitivity", 0.1, 2)
    cvScopeMatch = CreateClientConVar("cl_sandswep_scope_sens_match", "0.5", true, false, "Scope zoom compensation (0-1)", 0, 1)
end

function SWEP:AdjustMouseSensitivity()
    local blend = self:GetAimProgress()
    if blend <= 0 then return end

    local sight = self:GetActiveSight()
    local zoom = (sight.Zoom or 1) * Lerp(self:GetFocusProgress(), 1, self.FocusZoom)
    local mult = (1 / zoom) * (sight.Sensitivity or 1)

    if cvAdsSens then
        mult = mult * cvAdsSens:GetFloat()
        local mag = self:GetSightMagnification(sight)
        if mag > 1 then
            mult = mult * mag ^ -cvScopeMatch:GetFloat() * cvScopeSens:GetFloat()
        end
    end

    local point = self:GetPointAimProgress()
    if point > 0 then
        mult = Lerp(point, mult, (cvAdsSens and cvAdsSens:GetFloat() or 1) / (self.PointAimZoom or 1))
    end

    return Lerp(blend, 1, mult)
end

function SWEP:GetSightMagnification(sight)
    local pip = sight and sight.PIP
    if not pip then return 1 end
    if not (CLIENT and pip.Min and pip.Max) then return pip.Magnification or 1 end

    self._varZoom = self._varZoom or {}
    local zoom = self._varZoom[sight.Name]
    if not zoom then
        local start = pip.Start or pip.Min
        zoom = { target = start, cur = start }
        self._varZoom[sight.Name] = zoom
    end

    local frame = FrameNumber()
    if zoom.frame ~= frame then
        zoom.frame = frame

        if pip.Snap then
            local midShutter = zoom.shutterAt and RealTime() - zoom.shutterAt < pip.Shutter * 0.5
            if not midShutter then zoom.cur = zoom.target end
            return zoom.cur
        end

        local blend = 1 - math.exp(-VisualFrameTime() * (self.VariableZoomSpeed or 12))
        zoom.cur = math.exp(Lerp(blend, math.log(zoom.cur), math.log(zoom.target)))
        if math.abs(math.log(zoom.cur / zoom.target)) < 0.01 then zoom.cur = zoom.target end
    end

    return zoom.cur
end

function SWEP:StepSightZoom(sight, dir)
    local pip = sight.PIP
    self:GetSightMagnification(sight)
    local zoom = self._varZoom[sight.Name]

    local step = pip.Step or 1.25
    local target = math.Clamp(zoom.target * step ^ dir, pip.Min, pip.Max)
    if math.abs(target - pip.Min) < 0.05 then
        target = pip.Min
    elseif math.abs(target - pip.Max) < 0.05 then
        target = pip.Max
    end

    if target ~= zoom.target then
        local now = RealTime()
        if pip.Shutter then zoom.shutterAt, zoom.shutterDir = now, dir end

        if now - (self._zoomSoundAt or 0) > 0.06 then
            self._zoomSoundAt = now
            local snd = pip.Sound or (dir > 0 and self.VariableZoomSoundIn or self.VariableZoomSoundOut)
            if snd then self:EmitSound(snd, 50, 100, 0.5) end
        end
    end

    zoom.target = target
end

function SWEP:GetSightShutter(sight)
    local pip = sight and sight.PIP
    local zoom = pip and pip.Shutter and self._varZoom and self._varZoom[sight.Name]
    if not (zoom and zoom.shutterAt) then return end

    local progress = (RealTime() - zoom.shutterAt) / pip.Shutter
    if progress >= 1 then
        zoom.shutterAt = nil
        return
    end

    return progress, zoom.shutterDir or 1
end

if CLIENT then
    hook.Add("PlayerBindPress", "SandSwep_VariableZoom", function(ply, bind, pressed)
        if not pressed then return end

        local dir = (bind:find("invprev", 1, true) and 1) or (bind:find("invnext", 1, true) and -1)
        if not dir then return end

        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or not wep.IsSandSwep or not wep:GetAiming() then return end

        local sight = wep:GetActiveSight()
        if not (sight and sight.PIP and sight.PIP.Min and sight.PIP.Max) then return end

        wep:StepSightZoom(sight, dir)
        return true
    end)
end
