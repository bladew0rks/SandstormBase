if not CLIENT then return end

SandSwep.HandEdit = SandSwep.HandEdit or {}

local FULL, NONE = 0.6, 2.0
local FIELDS = { "LeftHandDrop", "LeftHandRoll", "LeftHandPivotUp", "LeftHandPos", "LeftHandAng", "LeftElbow",
    "LeftForearmRoll", "LeftWristTwist", "LeftHandFadeFull", "LeftHandFadeNone", "LeftHandMarkers" }

local function MarkerWeight(marks, cycle)
    local count = #marks
    if cycle <= marks[1][1] then return marks[1][2] end
    if cycle >= marks[count][1] then return marks[count][2] end

    for i = 1, count - 1 do
        local from, to = marks[i], marks[i + 1]
        if cycle <= to[1] then
            local span = to[1] - from[1]
            return span > 0 and Lerp((cycle - from[1]) / span, from[2], to[2]) or to[2]
        end
    end

    return marks[count][2]
end

local function Rod(vec, axis, cos, sin)
    return vec * cos + axis:Cross(vec) * sin + axis * (axis:Dot(vec) * (1 - cos))
end

local function RodXYZ(vx, vy, vz, ax, ay, az, cos, sin)
    local dot = (ax * vx + ay * vy + az * vz) * (1 - cos)
    return vx * cos + (ay * vz - az * vy) * sin + ax * dot,
        vy * cos + (az * vx - ax * vz) * sin + ay * dot,
        vz * cos + (ax * vy - ay * vx) * sin + az * dot
end

local function Turn(mat, axis, cos, sin, pivot)
    local m11, m12, m13, m14, m21, m22, m23, m24, m31, m32, m33, m34 = mat:Unpack()
    local ax, ay, az = axis.x, axis.y, axis.z
    local px, py, pz = pivot.x, pivot.y, pivot.z

    m11, m21, m31 = RodXYZ(m11, m21, m31, ax, ay, az, cos, sin)
    m12, m22, m32 = RodXYZ(m12, m22, m32, ax, ay, az, cos, sin)
    m13, m23, m33 = RodXYZ(m13, m23, m33, ax, ay, az, cos, sin)
    m14, m24, m34 = RodXYZ(m14 - px, m24 - py, m34 - pz, ax, ay, az, cos, sin)

    mat:SetUnpacked(
        m11, m12, m13, m14 + px,
        m21, m22, m23, m24 + py,
        m31, m32, m33, m34 + pz,
        0, 0, 0, 1)
    return mat
end

local function Between(from, to)
    local fromLen, toLen = from:Length(), to:Length()
    if fromLen < 1e-6 or toLen < 1e-6 then return end

    local axis = from:Cross(to)
    local sin = axis:Length() / (fromLen * toLen)
    if sin < 1e-5 then return end

    return axis:GetNormalized(), math.Clamp(from:Dot(to) / (fromLen * toLen), -1, 1), sin
end

local function Subtree(ent, bone, out)
    out[#out + 1] = bone
    for _, child in ipairs(ent:GetChildBones(bone) or {}) do Subtree(ent, child, out) end
    return out
end

local function BoneSet(vm)
    local model = vm:GetModel()
    if vm.SandSwepHandBones and vm.SandSwepHandBones.model == model then return vm.SandSwepHandBones end

    local bones = { model = model }
    for k, name in pairs({ up = "b_ch_l_upperarm", fore = "b_ch_l_forearm", hand = "b_ch_l_hand",
                           wpn = "b_wpn", fg = "b_wpn_foregrip" }) do
        bones[k] = vm:LookupBone(name)
        if not bones[k] then bones.missing = true end
    end

    if not bones.missing then
        bones.upTree, bones.foreTree, bones.handTree = Subtree(vm, bones.up, {}), Subtree(vm, bones.fore, {}), Subtree(vm, bones.hand, {})

        bones.twist = {}
        for i = 1, 7 do
            local id = vm:LookupBone("b_ch_l_forearm_twist" .. i)
            if id then bones.twist[#bones.twist + 1] = id end
        end

        bones.hold = {}
    end

    vm.SandSwepHandBones = bones
    return bones
end

function SWEP:GetHandPoseSource()
    local id = self.GetSlotAttachment and self:GetSlotAttachment("underbarrel")
    local def = id and SandSwep.Attachments[id]
    if def then return def, id end

    return self, "weapon:" .. self:GetClass()
end

function SWEP:GetHandPose(out)
    local src, key = self:GetHandPoseSource()
    local edit = SandSwep.HandEdit[key]

    out = out or {}
    for _, field in ipairs(FIELDS) do
        local value = edit and edit[field]
        if value == nil then value = src[field] end
        out[field] = value
    end

    return out, key, src
end

local function Active(pose)
    return (pose.LeftHandDrop or 0) ~= 0 or (pose.LeftHandRoll or 0) ~= 0 or pose.LeftHandPos or pose.LeftHandAng
        or (pose.LeftElbow or 0) ~= 0 or (pose.LeftForearmRoll or 0) ~= 0 or (pose.LeftWristTwist or 0) ~= 0
end

local function ActiveSource(src, edit)
    if edit then return true end
    return Active(src)
end

local handScratch = {}

function SWEP:VMHandPose(vm)
    local src, key = self:GetHandPoseSource()
    local edit = SandSwep.HandEdit[key]
    if not ActiveSource(src, edit) then return end

    local pose = edit and self:GetHandPose(handScratch) or src
    if not Active(pose) then return end

    local bones = BoneSet(vm)
    if bones.missing then return end

    local wpnM, fgM, handM = vm:GetBoneMatrix(bones.wpn), vm:GetBoneMatrix(bones.fg), vm:GetBoneMatrix(bones.hand)
    if not (wpnM and fgM and handM) then return end

    local wrist = handM:GetTranslation()
    local gripOffset = WorldToLocal(wrist, angle_zero, fgM:GetTranslation(), wpnM:GetAngles())

    local seqName = string.lower(vm:GetSequenceName(vm:GetSequence()) or "")
    if string.find(seqName, "idle", 1, true) then bones.hold[key] = gripOffset end

    local marks = pose.LeftHandMarkers and pose.LeftHandMarkers[seqName]
    local weight
    if marks and #marks > 0 then
        weight = MarkerWeight(marks, vm:GetCycle())
    else
        local hold = bones.hold[key]
        if not hold then return end

        local full = pose.LeftHandFadeFull or FULL
        local none = math.max(pose.LeftHandFadeNone or NONE, full + 0.01)
        weight = 1 - math.Clamp((gripOffset:Distance(hold) - full) / (none - full), 0, 1)
    end
    if weight <= 0 then return end

    local delta = wpnM:GetUp() * (-(pose.LeftHandDrop or 0) * weight)
    local handMats = bones.handMats or {}
    bones.handMats = handMats
    for _, bone in ipairs(bones.handTree) do handMats[bone] = vm:GetBoneMatrix(bone) end

    local _, w12, _, _, _, w22, _, _, _, w32 = wpnM:Unpack()
    local barrel = Vector(-w12, -w22, -w32)
    if (pose.LeftHandRoll or 0) ~= 0 and barrel:LengthSqr() > 1e-6 then
        barrel:Normalize()

        local rad = math.rad(pose.LeftHandRoll * weight)
        local rollCos, rollSin = math.cos(rad), math.sin(rad)
        local pivot = fgM:GetTranslation() + wpnM:GetUp() * (pose.LeftHandPivotUp or 0)

        for _, bone in ipairs(bones.handTree) do
            local mat = handMats[bone]
            if mat then Turn(mat, barrel, rollCos, rollSin, pivot) end
        end
        wrist = Rod(wrist - pivot, barrel, rollCos, rollSin) + pivot
    end

    if pose.LeftHandPos or pose.LeftHandAng then
        local wpnAng = wpnM:GetAngles()
        local angOff = pose.LeftHandAng or angle_zero
        local _, handAng = LocalToWorld(vector_origin, Angle(angOff.p * weight, angOff.y * weight, angOff.r * weight), vector_origin, wpnAng)
        local posOff = LocalToWorld((pose.LeftHandPos or vector_origin) * weight, angle_zero, vector_origin, wpnAng)
        local newWrist = wrist + posOff

        for _, bone in ipairs(bones.handTree) do
            local mat = handMats[bone]
            if mat then
                local scale = mat:GetScale()
                local localPos, localAng = WorldToLocal(mat:GetTranslation(), mat:GetAngles(), wrist, wpnAng)
                local newPos, newAng = LocalToWorld(localPos, localAng, newWrist, handAng)

                mat:Identity()
                mat:SetTranslation(newPos)
                mat:SetAngles(newAng)
                mat:Scale(scale)
            end
        end
        wrist = newWrist
    end

    local upM, foreM = vm:GetBoneMatrix(bones.up), vm:GetBoneMatrix(bones.fore)
    if not (upM and foreM) then return end

    local origWrist = handM:GetTranslation()
    local shoulder, elbow, target = upM:GetTranslation(), foreM:GetTranslation(), wrist + delta
    local upperLen, lowerLen = (elbow - shoulder):Length(), (origWrist - elbow):Length()
    local toTarget = target - shoulder
    local reach = math.Clamp(toTarget:Length(), math.abs(upperLen - lowerLen) + 0.01, upperLen + lowerLen - 0.01)
    local dir = toTarget:GetNormalized()
    local cosA = math.Clamp((upperLen * upperLen + reach * reach - lowerLen * lowerLen) / (2 * upperLen * reach), -1, 1)

    local pole = (elbow - shoulder) - dir * (elbow - shoulder):Dot(dir)
    if pole:LengthSqr() < 1e-8 then return end
    pole:Normalize()

    local newElbow = shoulder + (dir * cosA + pole * math.sqrt(1 - cosA * cosA)) * upperLen
    if (pose.LeftElbow or 0) ~= 0 then
        local rad = math.rad(pose.LeftElbow * weight)
        newElbow = Rod(newElbow - shoulder, dir, math.cos(rad), math.sin(rad)) + shoulder
    end

    local axis, cos, sin = Between(elbow - shoulder, newElbow - shoulder)
    if axis then
        for _, bone in ipairs(bones.upTree) do
            local mat = vm:GetBoneMatrix(bone)
            if mat then vm:SetBoneMatrix(bone, Turn(mat, axis, cos, sin, shoulder)) end
        end
    end

    local turnedWrist = axis and (Rod(origWrist - shoulder, axis, cos, sin) + shoulder) or origWrist
    axis, cos, sin = Between(turnedWrist - newElbow, target - newElbow)
    if axis then
        for _, bone in ipairs(bones.foreTree) do
            local mat = vm:GetBoneMatrix(bone)
            if mat then vm:SetBoneMatrix(bone, Turn(mat, axis, cos, sin, newElbow)) end
        end
    end

    local foreAxis = (target - newElbow):GetNormalized()
    if (pose.LeftForearmRoll or 0) ~= 0 then
        local rad = math.rad(pose.LeftForearmRoll * weight)
        local rollCos, rollSin = math.cos(rad), math.sin(rad)
        for _, bone in ipairs(bones.foreTree) do
            local mat = vm:GetBoneMatrix(bone)
            if mat then vm:SetBoneMatrix(bone, Turn(mat, foreAxis, rollCos, rollSin, newElbow)) end
        end
    end

    if (pose.LeftWristTwist or 0) ~= 0 then
        for i, bone in ipairs(bones.twist) do
            local mat = vm:GetBoneMatrix(bone)
            if mat then
                local rad = math.rad(pose.LeftWristTwist * weight * i / #bones.twist)
                vm:SetBoneMatrix(bone, Turn(mat, foreAxis, math.cos(rad), math.sin(rad), newElbow))
            end
        end
    end

    for _, bone in ipairs(bones.handTree) do
        local mat = handMats[bone]
        if mat then
            mat:SetTranslation(mat:GetTranslation() + delta)
            vm:SetBoneMatrix(bone, mat)
        end
    end
end

local editor

local function GripData()
    local vm = LocalPlayer():GetViewModel()
    local model = IsValid(vm) and vm:GetModel()
    return model and SandSwep.GripData and SandSwep.GripData[string.lower(model)]
end

concommand.Add("sandswep_handeditor", function()
    if IsValid(editor) then
        editor:Remove()
        return
    end

    local wep = LocalPlayer():GetActiveWeapon()
    if not IsValid(wep) or not wep.IsSandSwep then
        print("[sandswep] hold a SandSwep weapon")
        return
    end

    local pose, key, src = wep:GetHandPose()
    local cur = SandSwep.HandEdit[key]
    if not cur then
        cur = {}
        for k, v in pairs(pose) do
            if isvector(v) then
                cur[k] = Vector(v)
            elseif isangle(v) then
                cur[k] = Angle(v)
            elseif istable(v) then
                cur[k] = table.Copy(v)
            else
                cur[k] = v
            end
        end
        cur.LeftHandPos = cur.LeftHandPos or Vector()
        cur.LeftHandAng = cur.LeftHandAng or Angle()
        SandSwep.HandEdit[key] = cur
    end

    local grip = GripData()
    local gripId = key:sub(1, 7) ~= "weapon:" and key or nil

    editor = vgui.Create("DFrame")
    editor:SetTitle("Hand editor: " .. (src.Name or src.PrintName or key))
    editor:SetSize(640, 560)
    editor:SetPos(ScrW() - 660, 60)
    editor:SetSizable(true)
    editor:SetMinWidth(420)
    editor:SetMinHeight(300)
    editor:MakePopup()
    editor:SetKeyboardInputEnabled(false)

    local left = vgui.Create("DScrollPanel", editor)
    left:Dock(LEFT)
    local right = vgui.Create("DPanel", editor)
    right:Dock(FILL)
    right:DockMargin(8, 0, 0, 0)
    right.Paint = nil
    editor.PerformLayout = function(self, w, h)
        baseclass.Get("DFrame").PerformLayout(self, w, h)
        left:SetWide(math.floor((w - 18) * 0.55))
    end

    local sliders = {}
    local function Slider(label, min, max, decimals, value, set)
        local slider = left:Add("DNumSlider")
        slider:Dock(TOP)
        slider:SetTall(22)
        slider:SetText(label)
        slider:SetMinMax(min, max)
        slider:SetDecimals(decimals)
        slider:SetValue(value)
        slider.OnValueChanged = function(_, v) set(v) end
        return slider
    end
    local function Field(label, name, min, max, decimals, default)
        sliders[#sliders + 1] = { Slider(label, min, max, decimals, cur[name] or default, function(v) cur[name] = v end), default }
    end
    local function Comp(label, name, comp, min, max, decimals)
        sliders[#sliders + 1] = { Slider(label, min, max, decimals, cur[name][comp], function(v) cur[name][comp] = v end), 0 }
    end

    Comp("X (sideways)", "LeftHandPos", "x", -6, 6, 3)
    Comp("Y (barrel, - = forward)", "LeftHandPos", "y", -6, 6, 3)
    Comp("Z (up)", "LeftHandPos", "z", -6, 6, 3)
    Comp("Pitch", "LeftHandAng", "p", -180, 180, 1)
    Comp("Yaw", "LeftHandAng", "y", -180, 180, 1)
    Comp("Roll", "LeftHandAng", "r", -180, 180, 1)
    Field("Elbow", "LeftElbow", -90, 90, 1, 0)
    Field("Forearm roll", "LeftForearmRoll", -180, 180, 1, 0)
    Field("Wrist twist", "LeftWristTwist", -180, 180, 1, 0)
    Field("Fade: full within", "LeftHandFadeFull", 0, 4, 2, FULL)
    Field("Fade: off past", "LeftHandFadeNone", 0.1, 8, 2, NONE)

    local blendTime = GetConVar("cl_sandswep_grip_blend_time")
    if blendTime then
        Slider("Grip blend time (s)", 0.01, 1, 2, blendTime:GetFloat(), function(v)
            RunConsoleCommand("cl_sandswep_grip_blend_time", string.format("%.2f", v))
        end)
    end

    local combo = left:Add("DComboBox")
    combo:Dock(TOP)
    combo:DockMargin(0, 6, 0, 2)
    if grip and gripId then
        local poses = {}
        for name in pairs(grip.deltas or {}) do
            if not string.find(name, "@", 1, true) and name ~= "_unbase" then poses[#poses + 1] = name end
        end
        table.sort(poses)

        for _, name in ipairs(poses) do combo:AddChoice(name, nil, grip.map[gripId] == name) end
        if not grip.map[gripId] then combo:SetValue("Grip pose") end
        combo.OnSelect = function(_, _, name) grip.map[gripId] = name end
    else
        combo:SetValue(gripId and "no gripdata for this model" or "no foregrip fitted")
    end

    if gripId then
        Slider("Grip weight", 0, 1.5, 2, src.GripWeight or 1, function(v) src.GripWeight = v end)
        Slider("Finger weight", 0, 1.5, 2, src.GripFingerWeight or 1, function(v) src.GripFingerWeight = v end)

        local noads = left:Add("DCheckBoxLabel")
        noads:Dock(TOP)
        noads:DockMargin(0, 4, 0, 4)
        noads:SetText("Grip pose off while aiming")
        noads:SetValue(grip and grip.noads and grip.noads[gripId] and 1 or 0)
        noads.OnChange = function(_, v)
            if not grip then return end
            grip.noads = grip.noads or {}
            grip.noads[gripId] = v or nil
        end
    end

    local buttons = left:Add("DPanel")
    buttons:Dock(TOP)
    buttons:SetTall(28)
    buttons:DockMargin(0, 6, 0, 0)
    buttons.Paint = nil
    local reset = vgui.Create("DButton", buttons)
    reset:Dock(LEFT)
    reset:SetText("Reset arm")
    reset.DoClick = function()
        for _, entry in ipairs(sliders) do entry[1]:SetValue(entry[2]) end
    end
    local copy = vgui.Create("DButton", buttons)
    copy:Dock(FILL)
    copy:DockMargin(6, 0, 0, 0)
    copy:SetText("Copy values")
    buttons.PerformLayout = function(self, w) reset:SetWide(math.floor((w - 6) / 2)) end
    copy.DoClick = function()
        local parts = {}
        for _, field in ipairs(FIELDS) do
            local v = cur[field]
            if isvector(v) then
                if v ~= vector_origin then parts[#parts + 1] = string.format("%s = Vector(%.3f, %.3f, %.3f)", field, v.x, v.y, v.z) end
            elseif isangle(v) then
                if v ~= angle_zero then parts[#parts + 1] = string.format("%s = Angle(%.1f, %.1f, %.1f)", field, v.p, v.y, v.r) end
            elseif isnumber(v) and v ~= 0 then
                parts[#parts + 1] = string.format("%s = %.2f", field, v)
            end
        end

        if cur.LeftHandMarkers and next(cur.LeftHandMarkers) then
            local seqs = {}
            for seq, list in SortedPairs(cur.LeftHandMarkers) do
                if #list > 0 then
                    local points = {}
                    for _, mark in ipairs(list) do points[#points + 1] = string.format("{ %.3f, %d }", mark[1], mark[2]) end
                    seqs[#seqs + 1] = string.format("%s = { %s }", seq, table.concat(points, ", "))
                end
            end
            if #seqs > 0 then parts[#parts + 1] = "LeftHandMarkers = { " .. table.concat(seqs, ", ") .. " }" end
        end

        if gripId then
            if src.GripWeight then parts[#parts + 1] = string.format("GripWeight = %.2f", src.GripWeight) end
            if src.GripFingerWeight then parts[#parts + 1] = string.format("GripFingerWeight = %.2f", src.GripFingerWeight) end
            if grip and grip.map[gripId] then parts[#parts + 1] = "pose = " .. grip.map[gripId] end
            if grip and grip.noads and grip.noads[gripId] then parts[#parts + 1] = "noads = true" end
        end

        local txt = key .. ": " .. table.concat(parts, ", ")
        SetClipboardText(txt)
        print("[sandswep] " .. txt)
    end

    local hold = vgui.Create("DCheckBoxLabel", right)
    hold:Dock(TOP)
    hold:DockMargin(0, 2, 0, 4)
    hold:SetText("Hold frame" .. (GetConVar("developer"):GetInt() > 0 and "" or "  (needs developer 1)"))
    hold:SetConVar("cl_sandswep_debug_seqstep")

    local filter = vgui.Create("DTextEntry", right)
    filter:Dock(TOP)
    filter:SetTall(20)
    filter:SetPlaceholderText("Filter sequences")
    filter:SetUpdateOnType(true)

    local steps = vgui.Create("DPanel", right)
    steps:Dock(BOTTOM)
    steps:SetTall(24)
    steps:DockMargin(0, 4, 0, 0)
    steps.Paint = nil
    local prev = vgui.Create("DButton", steps)
    prev:Dock(LEFT)
    prev:SetText("< Prev")
    prev.DoClick = function() RunConsoleCommand("sandswep_seqstep", "-1") end
    local nxt = vgui.Create("DButton", steps)
    nxt:Dock(FILL)
    nxt:DockMargin(4, 0, 0, 0)
    nxt:SetText("Next >")
    nxt.DoClick = function() RunConsoleCommand("sandswep_seqstep", "1") end
    steps.PerformLayout = function(self, w) prev:SetWide(math.floor((w - 4) / 2)) end

    local frame = vgui.Create("DNumSlider", right)
    frame:Dock(BOTTOM)
    frame:SetTall(22)
    frame:SetText("Frame")
    frame:SetMinMax(0, 100)
    frame:SetDecimals(1)
    frame:SetConVar("cl_sandswep_debug_frame")

    local markPanel = vgui.Create("DPanel", right)
    markPanel:Dock(BOTTOM)
    markPanel:SetTall(24)
    markPanel:DockMargin(0, 4, 0, 0)
    markPanel.Paint = nil
    local markOn = vgui.Create("DButton", markPanel)
    markOn:Dock(LEFT)
    markOn:SetText("IK on here")
    local markOff = vgui.Create("DButton", markPanel)
    markOff:Dock(FILL)
    markOff:DockMargin(4, 0, 0, 0)
    markOff:SetText("IK off here")
    markPanel.PerformLayout = function(self, w) markOn:SetWide(math.floor((w - 4) / 2)) end

    local markList = vgui.Create("DListView", right)
    markList:Dock(BOTTOM)
    markList:SetTall(70)
    markList:DockMargin(0, 4, 0, 0)
    markList:SetMultiSelect(false)
    markList:AddColumn("Frame"):SetFixedWidth(60)
    markList:AddColumn("IK")
    markList:SetTooltip("Double-click a marker to remove it")

    local seqs = vgui.Create("DListView", right)
    seqs:Dock(FILL)
    seqs:DockMargin(0, 4, 0, 0)
    seqs:SetMultiSelect(false)
    seqs:SetHideHeaders(true)
    seqs:SetDataHeight(15)
    seqs:AddColumn("Sequence")

    local function LastFrame(name)
        local vm = LocalPlayer():GetViewModel()
        return IsValid(vm) and SandSwep.SeqStepLastFrame and SandSwep.SeqStepLastFrame(vm, name) or 1
    end
    local function SetMax(name) frame:SetMax(LastFrame(name)) end
    local function CurrentSeq() return string.lower(GetConVar("cl_sandswep_debug_seq"):GetString()) end

    local function RefreshMarks()
        markList:Clear()

        local seq = CurrentSeq()
        local list = cur.LeftHandMarkers and cur.LeftHandMarkers[seq]
        if not list then return end

        local last = math.max(LastFrame(seq), 1)
        for i, mark in ipairs(list) do
            local line = markList:AddLine(string.format("%.1f", mark[1] * last), mark[2] > 0 and "on" or "off")
            line.markIndex = i
        end
    end

    local function AddMark(value)
        local seq = CurrentSeq()
        if seq == "" then return end

        local cycle = math.Clamp(GetConVar("cl_sandswep_debug_frame"):GetFloat() / math.max(LastFrame(seq), 1), 0, 1)
        cur.LeftHandMarkers = cur.LeftHandMarkers or {}

        local list = cur.LeftHandMarkers[seq] or {}
        for i = #list, 1, -1 do
            if math.abs(list[i][1] - cycle) < 1e-4 then table.remove(list, i) end
        end
        list[#list + 1] = { cycle, value }
        table.sort(list, function(a, b) return a[1] < b[1] end)
        cur.LeftHandMarkers[seq] = list

        RefreshMarks()
    end

    markOn.DoClick = function() AddMark(1) end
    markOff.DoClick = function() AddMark(0) end
    markList.DoDoubleClick = function(_, _, line)
        local list = cur.LeftHandMarkers and cur.LeftHandMarkers[CurrentSeq()]
        if list and line.markIndex then table.remove(list, line.markIndex) end
        if list and #list == 0 then cur.LeftHandMarkers[CurrentSeq()] = nil end
        RefreshMarks()
    end

    local function Fill()
        seqs:Clear()

        local vm = LocalPlayer():GetViewModel()
        if not IsValid(vm) then return end

        local want = string.lower(filter:GetValue() or "")
        local current = GetConVar("cl_sandswep_debug_seq"):GetString()
        for i = 0, vm:GetSequenceCount() - 1 do
            local name = vm:GetSequenceName(i)
            if want == "" or string.find(string.lower(name), want, 1, true) then
                local line = seqs:AddLine(name)
                if name == current then seqs:SelectItem(line) end
            end
        end

        if current ~= "" then SetMax(current) end
    end

    filter.OnValueChange = Fill
    seqs.OnRowSelected = function(_, _, line)
        local name = line:GetColumnText(1)
        RunConsoleCommand("cl_sandswep_debug_seq", name)
        RunConsoleCommand("cl_sandswep_debug_frame", "0")
        RunConsoleCommand("cl_sandswep_debug_seqstep", "1")
        SetMax(name)
        timer.Simple(0, RefreshMarks)
    end

    Fill()
    RefreshMarks()
end)

local VMANIP_BONES = {
    "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand",
    "ValveBiped.Bip01_L_Wrist", "ValveBiped.Bip01_L_Ulna",
    "ValveBiped.Bip01_L_Finger0", "ValveBiped.Bip01_L_Finger01", "ValveBiped.Bip01_L_Finger02",
    "ValveBiped.Bip01_L_Finger1", "ValveBiped.Bip01_L_Finger11", "ValveBiped.Bip01_L_Finger12",
    "ValveBiped.Bip01_L_Finger2", "ValveBiped.Bip01_L_Finger21", "ValveBiped.Bip01_L_Finger22",
    "ValveBiped.Bip01_L_Finger3", "ValveBiped.Bip01_L_Finger31", "ValveBiped.Bip01_L_Finger32",
    "ValveBiped.Bip01_L_Finger4", "ValveBiped.Bip01_L_Finger41", "ValveBiped.Bip01_L_Finger42",
}

local function HasGCAL()
    return istable(GCAL) and isfunction(GCAL.RegisterWeaponBaseStrategy)
end

function SandSwep.VManipActive()
    local vmanip = VManip
    return istable(vmanip) and IsValid(vmanip.VMGesture) and vmanip.IsValid ~= nil and vmanip:IsValid() or false
end

local ARM_PARTS = { "Clavicle", "UpperArm", "Forearm", "Ulna", "Wrist", "Hand", "Finger" }

local function ArmSide(name)
    local side = string.match(name, "_([LR])_")
    if not side then return end
    for _, part in ipairs(ARM_PARTS) do
        if string.find(name, part, 1, true) then return side end
    end
end

local function TrackIsArm(track)
    for _, name in ipairs(track.bones or VMANIP_BONES) do
        if ArmSide(name) then return true end
    end
    return false
end

local function TrackWeight(id, track)
    local lerp = tonumber(track.lerpVal) or 1
    if lerp >= 1 then return 1 end

    local curve = track.lerpCurve or (track.data and track.data.lerp_curve) or 1
    local legacy = id == "legacy_left_arm" or (track.data and track.data.legacy)
    if not legacy and isfunction(GCAL.GetTrackBlendFactor) then
        return math.Clamp(GCAL.GetTrackBlendFactor(track, lerp, curve), 0, 1)
    end
    return math.pow(math.Clamp(lerp, 0, 1), curve)
end

local function VManipBlend()
    local vmanip = VManip
    if not istable(vmanip) then return end

    local gesture = vmanip.VMGesture
    if not IsValid(gesture) then return end

    local active = vmanip.IsValid and vmanip:IsValid()
    if not active then return end

    local lerp = tonumber(vmanip.VMatrixlerp) or 1
    if lerp >= 1 then return end

    return gesture, math.pow(math.Clamp(lerp, 0, 1), vmanip.Lerp_Curve or 1)
end

local restWeight = {}

function SandSwep.AnimatedHands()
    restWeight.L, restWeight.R = 1, 1

    if HasGCAL() and isfunction(GCAL.GetActiveTrackIDs) then
        for _, id in ipairs(GCAL:GetActiveTrackIDs()) do
            local track = GCAL:IsTrackActive(id) and GCAL:GetTrack(id)
            if track and TrackIsArm(track) then
                local w = TrackWeight(id, track)
                for _, name in ipairs(track.bones or VMANIP_BONES) do
                    local side = ArmSide(name)
                    if side and w < restWeight[side] then restWeight[side] = w end
                end
            end
        end
    else
        local _, w = VManipBlend()
        if w then restWeight.L = w end
    end

    return restWeight
end

local function BlendBones(vm, model, bones, sources, weight)
    for k, name in ipairs(bones) do
        local srcName = sources and sources[k] or name
        if srcName == "ValveBiped.Bip01_L_Ulna" then srcName = "ValveBiped.Bip01_L_Forearm" end
        if srcName == "ValveBiped.Bip01_R_Ulna" then srcName = "ValveBiped.Bip01_R_Forearm" end

        local bone = vm:LookupBone(name)
        local src = bone and model:LookupBone(srcName)
        local cur = src and vm:GetBoneMatrix(bone)
        local target = cur and model:GetBoneMatrix(src)

        if target then
            local a, b = target:ToTable(), cur:ToTable()
            for r = 1, 4 do
                local ra, rb = a[r], b[r]
                for c = 1, 4 do ra[c] = ra[c] + (rb[c] - ra[c]) * weight end
            end

            local out = Matrix(a)
            out:SetScale(cur:GetScale())
            vm:SetBoneMatrix(bone, out)
        end
    end
end

local function ApplyGCAL(vm)
    for _, id in ipairs(GCAL:GetActiveTrackIDs()) do
        local track = GCAL:IsTrackActive(id) and GCAL:GetTrack(id)
        if track and IsValid(track.model) and TrackIsArm(track) then
            local weight = TrackWeight(id, track)
            if weight < 1 then
                BlendBones(vm, track.model, track.bones or VMANIP_BONES, track.sourceBones, weight)
            end
        end
    end
end

function SWEP:VMVManip(vm)
    if HasGCAL() and isfunction(GCAL.GetActiveTrackIDs) then return ApplyGCAL(vm) end

    local gesture, weight = VManipBlend()
    if gesture then BlendBones(vm, gesture, VMANIP_BONES, nil, weight) end
end

local function InterruptReload()
    local ply = LocalPlayer()
    local wep = IsValid(ply) and ply:GetActiveWeapon()
    if IsValid(wep) and wep.IsSandSwep and wep:IsReloading() then
        RunConsoleCommand("sandswep_interruptreload")
    end
end

hook.Add("GCALTrackStarted", "SandSwep_InterruptReload", function(_, _, track)
    if istable(track) and TrackIsArm(track) then InterruptReload() end
end)

hook.Add("VManipPostPlayAnim", "SandSwep_InterruptReload", function()
    if not HasGCAL() then InterruptReload() end
end)
