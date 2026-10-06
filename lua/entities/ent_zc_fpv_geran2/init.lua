AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:OnDetonate()
	local cfg = ZCFpv.Types and ZCFpv.Types.geran2 or {}
	if not self:HgBoom(cfg.expType, cfg.expForce, cfg.expMass) then
		self:Break(true)
	end
end
