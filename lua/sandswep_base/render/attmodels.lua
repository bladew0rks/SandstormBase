local VisualFrameTime = SandSwep.VisualFrameTime

if not CLIENT then return end

local cvAttWorldLight = CreateClientConVar("cl_sandswep_att_worldlight", "1", true, false, "Lit viewmodel attachments", 0, 1)
local cvGripTime = CreateClientConVar("cl_sandswep_grip_blend_time", "0.2", true, false, "Seconds the foregrip hand takes to blend on or off the grip", 0.01, 1)

local MOUNT_AXES = { Rail = { Front = Vector(1, 0, 0), Out = Vector(0, 1, 0) } }

function SWEP:ResetVMBodygroups()
    local owner = self:GetOwner()
    if not IsValid(owner) or owner ~= LocalPlayer() then return end

    local vm = owner:GetViewModel()
    if not IsValid(vm) then return end

    if SandSwep.ClearHandScale then SandSwep.ClearHandScale(vm) end
    if SandSwep.ClearGLRound then SandSwep.ClearGLRound(vm) end
    if SandSwep.ClearParked then SandSwep.ClearParked(vm) end
    if not vm.SandSwepBodygroups then return end

    for i = 0, vm:GetNumBodyGroups() - 1 do vm:SetBodygroup(i, 0) end
    vm:SetSkin(0)
    vm.SandSwepBodygroups = nil
end

local function Basis(front, out)
    front = front:GetNormalized()
    out = (out - front * out:Dot(front)):GetNormalized()
    return front, out, front:Cross(out)
end

function SWEP:GetRailOffset(slot, def)
    local rail, mount = slot.Rail, def.Rail
    local gunFront, gunOut, gunSide = Basis(rail.Forward or Vector(0, -1, 0), rail.Out)
    local modelFront, modelOut, modelSide = Basis(mount.Front, mount.Out)

    local function ToGun(v)
        return gunFront * v:Dot(modelFront) + gunOut * v:Dot(modelOut) + gunSide * v:Dot(modelSide)
    end

    local fwd, up = ToGun(Vector(1, 0, 0)), ToGun(Vector(0, 0, 1))
    local pos = rail.Pos + gunFront * (rail.Slide or 0) - ToGun(mount.Mount or vector_origin)

    return {
        Bone = rail.Bone or "b_wpn",
        Pos = pos,
        Ang = fwd:AngleEx(up),
    }
end

function SWEP:GetMountOffset(slot)
    return self:GetRailOffset({ Rail = slot.Mount.Rail }, MOUNT_AXES)
end

function SWEP:GetAttachmentOffset(slotName, id, def)
    local edit = self._attEdit and self._attEdit[slotName]
    if edit then return edit end

    local slot = self:GetAttachmentSlots()[slotName]
    local override = slot and slot.Offsets and slot.Offsets[id]
    if override then return override end

    if slot and slot.Rail and def.Rail then return self:GetRailOffset(slot, def) end

    if def.Bonemerge == false then
        return {
            Bone = def.Bone,
            Attachment = def.Attachment,
            Pos = def.Pos,
            Ang = def.Ang,
        }
    end
end

function SWEP:RemoveVMAttachmentModels()
    for _, ent in pairs(self._vmAttEnts or {}) do
        if IsValid(ent) then ent:Remove() end
    end
    self._vmAttEnts, self._vmAttKey = nil, nil
end

local function ModelsCurrent(wep, key, vm, lit)
    return key and key.att == wep:GetAttData() and key.skins == wep:GetAttSkins() and key.vm == vm
        and key.model == vm:GetModel() and key.edit == wep._attEditVer and key.lit == lit
end

local function AllValid(ents)
    for _, ent in pairs(ents) do
        if not IsValid(ent) then return false end
    end
    return true
end

local function SetupLighting(ent, lit)
    if lit then
        ent:SetRenderMode(RENDERMODE_ENVIROMENTAL)
        ent:DrawShadow(false)
    else
        ent:SetNoDraw(true)
    end
end

function SWEP:UpdateVMAttachmentModels(vm)
    local lit = cvAttWorldLight:GetBool()
    if self._vmAttEnts and ModelsCurrent(self, self._vmAttKey, vm, lit) and AllValid(self._vmAttEnts) then return end

    self:RemoveVMAttachmentModels()
    self._vmAttEnts = {}
    local slots = self:GetAttachmentSlots()

    for slotName, id in self:IterAttachments() do
        local mount = slots[slotName] and slots[slotName].Mount
        if mount and mount.Except and mount.Except[id] then mount = nil end

        local ent = mount and ClientsideModel(mount.Model, RENDERGROUP_VIEWMODEL)
        if IsValid(ent) then
            SetupLighting(ent, lit)
            ent.SandSwepSlot = slotName

            if mount.Rail then
                ent.SandSwepOffset = self:GetMountOffset(slots[slotName])
            else
                ent:SetPos(vm:GetPos())
                ent:SetAngles(vm:GetAngles())
                ent:SetParent(vm)
                ent:AddEffects(EF_BONEMERGE)
            end

            self._vmAttEnts[slotName .. "#mount"] = ent
        end
    end

    for slotName, id, def in self:IterAttachments() do
        local ent = def.Model and ClientsideModel(def.Model, RENDERGROUP_VIEWMODEL)
        if IsValid(ent) then
            SetupLighting(ent, lit)
            ent.SandSwepDef = def
            ent.SandSwepSlot = slotName
            ent.SandSwepOffset = self:GetAttachmentOffset(slotName, id, def)
            ent:SetSkin(self:GetAttachmentSkin(slotName, def))
            SandSwep.ApplyAttScale(ent, def)

            if not ent.SandSwepOffset then
                ent:SetPos(vm:GetPos())
                ent:SetAngles(vm:GetAngles())
                ent:SetParent(vm)
                ent:AddEffects(EF_BONEMERGE)
            end

            self._vmAttEnts[slotName] = ent
        end
    end

    self._vmAttKey = {
        att = self:GetAttData(),
        skins = self:GetAttSkins(),
        vm = vm,
        model = vm:GetModel(),
        edit = self._attEditVer,
        lit = lit,
    }
end

local function PlaceOffset(ent, vm, offset)
    local origin, frame = SandSwep.OffsetFrame(vm, offset)
    if not origin then return false end

    local pos, ang = LocalToWorld(offset.Pos or vector_origin, offset.Ang or angle_zero, origin, frame)
    ent:SetPos(pos)
    ent:SetAngles(ang)
    ent:SetupBones()

    return true
end

local function PoseFlip(wep, ent, def)
    if not def or not def.FlipSequence then return end

    local kind, cycle
    if def.FlipOpenSequence and wep.GetSightFlipAnim then
        kind, cycle = wep:GetSightFlipAnim(ent.SandSwepSlot)
    end

    local name = kind and (kind == "open" and def.FlipOpenSequence or def.FlipCloseSequence) or def.FlipSequence
    ent._flipSeqs = ent._flipSeqs or {}

    local seq = ent._flipSeqs[name]
    if seq == nil then
        seq = ent:LookupSequence(name)
        ent._flipSeqs[name] = seq
    end
    if not seq or seq < 0 then return end

    if ent:GetSequence() ~= seq then ent:ResetSequence(seq) end
    ent:SetPlaybackRate(0)
    ent:SetCycle(cycle or wep:GetSightFlip(ent.SandSwepSlot, def.FlipTime))
end

function SWEP:DrawVMAttachments(vm, active, aimT)
    for _, ent in pairs(self._vmAttEnts or {}) do
        if IsValid(ent) then
            if active and active.Squash and active.AttSlot == ent.SandSwepSlot then
                self:SquashOptic(ent, active, Lerp(aimT, 1, active.Squash))
            elseif ent.SandSwepSquash then
                ent.SandSwepSquash.s = 1
            end

            PoseFlip(self, ent, ent.SandSwepDef)

            if ent.SandSwepOffset then
                if PlaceOffset(ent, vm, ent.SandSwepOffset) then ent:DrawModel() end
            else
                ent:DrawModel()
            end
        end
    end
end

function SWEP:ApplyVMPoseParams(vm)
    local want = self:GetDesiredPoseParams()
    if not next(want) then return end

    local fresh = vm.SandSwepPoses == nil or vm.SandSwepPoseSet ~= want
    vm.SandSwepPoses = vm.SandSwepPoses or {}

    for name, target in pairs(want) do
        vm:SetPoseParameter(name, target)
        vm.SandSwepPoses[name] = true
    end

    if fresh then
        vm.SandSwepPoseSet = want
        vm:InvalidateBoneCache()
    end
end

local function GripTarget(vm, rate)
    local data = SandSwep.GetSequenceData(vm:GetModel(), vm:GetSequenceName(vm:GetSequence()))
    local marks = data and data.marks
    if not marks or data.len <= 0 then return 1 end

    local cycle = vm:GetCycle()
    local target = 1
    if marks.gripoff and cycle >= marks.gripoff then target = 0 end
    if marks.gripon and cycle >= marks.gripon - vm:GetPlaybackRate() / (rate * data.len) then target = 1 end

    return target
end

local function GripCurve(vm, time)
    local data = SandSwep.GetSequenceData(vm:GetModel(), vm:GetSequenceName(vm:GetSequence()))
    local marks = data and data.marks
    if not marks or data.len <= 0 then return 1 end

    local elapsed = vm:GetCycle() * data.len
    local weight = 1
    if marks.gripoff then weight = math.Clamp(1 - (elapsed - marks.gripoff * data.len) / time, 0, 1) end
    if marks.gripon then weight = math.max(weight, math.Clamp((elapsed - marks.gripon * data.len) / time + 1, 0, 1)) end

    return weight
end

function SWEP:ApplyGripWeight(vm)
    if vm:LookupPoseParameter("gripweight") < 0 then return end

    local rate = 1 / cvGripTime:GetFloat()
    local target = GripTarget(vm, rate)
    local model, frame = vm:GetModel(), FrameNumber()

    local grip = vm.SandSwepGrip
    if not grip or grip.model ~= model then
        grip = { model = model, w = target }
        vm.SandSwepGrip = grip
    elseif self._seqStep then
        grip.w = GripCurve(vm, 1 / rate)
    elseif grip.frame ~= frame then
        grip.w = math.Approach(grip.w, target, rate * VisualFrameTime())
    end
    grip.frame = frame

    if math.abs(vm:GetPoseParameter("gripweight") - grip.w) > 0.001 then
        vm:SetPoseParameter("gripweight", grip.w)
        vm:InvalidateBoneCache()
    end

    vm.SandSwepPoses = vm.SandSwepPoses or {}
    vm.SandSwepPoses.gripweight = true
end

concommand.Add("sandswep_posedebug", function()
    local ply = LocalPlayer()
    local wep = IsValid(ply) and ply:GetActiveWeapon()
    local vm = IsValid(ply) and ply:GetViewModel()
    if not IsValid(wep) or not wep.GetDesiredPoseParams or not IsValid(vm) then
        print("[sandswep] Hold a sandswep weapon first.")
        return
    end

    print("[sandswep] viewmodel " .. vm:GetModel() .. ", " .. vm:GetNumPoseParameters() .. " pose parameter(s), sequence " .. vm:GetSequenceName(vm:GetSequence()))

    for name, want in pairs(wep:GetDesiredPoseParams()) do
        local id = vm:LookupPoseParameter(name)
        local lo, hi = vm:GetPoseParameterRange(id >= 0 and id or 0)
        print(string.format("  %s: id %d, range %s..%s, wanted %.2f, client value %.2f",
            name, id, tostring(lo), tostring(hi), want, vm:GetPoseParameter(name)))
    end

    if vm:LookupPoseParameter("gripweight") >= 0 then
        print(string.format("  gripweight: %.2f, cycle %.3f", vm:GetPoseParameter("gripweight"), vm:GetCycle()))
    end
end)

local function ResetForeignViewmodel(vm)
    if vm.SandSwepHandScale then SandSwep.ClearHandScale(vm) end
    if vm.SandSwepGLRound then SandSwep.ClearGLRound(vm) end

    if vm.SandSwepBodygroups then
        for i = 0, vm:GetNumBodyGroups() - 1 do vm:SetBodygroup(i, 0) end
        vm:SetSkin(0)
        vm.SandSwepBodygroups = nil
    end

    if vm.SandSwepPoses then
        for name in pairs(vm.SandSwepPoses) do vm:SetPoseParameter(name, 0) end
        vm.SandSwepPoses = nil
        vm.SandSwepGrip = nil
    end
end

hook.Add("PreDrawViewModel", "SandSwep_ResetBodygroups", function(vm, ply, wep)
    if not IsValid(vm) or (IsValid(wep) and wep.IsSandSwep) then return end
    ResetForeignViewmodel(vm)
end)

local function EditorSlider(frame, label, get, set, min, max)
    local slider = vgui.Create("DNumSlider", frame)
    slider:Dock(TOP)
    slider:DockMargin(4, 2, 4, 2)
    slider:SetText(label)
    slider:SetMinMax(min, max)
    slider:SetDecimals(3)
    slider:SetValue(get())
    slider.OnValueChanged = function(_, value) set(value) end
end

local function OpenEditor(wep, slotName, id, edit)
    local frame = vgui.Create("DFrame")
    frame:SetTitle("Attachment editor - " .. id .. " on bone " .. edit.Bone)
    frame:SetSize(420, 330)
    frame:SetPos(30, ScrH() / 2 - 165)
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(false)

    frame.OnClose = function()
        if IsValid(wep) and wep._attEdit then
            wep._attEdit[slotName] = nil
            if not next(wep._attEdit) then wep._attEdit = nil end
            wep._attEditVer = (wep._attEditVer or 0) + 1
        end
    end

    EditorSlider(frame, "X", function() return edit.Pos.x end, function(v) edit.Pos.x = v end, -6, 6)
    EditorSlider(frame, "Y", function() return edit.Pos.y end, function(v) edit.Pos.y = v end, -6, 6)
    EditorSlider(frame, "Z", function() return edit.Pos.z end, function(v) edit.Pos.z = v end, -6, 6)
    EditorSlider(frame, "Pitch", function() return edit.Ang.p end, function(v) edit.Ang.p = v end, -180, 180)
    EditorSlider(frame, "Yaw", function() return edit.Ang.y end, function(v) edit.Ang.y = v end, -180, 180)
    EditorSlider(frame, "Roll", function() return edit.Ang.r end, function(v) edit.Ang.r = v end, -180, 180)

    local copy = vgui.Create("DButton", frame)
    copy:Dock(BOTTOM)
    copy:DockMargin(4, 4, 4, 4)
    copy:SetText("Copy offset to clipboard")
    copy.DoClick = function()
        local line = string.format('%s = { Bone = "%s", Pos = Vector(%.3f, %.3f, %.3f), Ang = Angle(%.2f, %.2f, %.2f) },',
            id, edit.Bone, edit.Pos.x, edit.Pos.y, edit.Pos.z, edit.Ang.p, edit.Ang.y, edit.Ang.r)
        SetClipboardText(line)
        print("[sandswep] " .. line)
    end
end

concommand.Add("sandswep_atteditor", function(_, _, args)
    local ply = LocalPlayer()
    local wep = IsValid(ply) and ply:GetActiveWeapon()
    if not IsValid(wep) or not wep.IsSandSwep then
        print("[sandswep] Hold a sandswep weapon first.")
        return
    end

    local slotName = args[1]
    local id = slotName and wep:GetSlotAttachment(slotName)
    local def = id and SandSwep.Attachments[id]
    if not def then
        print("[sandswep] usage: sandswep_atteditor <slot>  (the slot needs an attachment fitted)")
        return
    end

    local current = wep:GetAttachmentOffset(slotName, id, def) or {}
    local ang = current.Ang or angle_zero
    local edit = {
        Bone = current.Bone or def.MountBone or "A_Optic",
        Pos = Vector(current.Pos or vector_origin),
        Ang = Angle(ang.p, ang.y, ang.r),
    }

    wep._attEdit = wep._attEdit or {}
    wep._attEdit[slotName] = edit
    wep._attEditVer = (wep._attEditVer or 0) + 1
    OpenEditor(wep, slotName, id, edit)
end)
