include("shared.lua")

local glow = Material("sprites/light_glow02_add")

function ENT:Draw()
	self:DrawModel()
	if not self:GetNWBool("ZCFpvJammerActive", true) then return end

	render.SetMaterial(glow)
	render.DrawSprite(self:WorldSpaceCenter() + self:GetUp() * 18, 18, 18, Color(255, 45, 25))
end
