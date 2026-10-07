	AddCSLuaFile("cl_teamselect.lua")
	AddCSLuaFile("sh_teamselect.lua")

	include("sh_teamselect.lua")

	util.AddNetworkString("ZC_TeamSelect")
	util.AddNetworkString("ZCTeamSelectOpen")

	local function GetTeamSpawn(teamId)
		local pointGroup = "Team" .. teamId
		local points = zb.GetMapPoints(pointGroup)
		if not points or #points == 0 then return nil end

		local point = points[math.random(#points)]
		return point.pos, point.ang
	end

	local function ApplyTeam(ply, teamId)
		if not IsValid(ply) or not ply:IsPlayer() then return end
		teamId = tonumber(teamId) or 1

		local teamData = ZCTeams.Teams[teamId]
		if not teamData then return end

		if ply.ZCTeamSelected == teamId then return end
		ply.ZCTeamSelected = teamId

		local count = 0
		for _, p in ipairs(player.GetAll()) do
			if IsValid(p) and p.ZCTeamSelected == teamId then
				count = count + 1
			end
		end

		ply:SetTeam(teamId)
		ply:SetModel(teamData.model)
		ply:SetPlayerColor(teamData.color:ToVector())
		ply:SetNWVector("PlayerColor", teamData.color:ToVector())
		ply:SetNWString("PlayerName", teamData.name)
		ply:SetNWInt("ZCTeam", teamId)

		net.Start("ZC_TeamSelect")
			net.WriteInt(teamId, 8)
		net.Send(ply)

		PrintMessage(HUD_PRINTTALK, ply:Nick() .. " joined " .. teamData.name .. " (" .. count .. ")")

		local spawn, ang = GetTeamSpawn(teamId)
		if spawn then
			ply:SetPos(spawn + Vector(0, 0, 8))
			if ang then ply:SetEyeAngles(ang) end
		end
	end

	net.Receive("ZC_TeamSelect", function(len, ply)
		local teamId = net.ReadInt(8)
		ApplyTeam(ply, teamId)
	end)

	hook.Add("PlayerInitialSpawn", "ZCTeamSelectInit", function(ply)
		timer.Simple(0.5, function()
			if not IsValid(ply) then return end

			net.Start("ZC_TeamSelectOpen")
				net.WriteBool(not ply.ZCTeamSelected)
			net.Send(ply)
		end)
	end)

	hook.Add("PlayerSpawn", "ZCTeamSelectModel", function(ply)
		if not IsValid(ply) then return end

		local teamId = ply.ZCTeamSelected
		if not teamId then return end

		local teamData = ZCTeams.Teams[teamId]
		if not teamData then return end

		ply:SetTeam(teamId)
		ply:SetModel(teamData.model)
		ply:SetPlayerColor(teamData.color:ToVector())
		ply:SetNWVector("PlayerColor", teamData.color:ToVector())
		ply:SetNWString("PlayerName", teamData.name)
		ply:SetNWInt("ZCTeam", teamId)

		local spawn, ang = GetTeamSpawn(teamId)
		if spawn then
			ply:SetPos(spawn + Vector(0, 0, 8))
			if ang then ply:SetEyeAngles(ang) end
		end
	end)

	concommand.Add("zc_teamselect", function(ply)
		if not IsValid(ply) then return end

		net.Start("ZC_TeamSelectOpen")
			net.WriteBool(true)
		net.Send(ply)
	end)

	hook.Add("HG_PlayerSay", "ZCTeamSelectChat", function(ply, txtTbl, text)
		if text and string.lower(text) == "!team" then
			txtTbl[1] = ""

			net.Start("ZCTeamSelectOpen")
				net.WriteBool(true)
			net.Send(ply)
		end
	end)

