-- Sound system

local SOUNDSETS = { "reload", "reload_empty", "reload_quick", "reload_quick_empty", "magcheck", "deploy", "ready",
    "gl_reload", "gl_in", "gl_out", "sight", "reload_bolt", "holster", "cycle", "insert_start", "insert_start_empty",
    "insert", "insert_end", "insert_clip", "tubeswap", "insert_tubeswap" }

local SOUNDSET_ANIM = {
    reload = "reload", reload_empty = "reload_empty",
    reload_quick = "reload_speed", reload_quick_empty = "reload_speed_empty",
    magcheck = "checkammo", deploy = "draw", ready = "ready",
    gl_reload = "reload", gl_in = "gl_in", gl_out = "gl_out", reload_bolt = "reload_boltrelease",
    holster = "holster", cycle = "cycle", insert_start = "insert_start", insert_start_empty = "insert_start_empty",
    insert = "insert", insert_end = "insert_end", insert_clip = "insert_clip",
    tubeswap = "tubeswap", insert_tubeswap = "insert_tubeswap",
}

local SOUNDSET_FALLBACK = {
    reload_empty = "reload",
    reload_quick_empty = "reload_quick",
}

local setIdCache = setmetatable({}, { __mode = "k" })

local NO_EVENTS = {}

function SWEP:GetSoundSetIds()
    local events = self.SoundEvents or NO_EVENTS
    local cache = setIdCache[events]
    if cache then return cache end

    local names, ids = {}, {}
    for i, name in ipairs(SOUNDSETS) do names[i], ids[name] = name, i end

    local extra = {}
    for k in pairs(events) do
        if isstring(k) and not ids[k] then extra[#extra + 1] = k end
    end
    table.sort(extra)
    for _, k in ipairs(extra) do
        names[#names + 1] = k
        ids[k] = #names
    end

    cache = { names = names, ids = ids }
    setIdCache[events] = cache

    return cache
end

function SWEP:GetSoundEvents(name)
    if name == "sight" then
        local sight = self:GetSights()[self:GetSightPending()]
        return sight and sight.Toggle and sight.Toggle.Sounds
    end

    for _, _, def in self:IterAttachments() do
        local alt = def.SoundSuffix and self.SoundEvents and self.SoundEvents[name .. "_" .. def.SoundSuffix]
        if alt and #alt > 0 then return alt end
    end

    local events = self.SoundEvents and self.SoundEvents[name]
    if not events or #events == 0 then
        local model = self:GetModelSoundEvents(SOUNDSET_ANIM[name] or name)
        if model then return model end
    end

    if (not events or #events == 0) and SOUNDSET_FALLBACK[name] then
        return self:GetSoundEvents(SOUNDSET_FALLBACK[name])
    end

    return events
end

function SWEP:GetModelSoundEvents(anim)
    local entry = self:GetAnimEntry(anim)
    if not entry then return end

    local seq = isstring(entry.Seq) and entry.Seq or (istable(entry.Seq) and entry.Seq[1])
    local data = SandSwep.GetSequenceData(self.ViewModel, seq)
    if not data or not data.sounds then return end

    if not data.events then
        local list = {}
        for i, event in ipairs(data.sounds) do list[i] = { t = event.cycle * data.len, s = event.s } end
        data.events = list
    end

    return data.events
end

function SWEP:GetFireSound(role)
    if role == "Close" then return self.FireSounds.Close or self.Primary.Sound end
    return self.FireSounds[role]
end

function SWEP:GetSoundSetBaseTime(name)
    local anim = SOUNDSET_ANIM[name]
    if anim and self:HasAnim(anim) then return self:GetAnimLength(anim) end

    if name == "magcheck" then return self.MagCheckTime end
    if name == "deploy" then return self.DeployTime end
    if SOUNDSET_ANIM[name] then return 1 end
end

function SWEP:StartSoundSet(name, duration)
    local id = self:GetSoundSetIds().ids[name]
    local events = id and self:GetSoundEvents(name)
    if not events or #events == 0 then
        self:SetSoundSet(0)
        return
    end

    local base = self:GetSoundSetBaseTime(name)
    self:SetSoundSet(id)
    self:SetSoundSetStart(CurTime())
    self:SetSoundSetLast(-1)
    self:SetSoundSetScale((duration and base and base > 0) and duration / base or 1)
end

function SWEP:SwitchSoundSet(name, duration)
    local id = self:GetSoundSetIds().ids[name]
    local events = id and self:GetSoundEvents(name)
    if not events or #events == 0 then
        self:SetSoundSet(0)
        return
    end

    local base = self:GetSoundSetBaseTime(name)
    self:SetSoundSet(id)
    self:SetSoundSetScale((duration and base and base > 0) and duration / base or 1)
end

function SWEP:StopSoundSet()
    self:SetSoundSet(0)
end

local precachedSounds = {}

local function PrecacheSoundName(snd)
    if istable(snd) then
        for _, entry in ipairs(snd) do PrecacheSoundName(entry) end
        return
    end

    if not isstring(snd) or snd == "" or precachedSounds[snd] then return end
    precachedSounds[snd] = true

    local script = sound.GetProperties(snd)
    if script then
        PrecacheSoundName(script.sound)
    else
        util.PrecacheSound(snd)
    end
end

local function PrecacheEvents(events)
    if not istable(events) then return end

    for _, event in ipairs(events) do
        PrecacheSoundName(event.s)
    end
end

local SOUND_FIELDS = {
    "HolsterSound", "AimInSound", "AimOutSound", "FireModeSound", "SightSwitchSound",
    "VariableZoomSoundIn", "VariableZoomSoundOut", "ShellSounds",
    "MeleeSwingSound", "MeleeHitWorldSound", "MeleeHitFleshSound",
}

local HOLSTER_FALLBACKS = { "SandSwep.SS.Holster_Sidearm_1p", "SandSwep.SS.Holster_Rifle_1p" }

function SWEP:PrecacheSounds()
    if self._soundsPrecached then return end
    self._soundsPrecached = true

    for _, events in pairs(self.SoundEvents or NO_EVENTS) do
        PrecacheEvents(events)
    end

    for _, name in ipairs(SOUNDSETS) do
        if name ~= "sight" then PrecacheEvents(self:GetSoundEvents(name)) end
    end

    for _, sight in ipairs(self:GetSights() or NO_EVENTS) do
        if sight.Toggle then PrecacheEvents(sight.Toggle.Sounds) end
    end

    for _, snd in pairs(self.FireSounds or NO_EVENTS) do
        PrecacheSoundName(snd)
    end

    for _, info in pairs(SandSwep.GetModelSequences(self.ViewModel)) do
        PrecacheEvents(info.sounds)
    end

    for _, field in ipairs(SOUND_FIELDS) do
        PrecacheSoundName(self[field])
    end

    PrecacheSoundName(HOLSTER_FALLBACKS)
    PrecacheSoundName(self.Primary.Sound)
    PrecacheSoundName(self.Primary.DryFireSound)
end

function SWEP:PlayEventSound(event)
    if not event.s then return end
    if CLIENT and not IsFirstTimePredicted() then return end

    if event.v or event.p or event.l then
        self:EmitSound(event.s, event.l or 75, event.p or 100, event.v or 1, CHAN_AUTO)
    else
        self:EmitSound(event.s)
    end
end

function SWEP:ProcessSoundSet()
    local id = self:GetSoundSet()
    if id == 0 then return end

    local name = self:GetSoundSetIds().names[id]
    local events = name and self:GetSoundEvents(name)
    if not events then
        self:SetSoundSet(0)
        return
    end

    local scale = self:GetSoundSetScale()
    local elapsed = CurTime() - self:GetSoundSetStart()
    local last = self:GetSoundSetLast()
    local newLast = last
    local lastEvent = 0

    for _, event in ipairs(events) do
        local eventTime = (event.t or 0) * scale
        if eventTime > last + 1e-4 and eventTime <= elapsed then
            self:PlayEventSound(event)
            if eventTime > newLast then newLast = eventTime end
        end
        if eventTime > lastEvent then lastEvent = eventTime end
    end

    if newLast ~= last then self:SetSoundSetLast(newLast) end
    if elapsed >= lastEvent then self:SetSoundSet(0) end
end

function SWEP:IsIndoors()
    local ct = CurTime()
    if self._indoorCheck and self._indoorCheck > ct then return self._indoor end
    self._indoorCheck = ct + 0.5

    local owner = self:GetOwner()
    local pos = IsValid(owner) and owner:GetShootPos() or self:GetPos()
    local tr = SandSwep.TraceLine(pos, pos + Vector(0, 0, 2048), nil, MASK_SOLID_BRUSHONLY)
    self._indoor = tr.Hit and not tr.HitSky

    return self._indoor
end

function SWEP:IsSuppressed()
    local cache = self:AttCache()
    if cache.sup == nil then
        cache.sup = self.IntegralSuppressor or false
        for _, _, def in self:IterAttachments() do
            if def.Suppressor then cache.sup = true break end
        end
    end

    return cache.sup
end

function SWEP:HasFlashHider()
    local cache = self:AttCache()
    if cache.fh == nil then
        cache.fh = false
        for _, _, def in self:IterAttachments() do
            if def.FlashHider then cache.fh = true break end
        end
    end

    return cache.fh
end

local SUPPRESSED_LEVEL_DROP = 20

local function SuppressedLevel(level)
    return (level or 75) - SUPPRESSED_LEVEL_DROP
end

local function IsRawSound(snd)
    return isstring(snd) and (snd:find("%.wav$") or snd:find("%.mp3$") or snd:find("%.ogg$")) ~= nil
end

function SWEP:PlaySuppressedFireSounds()
    local sounds = self.FireSounds or {}
    local single = sounds.CloseSingleSuppressed and self:GetFireMode() == "semi"

    local close, key
    if single then
        close, key = sounds.CloseSingleSuppressed, "CloseSingleSuppressed"
    elseif sounds.CloseSuppressedIndoor and self:IsIndoors() then
        close, key = sounds.CloseSuppressedIndoor, "CloseSuppressedIndoor"
    else
        close, key = self:GetFireSound("CloseSuppressed"), "CloseSuppressed"
    end

    if close then
        self:EmitShotLayer(close, sounds.CloseSuppressedLevel or SuppressedLevel(sounds.CloseLevel), sounds.ClosePitch, sounds.CloseSuppressedVolume,
            self:NextShotChannel(), key)
    else
        close = self:PickSound(self:GetFireSound("Close"), "Close")
        if close then self:EmitSound(close, 72, math.random(122, 128), 0.32, IsRawSound(close) and self:NextShotChannel() or CHAN_WEAPON) end
    end
    self:QueueShotTail()

    local mech = self:GetFireSound("Mech")
    if mech then self:EmitSound(self:PickSound(mech, "Mech")) end

    local tail = self:GetFireSound("TailSuppressed")
    if tail then self:EmitSound(tail) end
end

function SWEP:PickSound(snd, key)
    if not istable(snd) then return snd end

    local count = #snd
    if count <= 1 then return snd[1] end

    self._sndLast = self._sndLast or {}
    local last = self._sndLast[key or snd]
    local i = math.random(1, last and count - 1 or count)
    if last and i >= last then i = i + 1 end
    self._sndLast[key or snd] = i

    return snd[i]
end

function SWEP:EmitShotLayer(snd, level, pitch, volume, chan, key)
    snd = self:PickSound(snd, key)
    if not snd then return end

    if IsRawSound(snd) then
        if string.find(snd, "^[%w_]") then snd = ")" .. snd end
        if istable(pitch) then pitch = math.random(pitch[1], pitch[2]) end
        if key and key:sub(1, 5) == "Close" then self._lastShotKey, self._lastShotPitch = key, pitch end
        self:EmitSound(snd, level or 75, pitch or 100, volume or 1, chan or CHAN_STATIC)
    else
        self:EmitSound(snd)
    end
end

local CHAN_SHOTTAIL = 150
local CHAN_SHOT_BASE, CHAN_SHOT_COUNT = 136, 8
function SWEP:NextShotChannel()
    self._shotChan = (self._shotChan or 0) % CHAN_SHOT_COUNT + 1
    return CHAN_SHOT_BASE + self._shotChan - 1
end
function SWEP:QueueShotTail()
    local fs = self.FireSounds
    if not fs or not (fs.ShotTail or fs.ShotTailIndoor or fs.ShotTailSuppressed) then return end
    if CLIENT and not IsFirstTimePredicted() then return end

    self._shotTails = self._shotTails or {}
    local ct = CurTime()
    for i = #self._shotTails, 1, -1 do
        if self._shotTails[i] > ct then table.remove(self._shotTails, i) end
    end

    local delay = fs.ShotTailDelay or 0.15
    if self:GetBurstLeft() > 0 then delay = math.max(delay, 60 / self:GetRPM() * 1.5) end
    table.insert(self._shotTails, ct + delay)
end

function SWEP:UpdateShotTail()
    local queue = self._shotTails
    if not queue or not queue[1] or CurTime() < queue[1] then return end
    while queue[1] and CurTime() >= queue[1] do table.remove(queue, 1) end    -- only the newest due one matters

    local fs = self.FireSounds
    local level = fs.ShotTailLevel or fs.CloseLevel
    local snd, vol
    if self:IsSuppressed() then
        snd, vol = fs.ShotTailSuppressed, fs.ShotTailSuppressedVolume
        level = SuppressedLevel(level)
    elseif fs.ShotTailIndoor and self:IsIndoors() then
        snd, vol = fs.ShotTailIndoor, fs.ShotTailIndoorVolume
    else
        snd = fs.ShotTail
    end

    self:EmitShotLayer(snd, level, fs.ShotTailPitch, vol or fs.ShotTailVolume, CHAN_SHOTTAIL, "ShotTail")
end

function SWEP:ArmBurstTail(interval)
    local fs = self.FireSounds
    if not fs or not (fs.BurstTail or fs.BurstTailIndoor or fs.BurstTailSuppressed) then return end

    local singleShot = self:GetFireMode() == "semi"
        and (self:IsSuppressed() and fs.CloseSingleSuppressed or not self:IsSuppressed() and fs.CloseSingle)
    if singleShot then
        self._burstTailAt = nil
        return
    end

    self._burstTailAt = CurTime() + (fs.BurstTailOffset or math.max(fs.BurstTailDelay or 0.15, (interval or 0) * 1.2))
end

function SWEP:UpdateBurstTail()
    local tailAt = self._burstTailAt
    if not tailAt or CurTime() < tailAt then return end

    self._burstTailAt = nil
    if CLIENT and not IsFirstTimePredicted() then return end

    local fs = self.FireSounds
    local level = fs.BurstTailLevel or fs.CloseLevel
    local snd, vol
    if self:IsSuppressed() then
        snd, vol = fs.BurstTailSuppressed, fs.BurstTailSuppressedVolume
        level = SuppressedLevel(level)
    elseif fs.BurstTailIndoor and self:IsIndoors() then
        snd, vol = fs.BurstTailIndoor, fs.BurstTailIndoorVolume
    else
        snd = fs.BurstTail
    end

    local pitch = fs.ClosePitch
    if istable(snd) and self._lastShotKey and #snd == #(fs[self._lastShotKey] or {}) then
        local i = self._sndLast and self._sndLast[self._lastShotKey]
        if i and snd[i] then snd, pitch = snd[i], self._lastShotPitch or pitch end
    end

    self:EmitShotLayer(snd, level, pitch, vol or fs.BurstTailVolume, nil, "BurstTail")
end

function SWEP:PlayFireSounds(clipAfter)
    if hook.Run("SandSwep_FireSounds", self, clipAfter) == true then return end
    if self:IsSuppressed() then return self:PlaySuppressedFireSounds() end

    local sounds = self.FireSounds or {}
    local semi = sounds.CloseSingle and self:GetFireMode() == "semi"
    local inside = self:IsIndoors()

    local close, key
    if semi then
        if inside and sounds.CloseSingleIndoor then
            close, key = sounds.CloseSingleIndoor, "CloseSingleIndoor"
        else
            close, key = sounds.CloseSingle, "CloseSingle"
        end
    elseif inside and sounds.CloseIndoor then
        close, key = sounds.CloseIndoor, "CloseIndoor"
    else
        close, key = self:GetFireSound("Close"), "Close"
    end

    if close then self:EmitShotLayer(close, sounds.CloseLevel, sounds.ClosePitch, sounds.CloseVolume, self:NextShotChannel(), key) end
    self:QueueShotTail()

    local mech = self:GetFireSound("Mech")
    if mech then self:EmitSound(self:PickSound(mech, "Mech")) end

    local tail = self:IsIndoors() and self:GetFireSound("TailIndoor") or self:GetFireSound("TailOutdoor")
    if tail then self:EmitSound(tail) end

    local fs = self.FireSounds
    local low = self:GetFireSound("LowAmmo")
    if low and clipAfter < (fs.LowAmmoCount or 0) then
        local pitch = 100 + ((fs.LowAmmoCount or 0) - clipAfter) * (fs.LowAmmoPitchStep or 0)
        self:EmitSound(low, 60, math.min(pitch, 255), 1, CHAN_AUTO)
    end

    local distant = self:GetFireSound("Distant")
    if not SERVER or not distant then return end

    local owner = self:GetOwner()
    local pos = self:GetPos()
    local range = (fs.DistantRange or 1500) ^ 2

    local filter = RecipientFilter()
    for _, ply in ipairs(player.GetHumans()) do
        if ply ~= owner and ply:GetPos():DistToSqr(pos) > range then filter:AddPlayer(ply) end
    end

    if filter:GetCount() > 0 then
        self:EmitSound(self:PickSound(distant, "Distant"), fs.DistantLevel or 140, 100, 1, CHAN_STATIC, 0, 0, filter)
    end
end
