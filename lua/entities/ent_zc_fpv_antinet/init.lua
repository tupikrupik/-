AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel(self.Model)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetTrigger(true)
	self:SetHealth(self.MaxHP)
	self:SetMaxHealth(self.MaxHP)
	self.TrappedDrones = {}

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(false) end
end

function ENT:ReleaseDrone(drone)
	if not IsValid(drone) or drone.ZCFpvNetOwner ~= self then return end

	self.TrappedDrones[drone] = nil
	drone.ZCFpvNetOwner = nil
	drone.ZCFpvNetTrapped = nil
	drone:SetNWBool("ZCFpvNetTrapped", false)
	drone:SetCollisionGroup(COLLISION_GROUP_NONE)

	if drone.Dead then return end
	drone:StartMotionController()
	local phys = drone:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(true)
		phys:Wake()
	end
end

function ENT:TrapDrone(drone)
	local ctl = drone:GetController()
	if IsValid(ctl) then ZCFpv.StopControl(ctl) end

	drone:SetPower(false)
	drone.ZCFpvNetTrapped = true
	drone.ZCFpvNetOwner = self
	drone:SetNWBool("ZCFpvNetTrapped", true)
	drone:SetCollisionGroup(COLLISION_GROUP_WORLD)
	drone:StopMotionController()
	self.TrappedDrones[drone] = true

	local phys = drone:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetVelocity(vector_origin)
		phys:AddAngleVelocity(-phys:GetAngleVelocity())
		phys:EnableMotion(false)
	end

	drone:EmitSound("physics/metal/metal_electro2.wav", 80, 100)
end

function ENT:ExplodeDrone(drone)
	if drone.Strike then
		drone:Detonate()
		return
	end
	if not drone:HgBoom("Normal", 30, 8) then
		drone:Break(true)
	end
end

function ENT:CatchDrone(drone)
	if not ZCFpv.IsDrone(drone) or drone.Dead or drone.CatapultMounted then return end
	if drone.ZCFpvNetTrapped or CurTime() < (drone.NextZCFpvNetHit or 0) then return end

	drone.NextZCFpvNetHit = CurTime() + 0.5
	if math.Rand(0, 1) <= 0.2 then
		self:ExplodeDrone(drone)
	else
		self:TrapDrone(drone)
	end
end

function ENT:Touch(ent)
	if not ZCFpv.IsDrone(ent) or not ent:GetPowered() then return end

	timer.Simple(0, function()
		if not IsValid(self) or not IsValid(ent) or not ent:GetPowered() then return end
		self:CatchDrone(ent)
	end)
end

function ENT:OnTakeDamage(dmg)
	self:SetHealth(self:Health() - dmg:GetDamage())
	if self:Health() <= 0 then self:Remove() end
end

function ENT:OnRemove()
	for drone in pairs(self.TrappedDrones or {}) do
		self:ReleaseDrone(drone)
	end
end

hook.Add("PhysgunPickup", "ZCFpv_AntiNetRelease", function(_, ent)
	if not ent.ZCFpvNetTrapped or not IsValid(ent.ZCFpvNetOwner) then return end
	ent.ZCFpvNetOwner:ReleaseDrone(ent)
end)
