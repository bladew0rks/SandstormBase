if not CLIENT then return end

local Developer = SandSwep.BaseShared.Developer

local cvStep = CreateClientConVar("cl_sandswep_debug_seqstep", "0", false, false, "Hold the viewmodel on a chosen sequence frame (needs developer 1)", 0, 1)
local cvSeq = CreateClientConVar("cl_sandswep_debug_seq", "", false, false, "Sequence held by the sequence stepper")
local cvFrame = CreateClientConVar("cl_sandswep_debug_frame", "0", false, false, "Frame held by the sequence stepper", 0, 10000)

function SandSwep.SeqStepLastFrame(vm, name)
    local data = SandSwep.GetSequenceData(vm:GetModel(), name)
    return data and math.max(data.frames - 1, 1) or 1
end

function SWEP:ApplySeqStep(vm)
    self._seqStep = nil
    if not cvStep:GetBool() or not Developer() then return end

    local name = cvSeq:GetString()
    local seq = name ~= "" and vm:LookupSequence(name) or -1
    if not seq or seq < 0 then return end

    local last = SandSwep.SeqStepLastFrame(vm, name)
    vm:SetSequence(seq)
    vm:SetCycle(math.Clamp(cvFrame:GetFloat(), 0, last) / last)
    vm:InvalidateBoneCache()

    self._seqStep = true
end

concommand.Add("sandswep_seqstep", function(_, _, args)
    local ply = LocalPlayer()
    local vm = IsValid(ply) and ply:GetViewModel()
    local name = cvSeq:GetString()
    if not IsValid(vm) or name == "" then return end

    local last = SandSwep.SeqStepLastFrame(vm, name)
    local frame = math.Clamp(math.Round(cvFrame:GetFloat() + (tonumber(args[1]) or 1)), 0, last)

    RunConsoleCommand("cl_sandswep_debug_frame", tostring(frame))
    RunConsoleCommand("cl_sandswep_debug_seqstep", "1")
end)
