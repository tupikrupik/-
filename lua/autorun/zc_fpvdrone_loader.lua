ZCFpv = ZCFpv or {}

if SERVER then
	AddCSLuaFile()
	AddCSLuaFile("zcity_fpvdrone/sh/sh_config.lua")
	AddCSLuaFile("zcity_fpvdrone/sh/sh_net.lua")
	AddCSLuaFile("zcity_fpvdrone/cl/cl_fpv.lua")
	AddCSLuaFile("zcity_fpvdrone/cl/cl_motor.lua")
	AddCSLuaFile("zcity_fpvdrone/cl/vhs/cl_vhs_engine.lua")
	AddCSLuaFile("zcity_fpvdrone/cl/cl_fx.lua")

	local function addTree(dir)
		local files, dirs = file.Find(dir .. "/*", "GAME")
		for _, f in ipairs(files or {}) do
			resource.AddFile(dir .. "/" .. f)
		end
		for _, d in ipairs(dirs or {}) do
			addTree(dir .. "/" .. d)
		end
	end

	addTree("models/sw/avia/crocus")
	addTree("models/sw/avia/mavic2")
	addTree("models/sw/avia/geran2")
	addTree("models/sw/avia/kvn")
	addTree("models/vt40")
	addTree("models/sw/shared")
	addTree("models/dronesrewrite/c_controller")
	addTree("models/dronesrewrite/w_controller")
	addTree("models/codeecho/yolka_interceptor")
	addTree("models/kortez")
	addTree("models/shtormer")
	addTree("materials/models/sw/avia/crocus")
	addTree("materials/models/sw/avia/mavic2")
	addTree("materials/models/sw/avia/geran2")
	addTree("materials/models/sw/avia/kvn")
	addTree("materials/models/vt40")
	addTree("materials/models/sw/shared")
	addTree("materials/models/dronesrewrite/w_controller")
	addTree("materials/models/codeecho/yolka_interceptor")
	addTree("materials/models/kortez")
	addTree("materials/models/shtormer")
	addTree("materials/codeecho/yolka_interceptor")
	addTree("materials/effects")
	addTree("materials/osd")
	addTree("resource/fonts")
	addTree("sound/sw/crocus")
	addTree("sound/sw/mavic2")
	addTree("sound/sw/geran2")
	addTree("sound/codeecho/yolka_interceptor")
	resource.AddFile("materials/entities/weapon_yolka_interceptor.png")
	for _, f in ipairs(file.Find("materials/entities/net*.png", "GAME") or {}) do
		resource.AddFile("materials/entities/" .. f)
	end

	for _, f in ipairs(file.Find("materials/entities/sw_*.png", "GAME") or {}) do
		resource.AddFile("materials/entities/" .. f)
	end
end

include("zcity_fpvdrone/sh/sh_config.lua")
include("zcity_fpvdrone/sh/sh_net.lua")

if SERVER then
	include("zcity_fpvdrone/sv/sv_flight.lua")
	include("zcity_fpvdrone/sv/sv_control.lua")
else
	include("zcity_fpvdrone/cl/vhs/cl_vhs_engine.lua")
	include("zcity_fpvdrone/cl/cl_fpv.lua")
	include("zcity_fpvdrone/cl/cl_motor.lua")
	include("zcity_fpvdrone/cl/cl_fx.lua")
end
