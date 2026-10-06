AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel(self.Model)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	local phys = self:GetPhysicsObject()
	if not IsValid(phys) then return end
	phys:SetMass(350)
	phys:EnableMotion(false)
end

function ENT:GetLaunchTransform(drone)
	local id = self:LookupAttachment("muzzle")
	local att = id and id > 0 and self:GetAttachment(id)
	if not att then return self:LocalToWorld(Vector(40, 0, 20)), self:GetAngles() end
	return att.Pos + att.Ang:Up() * (drone.CatapultPos or 5), att.Ang
end

function ENT:MountDrone(drone, ply)
	if IsValid(self.MountedDrone) or not IsValid(drone) or not drone.CatapultLaunchable then return false end
	if drone:IsPlayerHolding() then return false end

	local pos, ang = self:GetLaunchTransform(drone)
	drone:SetPower(false)
	drone.CatapultMounted = true
	drone:StopMotionController()
	drone:SetPos(pos)
	drone:SetAngles(ang)
	drone:SetOwner(ply)
	drone:SetCollisionGroup(COLLISION_GROUP_WORLD)

	local phys = drone:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetVelocity(vector_origin)
		phys:AddAngleVelocity(-phys:GetAngleVelocity())
		phys:Wake()
	end

	self.MountedDrone = drone
	self.MountOwner = ply
	self.MountWeld = constraint.Weld(drone, self, 0, 0, 0, false, false)
	self:SetNWEntity("ZCFpvMountedDrone", drone)
	self:EmitSound("physics/metal/metal_box_impact_soft2.wav", 70, 90)
	return true
end

function ENT:LoadDrone(ply)
	if IsValid(self.MountedDrone) then return false end

	local drone = ents.Create("ent_zc_fpv_geran2")
	if not IsValid(drone) then return false end

	local pos, ang = self:GetLaunchTransform(drone)
	drone:SetPos(pos)
	drone:SetAngles(ang)
	drone:SetOwner(ply)
	drone:Spawn()
	drone:Activate()

	if self:MountDrone(drone, ply) then
		ply.ZCFpvOwned = drone
		return true
	end

	drone:Remove()
	return false
end

function ENT:Launch(ply)
	local drone = self.MountedDrone
	if not IsValid(drone) then return false end
	if IsValid(self.MountOwner) and self.MountOwner ~= ply then return false end
	local pos, ang = self:GetLaunchTransform(drone)

	if IsValid(self.MountWeld) then self.MountWeld:Remove() end
	constraint.RemoveConstraints(drone, "Weld")
	self.MountWeld = nil
	self.MountedDrone = nil
	self.MountOwner = nil
	self:SetNWEntity("ZCFpvMountedDrone", NULL)

	drone:SetOwner(ply)
	ply.ZCFpvOwned = drone

	self:EmitSound("vehicles/airboat/fan_motor_start1.wav", 85, 115)

	timer.Simple(0, function()
		if not IsValid(drone) then return end

		drone.CatapultMounted = nil
		drone.LaunchSafeUntil = CurTime() + 1.25
		drone:SetPos(pos + ang:Forward() * 12)
		drone:SetAngles(ang)
		drone:SetCollisionGroup(COLLISION_GROUP_WORLD)

		local phys = drone:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(true)
			phys:Wake()
			phys:SetVelocity(vector_origin)
			phys:AddAngleVelocity(-phys:GetAngleVelocity())
		end

		drone:StartMotionController()
		drone:SetPower(true)

		if IsValid(phys) then
			phys:AddVelocity(drone:GetForward() * 1500 + drone:GetUp() * 150)
		end
	end)

	timer.Simple(1, function()
		if IsValid(drone) then drone:SetCollisionGroup(COLLISION_GROUP_NONE) end
	end)

	timer.Simple(0.2, function()
		if not IsValid(ply) or not IsValid(drone) or not ply:HasWeapon("weapon_zc_fpvcontroller") then return end
		ZCFpv.StartControl(ply, drone)
	end)
	return true
end

function ENT:Use(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	if CurTime() < (self.NextUse or 0) then return end
	self.NextUse = CurTime() + 0.75

	if IsValid(self.MountedDrone) then
		self:Launch(ply)
	else
		self:LoadDrone(ply)
	end
end

function ENT:PhysicsCollide(data)
	local drone = data.HitEntity
	if not IsValid(drone) or not drone.CatapultLaunchable then return end

	timer.Simple(0, function()
		if not IsValid(self) or not IsValid(drone) then return end
		self:MountDrone(drone, drone:GetOwner())
	end)
end

function ENT:OnRemove()
	if IsValid(self.MountWeld) then self.MountWeld:Remove() end
	if IsValid(self.MountedDrone) then self.MountedDrone:Remove() end
end
