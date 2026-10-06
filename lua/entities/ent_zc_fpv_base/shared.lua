ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "FPV Drone"
ENT.Author = "informal1337"
ENT.Category = "ZCity FPV"
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.ZCFpvDrone = true
ENT.Strike = false
ENT.DroneModel = "models/sw/avia/crocus/crocus_pg7.mdl"
ENT.IdleSound = "sw/crocus/crocus_idle.wav"
ENT.MaxHP = 5
ENT.MaxVel = 2500
ENT.Mass = 8
ENT.Thrust = 900
ENT.TurnRate = 180
ENT.HoverForce = 1.05
ENT.CollideDetonate = 200
ENT.CollideBreak = 400

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Controller")
	self:NetworkVar("Bool", 0, "Linked")
	self:NetworkVar("Bool", 1, "Hover")
	self:NetworkVar("Bool", 2, "Powered")
	self:NetworkVar("Float", 0, "Signal")
	self:NetworkVar("Float", 1, "ThrottleFrac")
end

function ENT:GetViewPosAng()
	if self.CamOffset then
		return self:LocalToWorld(self.CamOffset), self:GetAngles()
	end
	local id = self:LookupAttachment("view")
	local att = id and id > 0 and self:GetAttachment(id)
	if att then
		return att.Pos, att.Ang
	end
	return self:LocalToWorld(Vector(4, 0, 2)), self:GetAngles()
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end
