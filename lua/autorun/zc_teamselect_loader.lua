if SERVER then
	AddCSLuaFile("zcity_teamselect/cl_teamselect.lua")
	AddCSLuaFile("zcity_teamselect/sh_teamselect.lua")

	include("zcity_teamselect/sh_teamselect.lua")
	include("zcity_teamselect/init.lua")
else
	include("zcity_teamselect/sh_teamselect.lua")
	include("zcity_teamselect/cl_teamselect.lua")
end


if SERVER then
	resource.AddSingleFile("models/ru/soilder_rf_02.mdl")
	resource.AddSingleFile("models/ru/soilder_rf_02.vvd")
	resource.AddSingleFile("models/ru/soilder_rf_02.dx90.vtx")
	resource.AddSingleFile("models/ru/soilder_rf_02.dx80.vtx")
	resource.AddSingleFile("models/ru/soilder_rf_02.phy")
end
