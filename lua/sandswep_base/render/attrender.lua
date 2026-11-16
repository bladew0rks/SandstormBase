if not CLIENT then return end

local cvSightDev = GetConVar("cl_sandswep_sightdev")

function SWEP:PrecacheAssets()
    local cache = self:AttCache()
    if cache.assets then return end
    cache.assets = true

    self:PrecacheShells()
    self:PrecacheReticles()
    if SandSwepFX and SandSwepFX.Precache then SandSwepFX.Precache(self) end
    if SandSwep.PrecacheMagProps then SandSwep.PrecacheMagProps(self) end
end

function SWEP:PreDrawViewModel(vm)
    local bonePos, boneAng = vm.SandSwepBonePos, vm.SandSwepBoneAng
    if bonePos and boneAng then
        local pos, ang = vm:GetPos(), vm:GetAngles()
        local moved = bonePos:DistToSqr(pos) > 1e-6
            or math.abs(math.AngleDifference(boneAng.p, ang.p)) > 1e-3
            or math.abs(math.AngleDifference(boneAng.y, ang.y)) > 1e-3
            or math.abs(math.AngleDifference(boneAng.r, ang.r)) > 1e-3

        if moved then
            vm:InvalidateBoneCache()
        end
    end

    self:PrecacheAssets()
    self:HookBoneBlend(vm)
    self:ApplyGLRound(vm)
    self:ApplyParkedBones(vm)
    self:ApplyMagRoundBones(vm)
    self:ApplyHandScale(vm)
    self:ApplyAnimOffset(vm)
    self:ApplySeqStep(vm)
    self:ApplyCoverPose(vm)
    self:ApplyVMFireModePose(vm)

    if next(self:GetAttachmentSlots()) then
        self:ApplyVMBodygroups(vm)
        self:ApplyVMPoseParams(vm)
        self:ApplyGripWeight(vm)
    end
end

function SWEP:PostDrawViewModel(vm)
    if not next(self:GetAttachmentSlots()) then return end
    self:UpdateVMAttachmentModels(vm)

    cvSightDev = cvSightDev or GetConVar("cl_sandswep_sightdev")
    local aimT = (cvSightDev and cvSightDev:GetBool()) and 1 or self:GetAimProgress()
    local active = self:GetActiveSight()

    self:DrawVMAttachments(vm, active, aimT)
    self:DrawVMLaser(self:UpdateTacticalBeam())
    if aimT > 0.05 then self:DrawOpticOverlay(active, aimT) end
end
