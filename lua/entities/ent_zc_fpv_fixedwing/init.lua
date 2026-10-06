AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

DEFINE_BASECLASS("ent_zc_fpv_base")

function ENT:Initialize()
	BaseClass.Initialize(self)
	self:SetHover(false)

	local phys = self:GetPhysicsObject()
	if not IsValid(phys) then return end
	phys:SetAngleDragCoefficient(1)
	phys:SetDamping(0.15, 0.3)
end

function ENT:SetPower(on)
	on = on and true or false
	if self:GetPowered() == on then return end

	self:SetPowered(on)
	self:SetHover(false)
	self:SetSignal(on and 1 or 0)
	self.TargetAng = self:GetAngles()
	self.LastImpactPos = self:GetPos()

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:Wake() end

	if not on and self:GetLinked() then
		local ply = self:GetController()
		if IsValid(ply) then ZCFpv.StopControl(ply) end
	end
end

function ENT:CheckPlayerImpact()
	local pos = self:GetPos()
	local old = self.LastImpactPos or pos
	self.LastImpactPos = pos
	if old:DistToSqr(pos) < 1 then return false end

	local tr = util.TraceHull({
		start = old,
		endpos = pos,
		mins = Vector(-24, -24, -12),
		maxs = Vector(24, 24, 12),
		filter = {self, self:GetOwner(), self.ViewCam},
		mask = MASK_SHOT,
		collisiongroup = COLLISION_GROUP_NONE,
	})
	if not IsValid(tr.Entity) or not tr.Entity:IsPlayer() then return false end

	self:Detonate(true)
	return true
end

function ENT:PhysicsSimulate(phys, dt)
	return ZCFpv.SimulatePlane(self, phys, dt)
end
