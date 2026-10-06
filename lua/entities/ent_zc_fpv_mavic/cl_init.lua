include("shared.lua")

function ENT:Initialize()
	local scale = self.ModelScale or 1
	if scale == 1 then return end
	local mins = self:GetModelBounds()
	local m = Matrix()
	m:SetScale(Vector(scale, scale, scale))
	m:SetTranslation(Vector(0, 0, mins.z * (1 - scale)))
	self:EnableMatrix("RenderMultiply", m)
end

function ENT:Draw()
	self:DrawModel()
end
