AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel(self.Model)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:SetHealth(self.MaxHP)
	self:SetMaxHealth(self.MaxHP)
	self:SetNWBool("ZCFpvJammerActive", true)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(300)
		phys:Wake()
	end
end

function ENT:Use(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	if CurTime() < (self.NextUse or 0) then return end

	self.NextUse = CurTime() + 0.5
	local active = not self:GetNWBool("ZCFpvJammerActive", true)
	self:SetNWBool("ZCFpvJammerActive", active)
	self:EmitSound(active and "buttons/button14.wav" or "buttons/button19.wav", 70, active and 90 or 75)
end

function ENT:OnTakeDamage(dmg)
	self:TakePhysicsDamage(dmg)
	self:SetHealth(self:Health() - dmg:GetDamage())
	if self:Health() > 0 then return end

	local ed = EffectData()
	ed:SetOrigin(self:WorldSpaceCenter())
	ed:SetScale(1)
	util.Effect("cball_explode", ed, true, true)
	self:EmitSound("ambient/energy/zap9.wav", 85, 80)
	self:Remove()
end
