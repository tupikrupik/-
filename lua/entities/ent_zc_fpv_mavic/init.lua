AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local function payloadTransform(drone)
	local id = drone:LookupAttachment("drop")
	local att = id and id > 0 and drone:GetAttachment(id)
	if att then return att.Pos, att.Ang end
	local scale = drone.ModelScale or 1
	return drone:LocalToWorld(Vector(0, 0, -5 * scale)), drone:LocalToWorldAngles(Angle(0, 0, 90))
end

function ENT:AttachRGD(ply, wep)
	if IsValid(self.PayloadGrenade) then return false end
	self.PayloadGrenade = nil
	self:SetNWEntity("ZCFpvPayload", NULL)
	self:SetNWBool("ZCFpvRGD", false)

	local grenade = ents.Create("ent_hg_grenade_rgd5")
	if not IsValid(grenade) then return false end

	local pos, ang = payloadTransform(self)
	grenade:SetPos(pos)
	grenade:SetAngles(ang)
	grenade:SetOwner(ply)
	grenade.owner = ply
	grenade.owner2 = ply
	grenade.ZCFpvSafePayload = true
	grenade:Spawn()
	grenade:SetMoveType(MOVETYPE_NONE)
	grenade:SetSolid(SOLID_NONE)
	grenade:SetNotSolid(true)

	local id = self:LookupAttachment("drop")
	if id and id > 0 then
		grenade:SetParent(self, id)
		grenade:SetLocalPos(vector_origin)
		grenade:SetLocalAngles(angle_zero)
	else
		grenade:SetParent(self)
		grenade:SetLocalPos(Vector(0, 0, -5 * (self.ModelScale or 1)))
		grenade:SetLocalAngles(Angle(0, 0, 90))
	end

	local phys = grenade:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
		phys:Sleep()
	end

	self.PayloadGrenade = grenade
	self:SetNWEntity("ZCFpvPayload", grenade)
	self:SetNWBool("ZCFpvRGD", true)
	self:EmitSound("buttons/button17.wav", 60, 115)

	wep.count = math.max((wep.count or 1) - 1, 0)
	if wep.count < 1 then
		ply:SelectWeapon("weapon_hands_sh")
		wep:Remove()
	end

	net.Start("zc_fpv_payload_notice")
		net.WriteString("RGD-5 ATTACHED")
	net.Send(ply)
	return true
end

function ENT:ReleasePayload(ply)
	local grenade = self.PayloadGrenade
	if not IsValid(grenade) then
		self.PayloadGrenade = nil
		self:SetNWEntity("ZCFpvPayload", NULL)
		self:SetNWBool("ZCFpvRGD", false)
		return
	end

	local vel = self:GetVelocity() - self:GetUp() * 80
	grenade:SetParent(nil)
	grenade:SetNotSolid(false)
	grenade:PhysicsInit(SOLID_VPHYSICS)
	grenade:SetMoveType(MOVETYPE_VPHYSICS)
	grenade:SetSolid(SOLID_VPHYSICS)
	grenade:SetCollisionGroup(COLLISION_GROUP_NONE)

	local phys = grenade:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(true)
		phys:Wake()
		phys:SetVelocity(vel)
	end

	grenade.ZCFpvSafePayload = nil
	grenade:Arm(CurTime(), vel)
	self.PayloadGrenade = nil
	self:SetNWEntity("ZCFpvPayload", NULL)
	self:SetNWBool("ZCFpvRGD", false)
	self:EmitSound("buttons/lightswitch2.wav", 60, 120)

	net.Start("zc_fpv_payload_notice")
		net.WriteString("BOTTOM PAYLOAD RELEASED")
	net.Send(ply)
end

net.Receive("zc_fpv_attach_rgd", function(_, ply)
	local drone = net.ReadEntity()
	if not IsValid(drone) or not drone.DropPayload then return end
	if drone:GetOwner() ~= ply or ply:GetPos():DistToSqr(drone:GetPos()) > 57600 then return end

	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or wep.ENT ~= "ent_hg_grenade_rgd5" then return end
	if wep.ReadyToThrow or wep.SpoonTime or (wep.count or 1) < 1 then return end

	local tr = hg.eyeTrace(ply, 240)
	if not tr then return end
	if tr.Entity ~= drone then return end
	drone:AttachRGD(ply, wep)
end)
