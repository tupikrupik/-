local frame

local function CreateTeamCard(parent, teamId, teamData, x, y, w, h)
	local card = vgui.Create("DPanel", parent)
	card:SetPos(x, y)
	card:SetSize(w, h)
	card.TeamId = teamId
	card.TeamData = teamData
	card.HoverAlpha = 0
	card:SetCursor("hand")

	local model = vgui.Create("DModelPanel", card)
	model:Dock(FILL)
	model:SetMouseInputEnabled(false)
	model:SetModel(teamData.model)
	model:SetFOV(38)
	model:SetCamPos(Vector(85, 0, 52))
	model:SetLookAt(Vector(0, 0, 38))
	model:SetDirectionalLight(BOX_RIGHT, Color(255, 255, 255))
	model:SetDirectionalLight(BOX_LEFT, Color(120, 160, 255))
	model:SetAmbientLight(Vector(-30, -30, -30))
	model:SetAnimated(true)
	model.RotY = 30

	local ent = model:GetEntity()
	if IsValid(ent) then
		if teamId == 1 then
			ent:SetBodygroup(ent:FindBodygroupByName("vest") or 0, 2)
		elseif teamId == 2 then
			ent:SetSkin(2)
			timer.Simple(0, function()
				if IsValid(ent) then ent:SetSkin(1) end
			end)
		end
	end
	if IsValid(ent) then
		local idle = ent:LookupSequence("idle_all_01")
		if not idle or idle <= 0 then idle = ent:LookupSequence("idle") end
		if idle and idle > 0 then
			ent:ResetSequence(idle)
			model.IdleSequence = idle
		end
	end

	model.LayoutEntity = function(self, e)
		local target = card:IsHovered() and 12 or 30
		self.RotY = math.Approach(self.RotY, target + math.sin(CurTime() * 0.6) * 5, FrameTime() * 35)
		e:SetAngles(Angle(0, self.RotY, 0))
		self:RunAnimation()
	end

	function card:Think()
		self.HoverAlpha = math.Approach(self.HoverAlpha or 0, self:IsHovered() and 1 or 0, FrameTime() * 6)
	end

	function card:Paint(w, h)
		local glow = self.HoverAlpha or 0
		local scale = 1 + glow * 0.06
		local dw, dh = w * scale, h * scale
		local ox, oy = -(dw - w) * 0.5, -(dh - h) * 0.5
		local accent = self.TeamData.color

		surface.SetDrawColor(217, 217, 217, 51)
		surface.DrawRect(ox, oy, dw, dh)

		if glow > 0 then
			surface.SetDrawColor(accent.r, accent.g, accent.b, math.floor(45 * glow))
			surface.DrawRect(ox, oy, dw, dh)
		end

		local r, g, b = accent.r, accent.g, accent.b
		if self.TeamId == 2 then
			r, g, b = 238, 255, 0
		end

		surface.SetDrawColor(r, g, b, 255)
		surface.DrawOutlinedRect(ox, oy, dw, dh, 2)

		if glow > 0 then
			surface.SetDrawColor(r, g, b, math.floor(150 * glow))
			surface.DrawOutlinedRect(ox + 2, oy + 2, dw - 4, dh - 4, 2)
		end

		local nameY
		if self.TeamId == 1 then
			nameY = h - 34
		else
			nameY = 34
		end

		draw.SimpleText(self.TeamData.name:upper(), "ZC_TeamSelectName", w / 2, nameY, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	function card:OnMousePressed(code)
		if code ~= MOUSE_LEFT then return end

		surface.PlaySound("buttons/button14.wav")

		net.Start("ZC_TeamSelect")
			net.WriteInt(self.TeamId, 8)
		net.SendToServer()

		if IsValid(frame) then
			frame:Remove()
			frame = nil
		end
	end

	return card
end

local function CreateTeamMenu()
	if IsValid(frame) then frame:Remove() end

	surface.CreateFont("ZC_TeamSelectName", {font = "DISKET MONO", size = ScreenScale(13), weight = 700, antialias = true})
	surface.CreateFont("ZC_TeamSelectSub", {font = "DISKET MONO", size = ScreenScale(7), weight = 500, antialias = true})
	surface.CreateFont("ZC_TeamSelectHUD", {font = "DISKET MONO", size = ScreenScale(16), weight = 800, antialias = true})
	surface.CreateFont("ZC_TeamSelectHUDSub", {font = "DISKET MONO", size = ScreenScale(7), weight = 500, antialias = true})

	frame = vgui.Create("DFrame")
	frame:SetSize(ScrW(), ScrH())
	frame:Center()
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:SetDraggable(false)
	frame:MakePopup()
	frame:SetDeleteOnClose(true)

	function frame:Paint(w, h)
		local grad = Material("gui/gradient_down")
		surface.SetMaterial(grad)
		surface.SetDrawColor(21, 81, 233, 92)
		surface.DrawTexturedRect(0, 0, w, h)
		surface.SetDrawColor(12, 46, 131, 92)
		surface.DrawTexturedRect(0, 0, w, h)
	end

	local panelW = ScrW() * 0.195
	local panelH = ScrH() * 0.755
	local panelY = ScrH() * 0.108
	local leftX = ScrW() / 2 - panelW - ScrW() * 0.021
	local rightX = ScrW() / 2 + ScrW() * 0.021

	CreateTeamCard(frame, 1, ZCTeams.Teams[1], leftX, panelY, panelW, panelH)
	CreateTeamCard(frame, 2, ZCTeams.Teams[2], rightX, panelY, panelW, panelH)
end

net.Receive("ZC_TeamSelectOpen", function()
	CreateTeamMenu()
end)

net.Receive("ZC_TeamSelect", function()
	local teamId = net.ReadInt(8)
	local teamData = ZCTeams.Teams[teamId]

	if not teamData then return end

	local lply = LocalPlayer()
	if not IsValid(lply) then return end

	lply.ZCTeamSelected = teamId

	chat.AddText(teamData.color, "Ты вступил в ряды " .. teamData.name .. "!")
end)

concommand.Add("team_select", function()
	CreateTeamMenu()
end)
