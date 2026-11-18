SWEP.Base           = "weapon_base"
SWEP.PrintName      = "Sandstorm Base"
SWEP.Author         = "rtx & sprite"
SWEP.Category       = "Sandstorm SWEPs"
SWEP.Spawnable      = false
SWEP.AdminOnly      = false
SWEP.IsSandSwep     = true

SWEP.ViewModel      = "models/weapons/c_smg1.mdl"
SWEP.WorldModel     = "models/weapons/w_smg1.mdl"
SWEP.UseHands       = true
SWEP.ViewModelFOV   = 54
SWEP.HoldType       = "smg"

SWEP.Slot           = 2
SWEP.SlotPos        = 1
SWEP.DrawAmmo       = true
SWEP.DrawCrosshair  = true

-- Primary fire
SWEP.Primary.ClipSize       = 30        -- rounds per magazine
SWEP.Primary.DefaultClip    = 30
SWEP.Primary.Ammo           = "SMG1"
SWEP.Primary.Automatic      = true
SWEP.Primary.Damage         = 25
SWEP.Primary.MinDamage      = 0.3       -- fraction of full damage a slowed bullet still does
SWEP.Primary.NumShots       = 1
SWEP.Primary.Spread         = 0.02
SWEP.Primary.RPM            = 700
SWEP.Primary.Recoil         = 0.6
SWEP.Primary.Sound          = Sound("Weapon_SMG1.Single")
SWEP.Primary.DryFireSound   = Sound("Weapon_Pistol.Empty")

SWEP.Secondary.ClipSize     = -1
SWEP.Secondary.DefaultClip  = -1
SWEP.Secondary.Ammo         = "none"
SWEP.Secondary.Automatic    = false

SWEP.StartingMags           = 4
SWEP.MaxMags                = 0         -- max spare mags carried, 0 = no limit
SWEP.ChamberRound           = true
SWEP.HUDShownMags           = 3
SWEP.HideExactAmmo          = false

SWEP.QuickReloadWindow      = 0.35
SWEP.StagedReloads          = true
SWEP.SprintInterruptsReload = true
SWEP.Ejects                 = nil
SWEP.ShellModel             = "models/weapons/rifleshell.mdl"
SWEP.ShellAttachment        = "shell"
SWEP.ShellVelocity          = Vector(0, 150, 70)
SWEP.ShellSounds            = { "player/pl_shell1.wav", "player/pl_shell2.wav", "player/pl_shell3.wav" }
SWEP.IdleFidgetTime         = 35
SWEP.AutoResumeReload       = false

SWEP.MagCheckTime           = 1.0
SWEP.MagCheckSpeed          = 1.25
SWEP.MagCheckHoldTime       = 0.3
SWEP.DeployTime             = 0.6
SWEP.HolsterAnim            = true
SWEP.HolsterSpeed           = 1
SWEP.HolsterSound           = nil

-- Underbarrel grenade launcher (attachment with GL = { ... })
sound.Add({
    name = "SandSwep.GL.Fire",
    channel = CHAN_WEAPON,
    volume = 1,
    level = 90,
    pitch = { 97, 103 },
    sound = { "sandstorm/m203/fire_01.ogg", "sandstorm/m203/fire_02.ogg", "sandstorm/m203/fire_03.ogg" },
})
sound.Add({
    name = "SandSwep.GP25.Fire",
    channel = CHAN_WEAPON,
    volume = 1,
    level = 90,
    pitch = { 97, 103 },
    sound = { "sandstorm/gp25/fire_01.ogg", "sandstorm/gp25/fire_02.ogg", "sandstorm/gp25/fire_03.ogg" },
})
sound.Add({
    name = "SandSwep.M203PI.Fire",
    channel = CHAN_WEAPON,
    volume = 1,
    level = 90,
    pitch = { 97, 103 },
    sound = { "sandstorm/m203pi/fire_01.ogg", "sandstorm/m203pi/fire_02.ogg", "sandstorm/m203pi/fire_03.ogg" },
})
sound.Add({
    name = "SandSwep.GL.Dry",
    channel = CHAN_ITEM,
    volume = 0.7,
    level = 60,
    pitch = { 95, 105 },
    sound = {
        "sandstorm/shared/foley/launcher_dry_fire_01.ogg",
        "sandstorm/shared/foley/launcher_dry_fire_02.ogg",
        "sandstorm/shared/foley/launcher_dry_fire_03.ogg",
    },
})

SWEP.GLDefaults = {
    Ammo        = "SMG1_Grenade",   -- reserve pool (HL2 SMG grenades)
    StartAmmo   = 3,
    Velocity    = 2600,
    Damage      = 150,              -- blast damage (HL2 SMG grenade: 100)
    Radius      = 312.5,            -- blast radius (HL2 SMG grenade: 250)
    ArmDistance = 262,
    DudDamage   = 35,               -- what a dud does to whatever it hits
    Recoil      = 4,                -- view kick (degrees)
    FireDelay   = 0.6,
    Sound       = "SandSwep.GL.Fire",
    DrySound    = "SandSwep.GL.Dry",
}

-- Melee (gun butt / muzzle strike, Sandstorm style)
SWEP.MeleeEnabled           = false
SWEP.MeleeDamage            = 60
SWEP.MeleeRange             = 50        -- units from the eye
SWEP.MeleeHullSize          = 6         -- half-size of the swept box
SWEP.MeleeHitTime           = 0.22      -- seconds into the anim the blow lands
SWEP.MeleeRecovery          = 1.0
SWEP.MeleeForce             = 9000      -- physics push on props / ragdolls
SWEP.MeleeSwingSound        = "Weapon_Crowbar.Single"
SWEP.MeleeHitWorldSound     = "Weapon_Crowbar.Melee_HitWorld"
SWEP.MeleeHitFleshSound     = "Flesh.ImpactHard"

-- Tables guns define stay nil here: SWEP inheritance would merge base lists into theirs
SWEP.Anims                  = nil
SWEP.AnimSets               = nil
SWEP.AttachmentSlots        = nil

SWEP.ReloadSpeed            = 1         -- playback multiplier for reload anims
SWEP.MuteModelSounds        = true
SWEP.ZoomBumpPos            = Vector(0, 0, 0)
SWEP.ZoomBumpAng            = Angle(0, 0, 1.5)
SWEP.ZoomBumpTime           = 0.6
SWEP.ZoomBumpFreq           = 3.2
SWEP.ZoomBumpDamp           = 6
SWEP.VariableZoomSoundIn    = "SandSwep.SS.ToggleScope_Zoom_In"
SWEP.VariableZoomSoundOut   = "SandSwep.SS.ToggleScope_Zoom_Out"

SWEP.ProceduralMagCheck     = nil
SWEP.MagCheckPos            = Vector(-2, -1, 1.5)   -- x right, y forward, z up
SWEP.MagCheckAng            = Angle(12, 12, 40)
SWEP.ResumeBlendMax         = 0.25
SWEP.ReloadStageBlend       = 0.2
SWEP.MagCheckBlendIn        = 0.25
SWEP.MagCheckBlendOut       = 0.3       -- fraction spent returning

-- Sounds
SWEP.FireSounds = {
    Close         = nil,    -- the shot, heard by everyone nearby
    Mech          = nil,
    Distant       = nil,
    DistantRange  = 1500,
    DistantLevel  = 140,
    TailOutdoor   = nil,
    TailIndoor    = nil,
    LowAmmo       = "SandSwep.LowAmmo",
    LowAmmoCount  = 5,
    LowAmmoPitchStep = 5,
}

SWEP.SoundEvents = {}

SWEP.AimInSound             = "SandSwep.ADS.RifleIn"
SWEP.AimOutSound            = "SandSwep.ADS.RifleOut"

-- Fire modes
SWEP.FireModes              = nil       -- e.g. { "safe", "semi", "auto" }
SWEP.DefaultFireMode        = nil       -- nil = first non-safe mode
SWEP.BurstCount             = 3
SWEP.BurstDelay             = 0.25      -- extra pause after a burst
SWEP.FireModeSwitchDelay    = 0.3       -- min time between switches
SWEP.FireModeSound          = Sound("weapons/smg1/switch_single.wav")

SWEP.SafePos                = Vector(2, -2, -1.5)
SWEP.SafeAng                = Angle(-20, 25, -15)
SWEP.SafeLowerTime          = 0.35      -- seconds to lower into safe
SWEP.SafeRaiseTime          = 0.3
SWEP.SafeHoldType           = "passive" -- third-person hold type while safe

-- Aiming down sights
SWEP.Sights = {
    { Name = "IRONS", Pos = Vector(-6.4, -4, 1.05), Ang = Angle(0, 0, 0), Zoom = 1.15 },
}
SWEP.AimTime                = 0.3
SWEP.AimMoveSpeed           = 0.65      -- movement speed multiplier while aimed
SWEP.AimSpreadMult          = 0.25      -- spread multiplier while aimed
SWEP.PointAimPos            = Vector(-2, 0, 0)
SWEP.PointAimAng            = Angle(0, 0, -45)
SWEP.PointAimTime           = 0
SWEP.PointAimSpring         = 10
SWEP.PointAimDamping        = 0.75
SWEP.PointAimZoom           = 1
SWEP.AimRecoilMult          = 0.7       -- recoil multiplier while aimed
SWEP.AimDuringReload        = false     -- stay aimed while reloading
SWEP.AimInPos               = Vector(0, 0, -0.6)
SWEP.AimInAng               = Angle(0, 0, -6)
SWEP.SightSwitchTime        = 0.25      -- blend time between sights
SWEP.SightSwitchSound       = Sound("weapons/smg1/switch_burst.wav")

-- Aim deadzone (free aim)
SWEP.DeadzonePitch          = 3
SWEP.DeadzoneYaw            = 6
SWEP.DeadzoneLead           = 0.6
SWEP.DeadzoneSoftness       = 2
SWEP.DeadzoneSmoothing      = 18
SWEP.DeadzoneViewModelScale = 1

-- Movement: Sandstorm walk bob + sprint
SWEP.BobScale               = 0         -- engine (HL2) bob: off
SWEP.SwayScale              = 0
SWEP.WalkBobScale           = 1
SWEP.WalkBobAimScale        = 1
SWEP.WalkBobLean            = 1
SWEP.WalkBobRefSpeed        = 200

SWEP.SprintInTime           = 0.4       -- seconds into the sprint pose
SWEP.SprintOutTime          = 0.35
SWEP.SprintPos              = Vector(3, -1, -2)     -- procedural sprint pose (no sprint anims)
SWEP.SprintAng              = Angle(-15, 35, -15)
SWEP.SprintBobScale         = 2.5
SWEP.SprintHoldType         = "passive" -- third-person hold type while sprinting
SWEP.SprintCameraScale      = 1.5

SWEP.CameraAnimBone         = "b_camera"
SWEP.CameraAnimScale        = 1
SWEP.CameraAnimAimScale     = 0.5       -- while aimed
SWEP.CameraAnimLockViewModel = true     -- false = gun turns with the camera

SWEP.FocusZoom              = 1.15      -- extra zoom on top of the sight's
SWEP.FocusEaseTime          = 0.3       -- seconds to settle in / out
SWEP.FocusDuration          = 5         -- seconds of held breath from full
SWEP.FocusRecoverTime       = 8         -- seconds to refill from empty
SWEP.FocusMinBreath         = 0.3
SWEP.FocusSwayScale         = 0.15      -- breathing / walk sway left while holding
SWEP.FocusVignette          = 0.85
SWEP.BreathScale            = 1
SWEP.BreathAimScale         = 0.3       -- breathing left while aimed
SWEP.JumpMotionScale        = 1
SWEP.JumpMotionAimScale     = 0.3
SWEP.JumpCameraScale        = 0.35
