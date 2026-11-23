local RET = "models/weapons/sandswep/reticles/"

local EOTECH_SKINS = {
    { Name = "Black", Color = Color(30, 30, 30),    Skin = 0 },
    { Name = "Tan",   Color = Color(176, 150, 108), Skin = 1 },
}

SandSwep.RegisterAttachment("optic_eotech", {
    Name = "EOTech 553", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_eotech.mdl",
    Skins = EOTECH_SKINS,
    SightPose = "eotech",
    Sights = {
        { Name = "EOTECH", Zoom = 1.15,
          Lens = { Z = 1.425, Attachment = "lens", W = 1.0, H = 0.81 },
          Reticle = { Texture = RET .. "eotech", Size = 1.5 } },
    },
    Stats = { AimTime = 1.05 },
})

SandSwep.RegisterAttachment("optic_kobra", {
    Name = "Kobra", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_kobra.mdl",
    SightPose = "kobra",
    Sights = {
        { Name = "KOBRA", Zoom = 1.15,
          Lens = { Z = 1.480, Attachment = "lens", W = 0.86, H = 0.86 },
          Reticle = { Texture = RET .. "kobra", Color = Color(255, 40, 30), Size = 1.1 } },
    },
    Stats = { AimTime = 1.03 },
})

local ELCAN_PIP = { Magnification = 4, Min = 1, Max = 4, Start = 4, Step = 4, Snap = true, Shutter = 0.45, Sound = "SandSwep.ElcanLever" }

SandSwep.RegisterAttachment("optic_ta31", {
    Name = "ACOG TA31 (4x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_ta31.mdl",
    SightPose = "elcan",
    Sights = {
        { Name = "ACOG 4X", Zoom = 1.1,
          Lens = { Z = 1.360, Attachment = "lens", Radius = 0.42 },
          PIP = { Magnification = 4 },
          Reticle = { Texture = RET .. "acog", FillLens = true } },
    },
    Stats = { AimTime = 1.15, AimMoveSpeed = 0.95 },
})

SandSwep.RegisterAttachment("optic_ta31_rmr", {
    Name = "ACOG TA31 + RMR (4x/1x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_ta31_rmr.mdl",
    SightOffset = Vector(0.000, -0.763, 0.072),
    Sights = {
        { Name = "ACOG 4X", Zoom = 1.1, SwitchSound = "SandSwep.ElcanLever",
          Lens = { Z = 1.359, Attachment = "lens", Radius = 0.418, MaskOffset = 0.01 },
          PIP = { Magnification = 4 },
          Reticle = { Texture = RET .. "acog", FillLens = true } },
        { Name = "RMR", Zoom = 1.15, SwitchSound = "SandSwep.ElcanLever",
          SightOffset = Vector(0.000, -0.763, -1.267),
          Lens = { Z = 2.642, Attachment = "lens_rmr", W = 0.80, H = 0.59 },
          Reticle = { Texture = RET .. "dot", Color = Color(212, 0, 16), Size = 0.225 } },
    },
    Stats = { AimTime = 1.16, AimMoveSpeed = 0.95 },
})

SandSwep.RegisterAttachment("optic_m3a_low", {
    Name = "M3A Low (7x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_m3a_low.mdl",
    SightOffset = Vector(0.000, 0.660, 0.682),
    Sights = {
        { Name = "M3A 7X", Zoom = 1.1,
          Lens = { Z = 0.761, Attachment = "lens", Radius = 0.674, MaskOffset = 0.01 },
          PIP = { Magnification = 7 },
          Reticle = { Texture = RET .. "m3a", FillLens = true } },
    },
    Stats = { AimTime = 1.24, AimMoveSpeed = 0.93 },
})

SandSwep.RegisterAttachment("optic_elcan_rmr", {
    Name = "ELCAN Specter + RMR (1-4x/1x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_elcan_rmr.mdl",
    Skins = {
        { Name = "Black", Color = Color(30, 30, 30),    Skin = 0 },
        { Name = "Tan",   Color = Color(176, 150, 108), Skin = 1 },
    },
    SightOffset = Vector(0.000, -1.400, 0.060),
    Sights = {
        { Name = "ELCAN 1-4X", Zoom = 1.1, SwitchSound = "SandSwep.ElcanLever",
          Lens = { Z = 1.371, Attachment = "lens", Radius = 0.540, MaskOffset = 0.01 },
          PIP = ELCAN_PIP,
          Reticle = { Texture = RET .. "elcan", FillLens = true } },
        { Name = "RMR", Zoom = 1.15, SwitchSound = "SandSwep.ElcanLever",
          SightOffset = Vector(0.000, -1.400, -1.377),
          Lens = { Z = 2.833, Attachment = "lens_rmr", W = 0.65, H = 0.44 },
          Reticle = { Texture = RET .. "dot", Color = Color(212, 0, 16), Size = 0.225 } },
    },
    Stats = { AimTime = 1.17, AimMoveSpeed = 0.95 },
})

SandSwep.RegisterAttachment("optic_okp7", {
    Name = "OKP-7", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_okp7.mdl",
    SightPose = "okp",
    Sights = {
        { Name = "OKP-7", Zoom = 1.15,
          Lens = { Z = 0.554, Attachment = "lens", W = 1.04, H = 1.04 },
          Reticle = { Texture = RET .. "okp7", Color = Color(70, 255, 90), Size = 2.4 } },
    },
    Stats = { AimTime = 1.03 },
})

SandSwep.RegisterAttachment("optic_pkas", {
    Name = "PKA-S (1.5x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_pkas.mdl",
    SightPose = "pkas",
    Sights = {
        { Name = "PKA-S 1.5X", Zoom = 1.1,
          Lens = { Z = 0.758, Attachment = "lens", Radius = 0.387 },
          PIP = { Magnification = 1.5 },
          Reticle = { Texture = RET .. "pkas", Size = 2.3 } },
    },
    Stats = { AimTime = 1.06 },
})

SandSwep.RegisterAttachment("optic_pkas_rail", {
    Name = "PKA-S (1.5x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_pkas_rail.mdl",
    SightPose = "pkas_rail",
    Sights = {
        { Name = "PKA-S 1.5X", Zoom = 1.1,
          Lens = { Z = 1.758, Attachment = "lens", Radius = 0.387 },
          PIP = { Magnification = 1.5 },
          Reticle = { Texture = RET .. "pkas", Size = 2.3 } },
    },
    Stats = { AimTime = 1.06 },
})

SandSwep.RegisterAttachment("optic_ak_kobra", {
    Name = "Kobra (Side Mount)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_ak_kobra.mdl",
    SightPose = "ak_kobra",
    Sights = {
        { Name = "KOBRA", Zoom = 1.15,
          Lens = { Z = 2.515, Attachment = "lens", W = 0.86, H = 0.86 },
          Reticle = { Texture = RET .. "kobra", Color = Color(255, 40, 30), Size = 1.1 } },
    },
    Stats = { AimTime = 1.04 },
})

SandSwep.RegisterAttachment("optic_pso1", {
    Name = "PSO-1 (4x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_pso1.mdl",
    SightPose = "pso",
    Sights = {
        { Name = "PSO-1 4X", Zoom = 1.1,
          Lens = { Z = 0.965, Attachment = "lens", Radius = 0.5 },
          PIP = { Magnification = 4 },
          Reticle = { Texture = RET .. "pso1", FillLens = true } },
    },
    Stats = { AimTime = 1.18, AimMoveSpeed = 0.94 },
})

SandSwep.RegisterAttachment("optic_compm4", {
    Name = "Aimpoint CompM4", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_compm4.mdl",
    SightPose = "aimpoint",
    Sights = {
        { Name = "COMPM4", Zoom = 1.15, Squash = 0.3,
          Lens = { Z = 1.378, Attachment = "lens", Radius = 0.48 },
          Reticle = { Texture = RET .. "dot", Color = Color(255, 35, 25), Size = 0.25 } },
    },
    Stats = { AimTime = 1.03 },
})

local function MagSights(name, magLens, magReticle, dotLens, dotReticle, suffix, closeContact, dotOffset)
    closeContact = closeContact or 0.67
    return {
        { Name = name .. " 2X", Zoom = 1.1,
          Lens = magLens, PIP = { Magnification = 2 }, Reticle = magReticle,
          Toggle = { Anim = "mag_close" .. suffix, Flip = 0,
                     FlipStart = 0.72, FlipTime = 0.15, Commit = closeContact + 0.15,
                     Sounds = { { t = 0.81, s = "SandSwep.SS.WeaponToggle_Optic_Off" } } } },
        { Name = name, Zoom = 1.15, SightOffset = dotOffset,
          Lens = dotLens, Reticle = dotReticle,
          Toggle = { Anim = "mag_open" .. suffix, Flip = 1, FlipStart = 0.65, FlipTime = 0.15, Commit = 0.95,
                     Sounds = { { t = 0.4, s = "SandSwep.SS.WeaponToggle_Optic_On" } } } },
    }
end

SandSwep.RegisterAttachment("optic_compm4_2x", {
    Name = "CompM4 + 2x Magnifier", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_compm4_2x.mdl",
    SightOffset = Vector(0, 1, 0.055),
    FlipSequence = "flip", FlipTime = 0.25, FlipOpenSequence = "flip_open", FlipCloseSequence = "flip_close",
    Sights = MagSights("COMPM4",
        { Z = 1.376, Attachment = "lens", Radius = 0.417, MaskOffset = 0.01 },
        { Texture = RET .. "dot", Color = Color(255, 35, 25), Size = 0.5 },
        { Z = 1.378, Attachment = "lens_dot", Radius = 0.48 },
        { Texture = RET .. "dot", Color = Color(255, 35, 25), Size = 0.25 }, "", nil, Vector(0, 1, 0.053)),
    Stats = { AimTime = 1.1, AimMoveSpeed = 0.97 },
})

SandSwep.RegisterAttachment("optic_eotech_2x", {
    Name = "EOTech + 2x Magnifier", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_eotech_2x.mdl",
    Skins = EOTECH_SKINS,
    SightPose = "eotech2x",
    FlipSequence = "flip", FlipTime = 0.25, FlipOpenSequence = "flip_open", FlipCloseSequence = "flip_close",
    Sights = MagSights("EOTECH",
        { Z = 1.456, Attachment = "lens", Radius = 0.47, MaskOffset = 0.01 },
        { Texture = RET .. "eotech", Size = 3.0 },
        { Z = 1.551, Attachment = "lens_dot", W = 1.08, H = 0.88 },
        { Texture = RET .. "eotech", Size = 1.5 }, "_eotech"),
    Stats = { AimTime = 1.12, AimMoveSpeed = 0.97 },
})

SandSwep.RegisterAttachment("optic_kobra_2x", {
    Name = "Kobra + 2x Magnifier", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_kobra_2x.mdl",
    SightOffset = Vector(0, 1, -0.013),
    FlipSequence = "flip", FlipTime = 0.25, FlipOpenSequence = "flip_open", FlipCloseSequence = "flip_close",
    Sights = MagSights("KOBRA",
        { Z = 1.444, Attachment = "lens", Radius = 0.464, MaskOffset = 0.01 },
        { Texture = RET .. "kobra", Color = Color(255, 40, 30), Size = 2.2 },
        { Z = 1.500, Attachment = "lens_dot", W = 0.86, H = 0.86 },
        { Texture = RET .. "kobra", Color = Color(255, 40, 30), Size = 1.1 }, "_kobra", 0.73, Vector(0, 1, -0.069)),
    Stats = { AimTime = 1.1, AimMoveSpeed = 0.97 },
})

SandSwep.RegisterAttachment("optic_elcan", {
    Name = "ELCAN Specter DR (1-4x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_elcan.mdl",
    Skins = {
        { Name = "Tan",   Color = Color(176, 150, 108), Skin = 0 },
        { Name = "Black", Color = Color(30, 30, 30),    Skin = 1 },
    },
    SightOffset = Vector(0, -1.4, 0.06),
    Sights = {
        { Name = "ELCAN 1-4X", Zoom = 1.1,
          Lens = { Z = 1.371, Attachment = "lens", Radius = 0.54, MaskOffset = 0.01 },
          PIP = ELCAN_PIP,
          Reticle = { Texture = RET .. "elcan", FillLens = true } },
    },
    Stats = { AimTime = 1.18, AimMoveSpeed = 0.95 },
})
sound.Add({ name = "SandSwep.ElcanLever", channel = CHAN_ITEM, volume = 0.6, level = 55,
    pitch = { 92, 100 }, sound = "weapons/smg1/switch_single.wav" })

SandSwep.RegisterAttachment("optic_mro", {
    Name = "Trijicon MRO", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_mro.mdl",
    SightOffset = Vector(0.000, 0.000, 0.157),
    Sights = {
        { Name = "TRIJICON MRO", Zoom = 1.15,
          Lens = { Z = 1.274, Attachment = "lens", W = 0.64, H = 0.64 },
          Reticle = { Texture = RET .. "dot", Color = Color(212, 0, 16), Size = 0.225 } },
    },
    Stats = { AimTime = 1.03 },
})

SandSwep.RegisterAttachment("optic_mars", {
    Name = "MARS", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_mars.mdl",
    SightOffset = Vector(0.000, 0.000, -0.701),
    Sights = {
        { Name = "MARS", Zoom = 1.15,
          Lens = { Z = 2.132, Attachment = "lens", W = 0.94, H = 0.94 },
          Reticle = { Texture = RET .. "dot", Color = Color(212, 0, 16), Size = 0.225 } },
    },
    Stats = { AimTime = 1.04 },
    Laser = true,
    BeamBone = "A_Optic",
    BeamLocal = Vector(-0.25, -0.68, 2.99),
    BeamDir = Vector(0, 0, 1),
    LaserColor = Color(255, 30, 20),
})

SandSwep.RegisterAttachment("optic_romerot8", {
    Name = "Romero T8", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_romerot8.mdl",
    Skins = {
        { Name = "Tan", Color = Color(176, 150, 108), Skin = 0 },
        { Name = "Black", Color = Color(30, 30, 30), Skin = 1 },
    },
    SightOffset = Vector(0.000, 0.000, -0.034),
    Sights = {
        { Name = "ROMERO T8", Zoom = 1.15, Squash = 0.3, SquashAnchor = "rear",
          Lens = { Z = 1.465, Attachment = "lens", W = 1.15, H = 0.79 },
          Reticle = { Texture = RET .. "romerot8", Color = Color(212, 62, 50), Size = 2.0 } },
    },
    Stats = { AimTime = 1.05 },
})

SandSwep.RegisterAttachment("optic_pko6", {
    Name = "PKO-6", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_pko6.mdl",
    SightOffset = Vector(0.000, 0.000, 0.021),
    Sights = {
        { Name = "PKO-6", Zoom = 1.15,
          Lens = { Z = 1.410, Attachment = "lens", W = 1.26, H = 1.24 },
          Reticle = { Texture = RET .. "pko6", Color = Color(212, 0, 16), Size = 2.8 } },
    },
    Stats = { AimTime = 1.04 },
})

SandSwep.RegisterAttachment("optic_c79", {
    Name = "ELCAN C79 (4x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_c79.mdl",
    SightOffset = Vector(0.000, -1.347, 0.008),
    Sights = {
        { Name = "ELCAN C79 4X", Zoom = 1.1, SwitchSound = "SandSwep.ElcanLever",
          Lens = { Z = 1.423, Attachment = "lens", Radius = 0.563, MaskOffset = 0.01 },
          PIP = { Magnification = 4 },
          Reticle = { Texture = RET .. "c79", FillLens = true } },
        { Name = "IRONS", Zoom = 1.15, SwitchSound = "SandSwep.ElcanLever",
          SightOffset = Vector(0.000, -1.347, -1.047) },
    },
    Stats = { AimTime = 1.16, AimMoveSpeed = 0.95 },
})

SandSwep.RegisterAttachment("optic_susat", {
    Name = "SUSAT (4x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_susat.mdl",
    SightOffset = Vector(0.000, -2.522, -0.557),
    Sights = {
        { Name = "SUSAT 4X", Zoom = 1.1, SwitchSound = "SandSwep.ElcanLever",
          Lens = { Z = 1.987, Attachment = "lens", Radius = 0.416, MaskOffset = 0.01 },
          PIP = { Magnification = 4 },
          Reticle = { Texture = RET .. "susat", FillLens = true } },
        { Name = "IRONS", Zoom = 1.15, SwitchSound = "SandSwep.ElcanLever",
          SightOffset = Vector(0.000, -2.522, -1.383) },
    },
    Stats = { AimTime = 1.15, AimMoveSpeed = 0.95 },
})

SandSwep.RegisterAttachment("optic_lpvo", {
    Name = "LPVO (1-6x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_lpvo.mdl",
    SightOffset = Vector(0.000, -0.552, 0.174),
    Sights = {
        { Name = "LPVO 1-6X", Zoom = 1.1,
          Lens = { Z = 1.257, Attachment = "lens", Radius = 0.493, MaskOffset = 0.01 },
          PIP = { Magnification = 6, Min = 1, Max = 6 },
          Reticle = { Texture = RET .. "lpvo", FillLens = true } },
    },
    Stats = { AimTime = 1.2, AimMoveSpeed = 0.94 },
})

SandSwep.RegisterAttachment("optic_lrt", {
    Name = "LRT (1-6x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_lrt.mdl",
    SightOffset = Vector(0.000, -0.713, 0.328),
    Sights = {
        { Name = "LRT 1-6X", Zoom = 1.1,
          Lens = { Z = 1.103, Attachment = "lens", Radius = 0.703, MaskOffset = 0.01 },
          PIP = { Magnification = 6, Min = 1, Max = 6 },
          Reticle = { Texture = RET .. "lrt", FillLens = true } },
    },
    Stats = { AimTime = 1.2, AimMoveSpeed = 0.94 },
})

SandSwep.RegisterAttachment("optic_m3a", {
    Name = "M3A (7x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_m3a.mdl",
    SightOffset = Vector(0.000, 0.739, 0.205),
    Sights = {
        { Name = "M3A 7X", Zoom = 1.1,
          Lens = { Z = 1.226, Attachment = "lens", Radius = 0.674, MaskOffset = 0.01 },
          PIP = { Magnification = 7 },
          Reticle = { Texture = RET .. "m3a", FillLens = true } },
    },
    Stats = { AimTime = 1.24, AimMoveSpeed = 0.93 },
})

SandSwep.RegisterAttachment("optic_hunting", {
    Name = "Hunting Scope (7x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_hunting.mdl",
    SightOffset = Vector(0.000, 1.076, 0.135),
    Sights = {
        { Name = "HUNTING SCOPE 7X", Zoom = 1.1,
          Lens = { Z = 1.296, Attachment = "lens", Radius = 0.677, MaskOffset = 0.01 },
          PIP = { Magnification = 7 },
          Reticle = { Texture = RET .. "hunting", FillLens = true } },
    },
    Stats = { AimTime = 1.24, AimMoveSpeed = 0.93 },
})

SandSwep.RegisterAttachment("optic_pu", {
    Name = "PU Scope (4x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_pu.mdl",
    Bodygroups = { rail = 0 },
    SightPose = "pu",
    SightOffset = Vector(0.000, 4.921, 0.869),
    Sights = {
        { Name = "PU SCOPE 4X", Zoom = 1.1,
          Lens = { Z = 0.562, Attachment = "lens", Radius = 0.440, MaskOffset = 0.01 },
          PIP = { Magnification = 4 },
          Reticle = { Texture = RET .. "pu", FillLens = true } },
    },
    Stats = { AimTime = 1.18, AimMoveSpeed = 0.94 },
})
SandSwep.RegisterAttachment("optic_m997x", {
    Name = "M99 Scope (7x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_m997x.mdl",
    SightOffset = Vector(0.000, 1.988, -0.508),
    Sights = {
        { Name = "M99 SCOPE 7X", Zoom = 1.1,
          Lens = { Z = 1.939, Attachment = "lens", Radius = 0.448, MaskOffset = 0.01 },
          PIP = { Magnification = 7 },
          Reticle = { Texture = RET .. "m3a", FillLens = true } },
    },
    Stats = { AimTime = 1.24, AimMoveSpeed = 0.93 },
})



SandSwep.RegisterAttachment("grip_vertical_qbz97", {
    Name = "Vertical Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_vertgrip.mdl",
    Bodygroups = { railfg = 1 },
    PoseParams = { foregrip = 1 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.9, AimTime = 1.03 },
})

SandSwep.RegisterAttachment("optic_qts11_4x", {
    Name = "QTS-11 4x Scope", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_qts11_4x.mdl",
    SightPose = "qts11_4x",
    Bodygroups = { irons = 2, railoptic = 1 },
    Sights = {
        { Name = "4X", Zoom = 1.1, SightPose = "qts11_4x",
          Lens = { Z = 1.095, Attachment = "lens", Radius = 0.5 },
          PIP = { Magnification = 4 },
          Reticle = { Texture = RET .. "qts11_4x", FillLens = true } },
        { Name = "1X", Zoom = 1.1, SightPose = "qts11_4x",
          Lens = { Z = 1.095, Attachment = "lens", Radius = 0.5 },
          PIP = { Magnification = 1 },
          Reticle = { Texture = RET .. "qts11_4x", FillLens = true } },
    },
    Stats = { AimTime = 1.08 },
})

SandSwep.RegisterAttachment("grip_vertical_qts11", {
    Name = "Vertical Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_vertgrip.mdl",
    Bodygroups = { railb = 1 },
    PoseParams = { foregrip = 1 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.9, AimTime = 1.03 },
})

-- Muzzle: suppressors
SandSwep.RegisterAttachment("muzzle_socom", {
    Name = "SureFire SOCOM556", Slot = "muzzle",
    Model = "models/weapons/sandswep/attachments/a_socom.mdl",
    Suppressor = true,
    Stats = { Recoil = 0.9, AimTime = 1.04 },
})

SandSwep.RegisterAttachment("muzzle_pbs4", {
    Name = "PBS-4 Suppressor", Slot = "muzzle",
    Model = "models/weapons/sandswep/attachments/a_pbs4.mdl",
    Suppressor = true,
    Stats = { Recoil = 0.9, AimTime = 1.05 },
})

SandSwep.RegisterAttachment("muzzle_pbs1", {
    Name = "PBS-1 Suppressor", Slot = "muzzle",
    Model = "models/weapons/sandswep/attachments/a_pbs1.mdl",
    Suppressor = true,
    Stats = { Recoil = 0.9, AimTime = 1.05 },
})

SandSwep.RegisterAttachment("muzzle_comp_ar15", {
    Name = "Compensator", Slot = "muzzle",
    Model = "models/weapons/sandswep/attachments/a_comp_ar15.mdl",
    Stats = { RecoilLateral = 0.7, AimTime = 1.02 },
})

SandSwep.RegisterAttachment("muzzle_flash_ar15", {
    Name = "Flash Hider", Slot = "muzzle",
    Model = "models/weapons/sandswep/attachments/a_flash_ar15.mdl",
    FlashHider = true,
})

SandSwep.RegisterAttachment("muzzle_comp_ak74", {
    Name = "Compensator", Slot = "muzzle",
    Model = "models/weapons/sandswep/attachments/a_comp_ak74.mdl",
    Stats = { RecoilLateral = 0.7, AimTime = 1.02 },
})

SandSwep.RegisterAttachment("muzzle_flash_ak74", {
    Name = "Flash Hider", Slot = "muzzle",
    Model = "models/weapons/sandswep/attachments/a_flash_ak74.mdl",
    FlashHider = true,
})

SandSwep.RegisterAttachment("muzzle_comp_akm", {
    Name = "Compensator", Slot = "muzzle",
    Model = "models/weapons/sandswep/attachments/a_comp_akm.mdl",
    Stats = { RecoilLateral = 0.7, AimTime = 1.02 },
})

SandSwep.RegisterAttachment("muzzle_flash_akm", {
    Name = "Flash Hider", Slot = "muzzle",
    Model = "models/weapons/sandswep/attachments/a_flash_akm.mdl",
    FlashHider = true,
})

SandSwep.RegisterAttachment("muzzle_clothwrapped", {
    Name = "Cloth-Wrapped Suppressor", Slot = "muzzle",
    Model = "models/weapons/sandswep/attachments/a_clothwrapped.mdl",
    Suppressor = true,
    Stats = { Recoil = 0.88, AimTime = 1.07, AimMoveSpeed = 0.97 },
})

SandSwep.RegisterAttachment("muzzle_clothwrapped_black", {
    Name = "Cloth-Wrapped Suppressor", Slot = "muzzle",
    Model = "models/weapons/sandswep/attachments/a_clothwrapped_black.mdl",
    Suppressor = true,
    Stats = { Recoil = 0.88, AimTime = 1.07, AimMoveSpeed = 0.97 },
})

SandSwep.RegisterAttachment("muzzle_uzi_tirant", {
    Name = "TiRant 45 Suppressor", Slot = "muzzle",
    Model = "models/weapons/sandswep/attachments/a_uzi_tirant.mdl",
    Bodygroups = { barrel = 1 },
    Suppressor = true,
    Stats = { Recoil = 0.9, AimTime = 1.05 },
})

SandSwep.RegisterAttachment("muzzle_um45_flashhider", {
    Name = "UMP45 Flash Hider", Slot = "muzzle",
    MuzzleAttachment = "muzzle_flashhider",
    Bodygroups = { muzzle = 1 },
    Stats = { Recoil = 0.95 },
})

SandSwep.RegisterAttachment("muzzle_um45_suppressor", {
    Name = "UMP45 Suppressor", Slot = "muzzle",
    MuzzleAttachment = "muzzle_suppressed",
    Bodygroups = { muzzle = 2 },
    Suppressor = true,
    Stats = { Recoil = 0.9, AimTime = 1.05 },
})

SandSwep.RegisterAttachment("muzzle_mp7_comp", {
    Name = "MP7 Compensator", Slot = "muzzle",
    MuzzleAttachment = "muzzle_comp",
    Bodygroups = { muzzle = 1 },
    Stats = { RecoilLateral = 0.7, AimTime = 1.02 },
})

SandSwep.RegisterAttachment("muzzle_mp7_flash", {
    Name = "MP7 Flash Hider", Slot = "muzzle",
    MuzzleAttachment = "muzzle_flash",
    Bodygroups = { muzzle = 2 },
    FlashHider = true,
})

SandSwep.RegisterAttachment("muzzle_mp7_tirant", {
    Name = "TiRant Suppressor", Slot = "muzzle",
    MuzzleAttachment = "muzzle_supp",
    Bodygroups = { muzzle = 3 },
    Suppressor = true,
    Stats = { Recoil = 0.9, AimTime = 1.05 },
})

SandSwep.RegisterAttachment("muzzle_p90_suppressor", {
    Name = "P90 Suppressor", Slot = "muzzle",
    MuzzleAttachment = "muzzle_supp",
    Bodygroups = { muzzle = 1 },
    Suppressor = true,
    Stats = { Recoil = 0.9, AimTime = 1.05 },
})

SandSwep.RegisterAttachment("muzzle_vector_suppressor", {
    Name = "Vector Suppressor", Slot = "muzzle",
    MuzzleAttachment = "muzzle_supp",
    Bodygroups = { muzzle = 1 },
    Suppressor = true,
    Stats = { Recoil = 0.9, AimTime = 1.05 },
})

SandSwep.RegisterAttachment("muzzle_mp40_ins9mm", {
    Name = "9mm Suppressor", Slot = "muzzle",
    MuzzleAttachment = "muzzle_supp",
    Bodygroups = { muzzle = 1 },
    Suppressor = true,
    Stats = { Recoil = 0.9, AimTime = 1.05 },
})

SandSwep.RegisterAttachment("muzzle_sterling_l34", {
    Name = "L34A1 Suppressor", Slot = "muzzle",
    MuzzleAttachment = "muzzle_supp",
    Bodygroups = { muzzle = 1 },
    Suppressor = true,
    Stats = { Recoil = 0.85, AimTime = 1.06 },
})

SandSwep.RegisterAttachment("muzzle_greasegun_flash", {
    Name = "M3 Flash Hider", Slot = "muzzle",
    MuzzleAttachment = "muzzle_flash",
    Bodygroups = { muzzle = 1 },
    FlashHider = true,
})

SandSwep.RegisterAttachment("muzzle_greasegun_suppressor", {
    Name = "M3 Integral Suppressor", Slot = "muzzle",
    MuzzleAttachment = "muzzle_supp",
    Bodygroups = { muzzle = 2, barrel = 1 },
    Suppressor = true,
    Stats = { Recoil = 0.88, AimTime = 1.06 },
})

SandSwep.RegisterAttachment("muzzle_greasegun_suppressor_adv", {
    Name = "M3 Suppressor", Slot = "muzzle",
    MuzzleAttachment = "muzzle_suppadv",
    Bodygroups = { muzzle = 3 },
    Suppressor = true,
    Stats = { Recoil = 0.9, AimTime = 1.05 },
})

SandSwep.RegisterAttachment("muzzle_mp5a2_sec9mm", {
    Name = "9mm Suppressor", Slot = "muzzle",
    MuzzleAttachment = "muzzle_supp",
    Bodygroups = { muzzle = 1 },
    Suppressor = true,
    Stats = { Recoil = 0.9, AimTime = 1.05 },
})

SandSwep.RegisterAttachment("muzzle_mp5a5_sd", {
    Name = "MP5SD Suppressor", Slot = "muzzle",
    MuzzleAttachment = "muzzle_supp",
    Bodygroups = { muzzle = 2 },
    Suppressor = true,
    Stats = { Recoil = 0.9, AimTime = 1.05 },
})

-- Iron sights / gun parts

SandSwep.RegisterAttachment("sight_carryhandle", {
    Name = "Carry Handle", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_carryhandle.mdl",
})

-- Magazines
SandSwep.RegisterAttachment("mag_40", {
    Name = "35rd Magazine", Slot = "magazine",
    Bodygroups = { mag = 1 },
    MagSize = 35,
    AnimSet = "magext",
    Stats = { AimTime = 1.04 },
})

SandSwep.RegisterAttachment("mag_drum", {
    Name = "50rd Drum", Slot = "magazine",
    Bodygroups = { mag = 2 },
    MagSize = 50,
    AnimSet = "drum",
    SoundSuffix = "drum",
    Stats = { AimTime = 1.12, AimMoveSpeed = 0.95 },
})

SandSwep.RegisterAttachment("mag_uzi_32", {
    Name = "32rd Magazine", Slot = "magazine",
    Bodygroups = { mag = 1 },
    MagSize = 32,
    Stats = { AimTime = 1.04 },
})

SandSwep.RegisterAttachment("cosmetic_tourniquet", {
    Name = "Tourniquet", Slot = "cosmetic",
    Bodygroups = { tourniquet = 1 },
})

SandSwep.RegisterAttachment("mag_mp7_40", {
    Name = "40rd Magazine", Slot = "magazine",
    Bodygroups = { mag = 1 },
    MagSize = 40,
    AnimSet = "magext",
    Stats = { AimTime = 1.04 },
})

SandSwep.RegisterAttachment("mag_vector_30", {
    Name = "30rd Magazine", Slot = "magazine",
    Bodygroups = { mag = 1 },
    MagSize = 30,
    Stats = { AimTime = 1.02 },
})

SandSwep.RegisterAttachment("mag_sterling_50", {
    Name = "50rd Magazine", Slot = "magazine",
    Bodygroups = { mag = 1 },
    MagSize = 50,
    AnimSet = "magext",
    Stats = { AimTime = 1.06 },
})

SandSwep.RegisterAttachment("mag_mp5_40", {
    Name = "40rd Magazine", Slot = "magazine",
    Bodygroups = { mag = 1 },
    MagSize = 40,
    Stats = { AimTime = 1.04 },
})

SandSwep.RegisterAttachment("mag_m240_100", {
    Name = "100rd Box", Slot = "magazine",
    Bodygroups = { Mag = 1, Mag_Attach = 1 },
    MagSize = 100,
    AnimSet = "m240box",
    Stats = { AimTime = 1.08, AimMoveSpeed = 0.95 },
})

SandSwep.RegisterAttachment("mag_m99_10", {
    Name = "10rd Magazine", Slot = "magazine",
    Bodygroups = { Mag = 1 },
    MagSize = 10,
    AnimSet = "m99ext",
    Stats = { AimTime = 1.05 },
})

SandSwep.RegisterAttachment("bipod_mosin_harris", {
    Name = "Harris Bipod", Slot = "underbarrel",
    Bodygroups = { bipod = 1 },
    Stats = { AimTime = 1.06, AimMoveSpeed = 0.96 },
})

SandSwep.RegisterAttachment("mag_mosin_clips", {
    Name = "Stripper Clips", Slot = "magazine",
})

SandSwep.RegisterAttachment("mag_m82_10", {
    Name = "10rd Magazine", Slot = "magazine",
    Bodygroups = { Mag = 1 },
    MagSize = 10,
    AnimSet = "m82ext",
    Stats = { AimTime = 1.05 },
})

SandSwep.RegisterAttachment("bipod_l96a1", {
    Name = "L96A1 Bipod", Slot = "underbarrel",
    Bodygroups = { bipod = 1 },
    Stats = { AimTime = 1.06, AimMoveSpeed = 0.96 },
})

SandSwep.RegisterAttachment("mag_l96a1_10", {
    Name = "10rd Magazine", Slot = "magazine",
    Bodygroups = { mag = 1 },
    MagSize = 10,
    Stats = { AimTime = 1.05 },
})

SandSwep.RegisterAttachment("bipod_m24_harris", {
    Name = "Harris Bipod", Slot = "underbarrel",
    Bodygroups = { bipod = 1 },
    Stats = { AimTime = 1.06, AimMoveSpeed = 0.96 },
})

SandSwep.RegisterAttachment("mag_m110_20", {
    Name = "20rd Magazine", Slot = "magazine",
    Bodygroups = { mag = 1 },
    MagSize = 20,
    AnimSet = "m110mag20",
    Stats = { AimTime = 1.05 },
})

SandSwep.RegisterAttachment("muzzle_m110_supp", {
    Name = "KAC Suppressor", Slot = "muzzle",
    MuzzleAttachment = "muzzle_suppressed",
    Bodygroups = { muzzle = 1 },
    Suppressor = true,
    Stats = { Recoil = 0.88, AimTime = 1.06 },
})

SandSwep.RegisterAttachment("optic_m110scope", {
    Name = "M110 Scope (3.5-10x)", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_m110scope.mdl",
    Bodygroups = { sights = 1 },
    SightPose = "m110scope",
    Sights = {
        { Name = "MK4 3.5X", Zoom = 1.1, SwitchSound = "SandSwep.ElcanLever",
          Lens = { Z = -4.961, Attachment = "lens", Radius = 0.53 },
          PIP = { Magnification = 3.5 },
          Reticle = { Texture = RET .. "m110mk4", FillLens = true },
          Toggle = { Anim = "mk4_out", Commit = 22 / 30, Sounds = { { t = 22 / 30, s = "SandSwep.SS.ToggleScope_Zoom_Out" } } } },
        { Name = "MK4 10X", Zoom = 1.1, SwitchSound = "SandSwep.ElcanLever",
          Lens = { Z = -4.961, Attachment = "lens", Radius = 0.53 },
          PIP = { Magnification = 10 },
          Reticle = { Texture = RET .. "m110mk4", FillLens = true },
          Sensitivity = 0.5,     -- slower mouse at 10x
          Toggle = { Anim = "mk4_in", Commit = 27 / 30, Sounds = { { t = 27 / 30, s = "SandSwep.SS.ToggleScope_Zoom_In" } } } },
    },
    Stats = { AimTime = 1.2, AimMoveSpeed = 0.93 },
})

SandSwep.RegisterAttachment("mag_uzi_50", {
    Name = "50rd Drum", Slot = "magazine",
    Bodygroups = { mag = 2 },
    MagSize = 50,
    AnimSet = "uzidrum",
    SoundSuffix = "drum",
    Stats = { AimTime = 1.1, AimMoveSpeed = 0.95 },
})

SandSwep.RegisterAttachment("mag_mg3_100", {
    Name = "100rd Belt Box", Slot = "magazine",
    Bodygroups = { Mag = 1 },
    MagSize = 100,
    AnimSet = "ext",
    Stats = { AimTime = 1.08, AimMoveSpeed = 0.95 },
})

SandSwep.RegisterAttachment("mag_m60_100", {
    Name = "100rd Belt Box", Slot = "magazine",
    Bodygroups = { Mag = 1 },
    MagSize = 100,
    AnimSet = "ext",
    Stats = { AimTime = 1.08, AimMoveSpeed = 0.95 },
})

SandSwep.RegisterAttachment("mag_m250_100", {
    Name = "100rd Belt Box", Slot = "magazine",
    Bodygroups = { Mag = 1 },
    MagSize = 100,
    AnimSet = "ext",
    Stats = { AimTime = 1.08, AimMoveSpeed = 0.95 },
})

SandSwep.RegisterAttachment("muzzle_m250_supp", {
    Name = "M250 Suppressor", Slot = "muzzle",
    Bodygroups = { muzzle = 1 },
    Suppressor = true,
    MuzzleAttachment = "muzzle_supp",
    Stats = { Recoil = 0.9, AimTime = 1.05 },
})

SandSwep.RegisterAttachment("mag_rpk_40", {
    Name = "40rd Magazine", Slot = "magazine",
    Bodygroups = { mag = 1 },
    MagSize = 40,
    Stats = { AimTime = 1.04 },
})

SandSwep.RegisterAttachment("mag_rpk_drum", {
    Name = "75rd Drum", Slot = "magazine",
    Bodygroups = { mag = 2 },
    MagSize = 75,
    AnimSet = "rpkdrum",
    SoundSuffix = "drum",
    Stats = { AimTime = 1.12, AimMoveSpeed = 0.93 },
})

SandSwep.RegisterAttachment("grip_vertical_vhs", {
    Name = "Vertical Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_vertgrip.mdl",
    Bodygroups = { rail = 1 },
    PoseParams = { foregrip = 1 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.9, AimTime = 1.03 },
})

-- Underbarrel

SandSwep.RegisterAttachment("ugl_m203", {
    Name = "M203 Grenade Launcher", Slot = "underbarrel", GLName = "M203",
    Bodygroups = { gl = 1, cover_l = 1 },
    AnimSet = "gl",
    GL = { StartAmmo = 3 },
    Stats = { AimTime = 1.12, AimMoveSpeed = 0.94, Recoil = 0.92 },
})

SandSwep.RegisterAttachment("grip_ak_romanian", {
    Name = "Romanian Foregrip", Slot = "underbarrel",
    Bodygroups = { handguard = 1 },
    PoseParams = { foregrip = 1 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.9, AimTime = 1.03 },
})

SandSwep.RegisterAttachment("grip_vertical", {
    Name = "Vertical Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_vertgrip.mdl",
    PoseParams = { foregrip = 1 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.9, AimTime = 1.03 },
})

SandSwep.RegisterAttachment("grip_vertical_rail", {
    Name = "Vertical Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_vertgrip_rail.mdl",
    PoseParams = { foregrip = 1 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.9, AimTime = 1.03 },
})

SandSwep.RegisterAttachment("grip_vertical_famas", {
    Name = "Vertical Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_vertgrip.mdl",
    Bodygroups = { griprail = 1 },
    PoseParams = { foregrip = 1 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.9, AimTime = 1.03 },
})

SandSwep.RegisterAttachment("grip_hb_aiming", {
    Name = "Aiming Grip", Slot = "underbarrel",
    Bodygroups = { foregrip = 2 },
    PoseParams = { foregrip = 1, griptype = 1 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.95, AimTime = 0.9 },
})
SandSwep.RegisterAttachment("grip_hb_loading", {
    Name = "Loading Grip (AFG)", Slot = "underbarrel",
    Bodygroups = { foregrip = 3 },
    PoseParams = { foregrip = 1, griptype = 2 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.94, ReloadSpeed = 1.12 },
})
SandSwep.RegisterAttachment("grip_hb_quickdraw", {
    Name = "Quickdraw Grip", Slot = "underbarrel",
    Bodygroups = { foregrip = 4 },
    PoseParams = { foregrip = 1, griptype = 3 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.94, AimTime = 0.95, AimMoveSpeed = 1.05 },
})

SandSwep.RegisterAttachment("grip_mcx_aiming", {
    Name = "Aiming Grip", Slot = "underbarrel",
    Bodygroups = { foregrip = 1 },
    PoseParams = { foregrip = 1, griptype = 1 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.95, AimTime = 0.9 },
})
SandSwep.RegisterAttachment("grip_mcx_loading", {
    Name = "Loading Grip (AFG)", Slot = "underbarrel",
    Bodygroups = { foregrip = 2 },
    PoseParams = { foregrip = 1, griptype = 2 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.94, ReloadSpeed = 1.12 },
})
SandSwep.RegisterAttachment("grip_mcx_quickdraw", {
    Name = "Quickdraw Grip", Slot = "underbarrel",
    Bodygroups = { foregrip = 3 },
    PoseParams = { foregrip = 1, griptype = 3 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.94, AimTime = 0.95, AimMoveSpeed = 1.05 },
})
SandSwep.RegisterAttachment("grip_aiming", {
    Name = "Aiming Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_fg_aiming.mdl",
    PoseParams = { foregrip = 1, griptype = 1 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.95, AimTime = 0.9 },
})
SandSwep.RegisterAttachment("grip_aiming_rail", {
    Name = "Aiming Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_fg_aimingrail.mdl",
    PoseParams = { foregrip = 1, griptype = 1 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.95, AimTime = 0.9 },
})
SandSwep.RegisterAttachment("grip_loading", {
    Name = "Loading Grip (AFG)", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_fg_loading.mdl",
    PoseParams = { foregrip = 1, griptype = 2 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.94, ReloadSpeed = 1.12 },
})
SandSwep.RegisterAttachment("grip_loading_rail", {
    Name = "Loading Grip (AFG)", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_fg_loadingrail.mdl",
    PoseParams = { foregrip = 1, griptype = 2 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.94, ReloadSpeed = 1.12 },
})
SandSwep.RegisterAttachment("grip_quickdraw", {
    Name = "Quickdraw Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_fg_quickdraw.mdl",
    PoseParams = { foregrip = 1, griptype = 3 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.94, AimTime = 0.95, AimMoveSpeed = 1.05 },
})
SandSwep.RegisterAttachment("grip_quickdraw_rail", {
    Name = "Quickdraw Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_fg_quickdrawrail.mdl",
    PoseParams = { foregrip = 1, griptype = 3 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.94, AimTime = 0.95, AimMoveSpeed = 1.05 },
})
SandSwep.RegisterAttachment("grip_pointshooting", {
    Name = "Point Shooting Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_fg_pointshooting.mdl",
    PoseParams = { foregrip = 1, griptype = 4 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.96, AimTime = 0.97 },
    Laser = true,
    BeamBone = "a_foregrip",
    BeamLocal = Vector(0.09, 2.88, -0.79),
    BeamDir = Vector(0, 1, 0),
    LaserColor = Color(255, 30, 20),
})
SandSwep.RegisterAttachment("grip_pointshooting_rail", {
    Name = "Point Shooting Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_fg_pointshootingrail.mdl",
    PoseParams = { foregrip = 1, griptype = 4 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.96, AimTime = 0.97 },
    Laser = true,
    BeamBone = "a_foregrip",
    BeamLocal = Vector(0.09, 2.88, -0.79),
    BeamDir = Vector(0, 1, 0),
    LaserColor = Color(255, 30, 20),
})
SandSwep.RegisterAttachment("grip_recoil", {
    Name = "Vertical Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_fg_recoil.mdl",
    PoseParams = { foregrip = 1, griptype = 5 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.88, AimTime = 1.03, CycleSpeed = 1.15 },
})
SandSwep.RegisterAttachment("grip_recoil_rail", {
    Name = "Vertical Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_fg_recoilrail.mdl",
    PoseParams = { foregrip = 1, griptype = 5 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.88, AimTime = 1.03, CycleSpeed = 1.15 },
})
SandSwep.RegisterAttachment("grip_recoil_small", {
    Name = "Vertical Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_fg_recoilsmall.mdl",
    PoseParams = { foregrip = 1, griptype = 5 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.88, AimTime = 1.03, CycleSpeed = 1.15 },
})
SandSwep.RegisterAttachment("grip_recoil_largerail", {
    Name = "Vertical Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_fg_recoillargerail.mdl",
    PoseParams = { foregrip = 1, griptype = 5 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.88, AimTime = 1.03, CycleSpeed = 1.15 },
})
SandSwep.RegisterAttachment("grip_vertical_fg", {
    Name = "Vertical Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_vertgrip.mdl",
    PoseParams = { foregrip = 1 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.9, AimTime = 1.03 },
})
SandSwep.RegisterAttachment("grip_vertical_fg_rail", {
    Name = "Vertical Grip", Slot = "underbarrel",
    Model = "models/weapons/sandswep/attachments/a_vertgrip_rail.mdl",
    PoseParams = { foregrip = 1 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.9, AimTime = 1.03 },
})

for _, gun in ipairs({ "akm", "akalpha" }) do
    SandSwep.RegisterAttachment("mag_" .. gun .. "_40", {
        Name = "40rd Magazine", Slot = "magazine",
        Bodygroups = { mag = 1 },
        MagSize = 40,
        Stats = { AimTime = 1.04 },
    })
    SandSwep.RegisterAttachment("mag_" .. gun .. "_drum", {
        Name = "75rd Drum", Slot = "magazine",
        Bodygroups = { mag = 2 },
        MagSize = 75,
        AnimSet = gun .. "drum",
        SoundSuffix = "drum",
        Stats = { AimTime = 1.14, AimMoveSpeed = 0.94 },
    })
end
SandSwep.RegisterAttachment("grip_akm_romanian", {
    Name = "Romanian Foregrip", Slot = "underbarrel",
    Bodygroups = { handguard = 1 },
    PoseParams = { foregrip = 1 },
    AnimSet = "foregrip",
    Stats = { Recoil = 0.9, AimTime = 1.03 },
})

SandSwep.RegisterAttachment("tac_peq15", {
    Name = "PEQ-15", Slot = "tactical",
    Model = "models/weapons/sandswep/attachments/a_peq15.mdl",
    MountBone = "a_laserflashlight",
    Rail = { Front = Vector(0, 1, 0), Out = Vector(0, 0, -1), Mount = Vector(0, 0.3, 0.0) },
    Laser = true,
    BeamLocal = Vector(0, 2.2, -0.4),
    LaserColor = Color(255, 30, 20),
})

SandSwep.RegisterAttachment("tac_laser_ras", {
    Name = "Laser", Slot = "tactical",
    Model = "models/weapons/sandswep/attachments/a_genlaser_ras.mdl",
    MountBone = "a_laserflashlight",
    Rail = { Front = Vector(0, 1, 0), Out = Vector(0, 0, -1), Mount = Vector(0, -0.035, 0.0) },
    Laser = true,
    BeamLocal = Vector(0, 1.27, -0.526),
    LaserColor = Color(255, 30, 20),
})

SandSwep.RegisterAttachment("tac_m952v", {
    Name = "M952V", Slot = "tactical",
    Model = "models/weapons/sandswep/attachments/a_sand_m952v.mdl",
    MountBone = "a_laserflashlight",
    Rail = { Front = Vector(0, 1, 0), Out = Vector(0, 0, 1), Mount = Vector(0, 0, 0) },
    Light = true,
    BeamLocal = Vector(0, 2.55, 0.97),
})

SandSwep.RegisterAttachment("tac_ak_bandlight", {
    Name = "Flashlight (Gas Block)", Slot = "tactical",
    Model = "models/weapons/sandswep/attachments/a_ak_bandlight.mdl",
    Light = true,
    Beam = "beam",
})

SandSwep.RegisterAttachment("tac_ak_bandlaser", {
    Name = "Laser (Gas Block)", Slot = "tactical",
    Model = "models/weapons/sandswep/attachments/a_ak_bandlaser.mdl",
    Laser = true,
    Beam = "beam",
    LaserColor = Color(255, 30, 20),
})

SandSwep.RegisterAttachment("tac_uzi_laser", {
    Name = "Laser", Slot = "tactical",
    Model = "models/weapons/sandswep/attachments/a_uzi_laser.mdl",
    Laser = true,
    Beam = "beam",
    LaserColor = Color(255, 30, 20),
})

SandSwep.RegisterAttachment("tac_uzi_light", {
    Name = "Flashlight", Slot = "tactical",
    Model = "models/weapons/sandswep/attachments/a_uzi_light.mdl",
    Light = true,
    Beam = "beam",
})







SandSwep.RegisterAttachment("optic_maaws_scope", {
    Name = "M3 Telescopic Sight", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_maaws_scope.mdl",
    SightPose = "maaws",
    Sights = {
        { Name = "SCOPE", Zoom = 1.1, SightPose = "maaws", Ang = Angle(8.86, -4.49, 19.27),
          Lens = { Attachment = "lens", Radius = 0.6 },
          PIP = { Magnification = 2.5 },
          Reticle = { Texture = RET .. "maaws", FillLens = true } },
    },
})

SandSwep.RegisterAttachment("optic_pzf3_scope", {
    Name = "Dynarange Sight", Slot = "optic",
    Model = "models/weapons/sandswep/attachments/a_pzf3_scope.mdl",
    SightPose = "pzf3",
    Sights = {
        { Name = "SCOPE", Zoom = 1.1, SightPose = "pzf3", Ang = Angle(11.34, -11.12, 29.66),
          Lens = { Attachment = "lens", Radius = 0.6 },
          PIP = { Magnification = 2.5 },
          Reticle = { Texture = RET .. "pzf3", FillLens = true } },
    },
})

-- Ammunition
SandSwep.RegisterAttachment("ammo_tracer", {
    Name = "Tracer Rounds", Slot = "ammo", AmmoType = true,
    TracerRounds = true,
})
