include("shared.lua")

function ENT:Think()
	ZCFpv.UpdateMotorSound(self)
	if self.Stable and self:GetClass() ~= "ent_zc_fpv_mavic" then
		self:SetNextClientThink(CurTime())
		return true
	end
	local first = self.RotorBone or (self:GetClass() == "ent_zc_fpv_mavic" and 1 or 2)
	local ft = RealFrameTime()
	local rpm = self.MotorRpm or 0
	local wantRotor = (self:GetPowered() or rpm > 0) and (700 + rpm * 6400) or 0
	self.RotorSpeed = Lerp(math.min(ft * 12, 1), self.RotorSpeed or 0, wantRotor)
	self.RotorAng = ((self.RotorAng or 0) + ft * self.RotorSpeed) % 360
	local spin = self.RotorPitch and Angle(self.RotorAng, 0, 0) or Angle(0, self.RotorAng, 0)
	for bone = first, first + 3 do
		self:ManipulateBoneAngles(bone, spin)
	end
	self:InvalidateBoneCache()
	self:SetNextClientThink(CurTime())
	return true
end

function ENT:OnRemove()
	ZCFpv.StopMotorSound(self)
end

function ENT:Draw()
	self:DrawModel()
end

hook.Add("PostDrawOpaqueRenderables", "ZCFpv_ForceDrone", function()
	local ply = LocalPlayer()
	local drone = IsValid(ply) and ZCFpv.GetLinkedDrone(ply)
	if not IsValid(drone) then return end
	drone:DrawModel()
end)
