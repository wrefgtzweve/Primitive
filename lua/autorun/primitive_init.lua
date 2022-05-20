

----------------------------------------------------------------
g_primitive = {}
g_primitive.update_delay = SERVER and 0.015 or 0.015

if SERVER then
	AddCSLuaFile("primitive/vgui/editor.lua")
	AddCSLuaFile("primitive/shapes.lua")
	AddCSLuaFile("primitive/spawn.lua")
	AddCSLuaFile("primitive/edit.lua")

	include("primitive/shapes.lua")
	include("primitive/spawn.lua")
	include("primitive/edit.lua")
else
	include("primitive/vgui/editor.lua")
	include("primitive/shapes.lua")
	include("primitive/spawn.lua")
	include("primitive/edit.lua")
end
