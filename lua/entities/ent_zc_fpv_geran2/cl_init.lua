include("shared.lua")

function ENT:Think()
	local powered = self:GetPowered()
	ZCFpv.UpdateMotorSound(self)

	local ft = math.max(RealFrameTime(), 0.001)
	local ang = self:GetAngles()
	local old = self.LastAnimAng or ang
	local pitchRate = math.AngleDifference(ang.p, old.p) / ft
	local rollRate = math.AngleDifference(ang.r, old.r) / ft
	self.LastAnimAng = Angle(ang.p, ang.y, ang.r)

	self.SurfacePitch = Lerp(math.min(ft * 8, 1), self.SurfacePitch or 0, math.Clamp(pitchRate * 0.08, -30, 30))
	self.SurfaceRoll = Lerp(math.min(ft * 8, 1), self.SurfaceRoll or 0, math.Clamp(rollRate * 0.08, -30, 30))
	local rpm = self.MotorRpm or 0
	self.PropSpeed = Lerp(math.min(ft * 6, 1), self.PropSpeed or 0, (powered or rpm > 0) and (500 + rpm * 2600) or 0)
	self.PropAngle = ((self.PropAngle or 0) + self.PropSpeed * ft) % 360

	self:ManipulateBoneAngles(1, Angle(self.PropAngle, 0, 0))
	self:ManipulateBoneAngles(2, Angle(0, 0, -self.SurfacePitch))
	self:ManipulateBoneAngles(3, Angle(0, 0, self.SurfaceRoll))
	self:ManipulateBoneAngles(4, Angle(0, 0, -self.SurfaceRoll))
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
