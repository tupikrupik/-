AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	local fallback = "models/props_lab/workspace002.mdl"
	self:SetModel(util.IsValidModel(self.Model) and self.Model or fallback)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:SetHealth(self.MaxHP)
	self:SetMaxHealth(self.MaxHP)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(180)
		phys:Wake()
	end
end

function ENT:Use(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	if CurTime() < (self.NextUse or 0) then return end
	self.NextUse = CurTime() + 0.5

	local linked = ZCFpv.GetLinkedDrone(ply)
	if IsValid(linked) then
		ZCFpv.StopControl(ply)
		self:EmitSound("buttons/button19.wav", 60, 90)
		return
	end

	local drone = ZCFpv.GetOwnerDrone(ply)
	if not ZCFpv.IsDrone(drone) or not drone:GetPowered() then
		self:EmitSound("buttons/button10.wav", 60, 90)
		return
	end

	if ZCFpv.StartControl(ply, drone) then
		self:EmitSound("buttons/button14.wav", 60, 110)
	else
		self:EmitSound("buttons/button10.wav", 60, 90)
	end
end

function ENT:OnTakeDamage(dmg)
	self:TakePhysicsDamage(dmg)
	self:SetHealth(self:Health() - dmg:GetDamage())
	if self:Health() <= 0 then self:Remove() end
end
