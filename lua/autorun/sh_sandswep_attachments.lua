AddCSLuaFile()
AddCSLuaFile("sandswep_base/ui/cl_ui.lua")
AddCSLuaFile("sandswep_base/attachments/sh_core.lua")
AddCSLuaFile("sandswep_base/attachments/sh_definitions.lua")
AddCSLuaFile("sandswep_base/attachments/sh_tactical.lua")
AddCSLuaFile("sandswep_base/attachments/cl_menu_style.lua")
AddCSLuaFile("sandswep_base/attachments/cl_presets.lua")
AddCSLuaFile("sandswep_base/attachments/cl_preview.lua")
AddCSLuaFile("sandswep_base/attachments/cl_menu_slots.lua")
AddCSLuaFile("sandswep_base/attachments/cl_menu.lua")
AddCSLuaFile("sandswep_base/attachments/cl_lasers.lua")

include("sandswep_base/attachments/sh_core.lua")
include("sandswep_base/attachments/sh_definitions.lua")
if SERVER then include("sandswep_base/attachments/sv_attachments.lua") end
include("sandswep_base/attachments/sh_tactical.lua")

if SERVER then return end

include("sandswep_base/attachments/cl_menu_style.lua")
include("sandswep_base/attachments/cl_presets.lua")
include("sandswep_base/attachments/cl_preview.lua")
include("sandswep_base/attachments/cl_menu_slots.lua")
include("sandswep_base/attachments/cl_menu.lua")
include("sandswep_base/attachments/cl_lasers.lua")
