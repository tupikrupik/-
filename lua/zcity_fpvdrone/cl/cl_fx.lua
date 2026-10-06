ZCFpv = ZCFpv or {}

CreateClientConVar("zc_fpv_vhs", "1", true, false)
CreateClientConVar("zc_fpv_vhs_comets", "1", true, false)
CreateClientConVar("zc_fpv_vhs_chroma", "1", true, false)
CreateClientConVar("zc_fpv_vhs_desat", "1", true, false)
CreateClientConVar("crocus_vhs_shake", "1", true, false)

local M_NOISE = Material("effects/fpv_noise")
local BAT_0 = Material("osd/bat_0.png", "mips smooth")
local BAT_1 = Material("osd/bat_1.png", "mips smooth")
local BAT_2 = Material("osd/bat_2.png", "mips smooth")
local BAT_3 = Material("osd/bat_3.png", "mips smooth")
local BAT_4 = Material("osd/bat_4.png", "mips smooth")
local BAT_5 = Material("osd/bat_5.png", "mips smooth")
local BAT_6 = Material("osd/bat_6.png", "mips smooth")
local FLYMN = Material("osd/flymn.png", "mips smooth")
local BAT_LOW = Material("osd/bat_low.png", "mips noclamp")
local M_CH = Material("osd/crosshair.png", "mips smooth")
local M_WIFI = Material("osd/wifi.png", "mips smooth")
local M_AIR = Material("osd/airspd.png", "mips smooth")
local M_GND = Material("osd/gndspd.png", "mips smooth")
local M_KMH = Material("osd/kmh.png", "mips smooth")
local M_MM = Material("osd/mm.png", "mips smooth")
local M_P0 = Material("osd/0p.png", "mips smooth")
local M_P1 = Material("osd/1p.png", "mips smooth")
local M_P2 = Material("osd/2p.png", "mips smooth")
local M_P3 = Material("osd/3p.png", "mips smooth")
local M_P4 = Material("osd/4p.png", "mips smooth")

local clr = Color(180, 180, 180, 255)
local COMPASS = {[0] = "N", [45] = "NE", [90] = "E", [135] = "SE", [180] = "S", [225] = "SW", [270] = "W", [315] = "NW", [360] = "N"}
local ring = {{2, 4}, {4, 2}, {4, -2}, {2, -4}, {-2, -4}, {-4, -2}, {-4, 2}, {-2, 4}}
local _pts = {{}, {}, {}, {}, {}}

surface.CreateFont("ZCFpv_Beta", {
	font = "VCR OSD Mono Cyr",
	size = 24,
	weight = 400,
	outline = true,
	antialias = false,
	scanlines = 1,
	extended = true,
})

surface.CreateFont("ZCFpv_Kvn", {
	font = "VCR OSD Mono Cyr",
	size = 34,
	weight = 500,
	antialias = false,
	extended = true,
})

surface.CreateFont("ZCFpv_KvnSm", {
	font = "VCR OSD Mono Cyr",
	size = 24,
	weight = 500,
	antialias = false,
	extended = true,
})

surface.CreateFont("ZCFpv_OSD", {
	font = "Arial",
	size = 28,
	weight = 600,
	antialias = false,
	scanlines = 1,
	extended = true,
})

surface.CreateFont("ZCFpv_OSD_Sm", {
	font = "Arial",
	size = 18,
	weight = 500,
	antialias = false,
	scanlines = 1,
	extended = true,
})

surface.CreateFont("ZCFpv_Dji", {
	font = "Segoe UI",
	size = 22,
	weight = 600,
	antialias = true,
	extended = true,
})

surface.CreateFont("ZCFpv_DjiMd", {
	font = "Segoe UI",
	size = 18,
	weight = 500,
	antialias = true,
	extended = true,
})

surface.CreateFont("ZCFpv_DjiSm", {
	font = "Segoe UI",
	size = 15,
	weight = 500,
	antialias = true,
	extended = true,
})

local vhsOn = false
local desatNext, desatEnd, desatVal = 0, 0, 1
local smoothNoise = 0
local takeOffPos
local flightStart
local vtMah = 0
local vtMahEnt
local cachedAlt = 0
local nextAltTrace = 0
local lowAltWarn = 8

local batUpperT = {0.05, 0.15, 0.30, 0.55, 0.80, 0.95}
local batUpperM = {BAT_6, BAT_5, BAT_4, BAT_3, BAT_2, BAT_1, BAT_0}
local batLowerT = {0.15, 0.30, 0.55, 0.80, 0.95}
local batLowerM = {BAT_5, BAT_4, BAT_3, BAT_2, BAT_1, BAT_0}

local function upperBat(pct)
	for i, t in ipairs(batUpperT) do
		if pct <= t then return batUpperM[i] end
	end
	return BAT_0
end

local function lowerBat(pct)
	for i, t in ipairs(batLowerT) do
		if pct <= t then return batLowerM[i] end
	end
	return BAT_0
end

local function DrawBox(x, y, w, h)
	x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(x - 1, y - 1, w + 2, h + 2)
	surface.SetDrawColor(180, 180, 180, 255)
	surface.DrawRect(x, y, w, h)
end

local function DrawOutlinedLine(x1, y1, x2, y2)
	x1, y1, x2, y2 = math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2)
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawLine(x1 - 1, y1, x2 - 1, y2)
	surface.DrawLine(x1 + 1, y1, x2 + 1, y2)
	surface.DrawLine(x1, y1 - 1, x2, y2 - 1)
	surface.DrawLine(x1, y1 + 1, x2, y2 + 1)
	surface.SetDrawColor(180, 180, 180, 255)
	surface.DrawLine(x1, y1, x2, y2)
end

local function DrawHollowPointer(x, y, side, text)
	local w = 70
	if side == "left" then
		_pts[1].x, _pts[1].y = x, y
		_pts[2].x, _pts[2].y = x + 15, y - 18
		_pts[3].x, _pts[3].y = x + w, y - 18
		_pts[4].x, _pts[4].y = x + w, y + 18
		_pts[5].x, _pts[5].y = x + 15, y + 18
	else
		_pts[1].x, _pts[1].y = x, y
		_pts[2].x, _pts[2].y = x - 15, y - 18
		_pts[3].x, _pts[3].y = x - w, y - 18
		_pts[4].x, _pts[4].y = x - w, y + 18
		_pts[5].x, _pts[5].y = x - 15, y + 18
	end
	surface.SetDrawColor(0, 0, 0, 255)
	for i = 1, 5 do
		local np = _pts[i + 1] or _pts[1]
		surface.DrawLine(_pts[i].x - 1, _pts[i].y, np.x - 1, np.y)
		surface.DrawLine(_pts[i].x + 1, _pts[i].y, np.x + 1, np.y)
		surface.DrawLine(_pts[i].x, _pts[i].y - 1, np.x, np.y - 1)
		surface.DrawLine(_pts[i].x, _pts[i].y + 1, np.x, np.y + 1)
	end
	surface.SetDrawColor(180, 180, 180, 255)
	for i = 1, 5 do
		local np = _pts[i + 1] or _pts[1]
		surface.DrawLine(_pts[i].x, _pts[i].y, np.x, np.y)
	end
	local tx = (side == "left") and (x + 42) or (x - 42)
	draw.SimpleText(text, "ZCFpv_Beta", math.floor(tx), math.floor(y), clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function DrawVerticalTape(val, x_pos, side, bottom_text, sh)
	local cy = sh * 0.5
	local pxd = 6
	local range = 25
	render.SetScissorRect(x_pos - 100, cy - 150, x_pos + 100, cy + 150, true)
	for i = math.floor(val - range), math.ceil(val + range) do
		local y = cy + (val - i) * pxd
		if i >= 0 then
			if i % 10 == 0 then
				local tx = (side == "left") and (x_pos + 12) or (x_pos - 12)
				DrawOutlinedLine(x_pos, y, tx, y)
				local txt_x = (side == "left") and (x_pos - 5) or (x_pos + 5)
				draw.SimpleText(string.format("%03d", i), "ZCFpv_Beta", txt_x, y, clr, side == "left" and 1 or 0, 1)
			elseif i % 2 == 0 then
				local tx = (side == "left") and (x_pos + 7) or (x_pos - 7)
				DrawOutlinedLine(x_pos, y, tx, y)
			end
		end
	end
	render.SetScissorRect(0, 0, 0, 0, false)
	DrawHollowPointer(side == "left" and x_pos + 12 or x_pos - 12, cy, side, string.format(side == "right" and "%04d" or "%03d", math.Round(val)))
	if bottom_text then
		draw.SimpleText(bottom_text, "ZCFpv_Beta", x_pos, cy + 170, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

local function DrawCompass(heading, cx)
	local strip_y, strip_w, pxd = 70, 420, 5
	local hw = strip_w / 2
	render.SetScissorRect(cx - hw, 0, cx + hw, strip_y + 60, true)
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(cx - hw, strip_y - 1, strip_w, 3)
	surface.SetDrawColor(180, 180, 180, 255)
	surface.DrawRect(cx - hw, strip_y, strip_w, 1)
	for i = math.floor(heading - hw / pxd), math.ceil(heading + hw / pxd) do
		local x = math.floor(cx + (i - heading) * pxd)
		local nd = i % 360
		if nd < 0 then nd = nd + 360 end
		local th = (i % 15 == 0) and 12 or ((i % 5 == 0) and 7 or 4)
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(x - 1, strip_y - th - 1, 3, th + 2)
		surface.SetDrawColor(180, 180, 180, 255)
		surface.DrawRect(x, strip_y - th, 1, th)
		if COMPASS[nd] and i % 45 == 0 then
			draw.SimpleText(COMPASS[nd], "ZCFpv_Beta", x, strip_y - 14, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		end
	end
	render.SetScissorRect(0, 0, 0, 0, false)
	draw.SimpleText(string.format("%03d", math.Round(heading)), "ZCFpv_Beta", cx, strip_y + 5, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

local function updateAltitude(pos, drone)
	local ct = CurTime()
	if ct >= nextAltTrace then
		nextAltTrace = ct + 0.1
		local tr = util.TraceLine({start = pos, endpos = pos - Vector(0, 0, 50000), filter = drone})
		cachedAlt = (pos.z - tr.HitPos.z) / 39.37
	end
	return cachedAlt
end

local function updateNoise(sig, jam)
	local lose = 1 - sig
	local target = (lose * lose) * 220 + lose * 80 + (jam or 0) ^ 2 * 180
	if sig < 0.12 then target = math.max(target, 200 + (0.12 - sig) * 900) end
	if sig < 0.06 then target = math.min(255, 240 + math.sin(CurTime() * 18) * 15) end
	smoothNoise = Lerp(FrameTime() * 3, smoothNoise, math.Clamp(target, 0, 255))
	return smoothNoise
end

local function DrawBetaflight(drone, sw, sh, cx, cy, sig)
	local pos = drone:GetPos()
	local ang = drone:GetAngles()
	local ct = CurTime()
	if not takeOffPos then takeOffPos = pos end
	if not flightStart then flightStart = ct end

	local altitude = updateAltitude(pos, drone)
	local speed = drone:GetVelocity():Length() * 0.09144
	local fTime = ct - flightStart

	-- horizon dashes
	local roll = math.Clamp(ang.r, -60, 60)
	for side = -1, 1, 2 do
		for d = 1, 5 do
			local pX = cx + (side * (100 + (d - 1) * 28))
			if side == -1 then pX = pX - 8 end
			local pY = math.Clamp(cy + (side * ((d / 5) * (roll * 4))), 150, sh - 150)
			DrawBox(pX, pY, 8, 2)
		end
	end

	DrawVerticalTape(speed, cx - 350, "left", "KM/H", sh)
	DrawVerticalTape(altitude, cx + 350, "right", "M", sh)
	DrawCompass((-ang.y + 90) % 360, cx)

	-- crosshair dots
	DrawBox(cx - 1, cy - 1, 2, 2)
	for _, p in ipairs(ring) do
		DrawBox(cx + p[1] - 1, cy + p[2] - 1, 2, 2)
	end
	for i = 1, 2 do
		local gap = 14 + (i - 1) * 10
		DrawBox(cx + gap, cy - 1, 5, 2)
		DrawBox(cx - gap - 5, cy - 1, 5, 2)
		DrawBox(cx - 1, cy + gap, 2, 5)
		DrawBox(cx - 1, cy - gap - 5, 2, 5)
	end

	local distHome = math.Round(pos:Distance(takeOffPos) / 39.37)
	draw.SimpleText(string.format("%03dM", distHome), "ZCFpv_Beta", 50, 50, clr, 0)

	local acroY = sh - 110
	local fps = math.Round(1 / math.max(RealFrameTime(), 0.001))
	draw.SimpleText(drone:GetHover() and "ANGLE" or "ACRO", "ZCFpv_Beta", cx - 45, acroY, clr, TEXT_ALIGN_CENTER)
	draw.SimpleText("FPS " .. fps, "ZCFpv_Beta", cx - 45, acroY + 25, clr, TEXT_ALIGN_CENTER)

	local bars = (sig > 0.7 and 3) or (sig > 0.35 and 2) or 1
	for i = 1, 3 do
		local h = 16 - (i - 1) * 5
		local sx = cx + 8 + i * 9
		local by = acroY + 24 - h
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(sx - 1, by - 1, 5, h + 2)
		local v = (i <= bars) and 180 or 30
		surface.SetDrawColor(v, v, v, 255)
		surface.DrawRect(sx, by, 3, h)
	end

	local pct = math.Clamp(0.45 + sig * 0.5, 0.08, 1)
	local throttle = math.Clamp(drone:GetVelocity():Length() / (drone.MaxVel or 2500), 0, 1)
	local volts = math.max(0, (13.5 + 3 * pct) - throttle * 1.5)
	local bx, by = 60, sh - 280

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(upperBat(pct))
	surface.DrawTexturedRect(bx, by, 40, 70)
	draw.SimpleText(string.format("%.2fV", volts / 4), "ZCFpv_Beta", bx + 55, by + 18, clr)

	surface.SetMaterial(lowerBat(pct))
	surface.DrawTexturedRect(bx, by + 90, 40, 70)
	draw.SimpleText(string.format("%.1fV", volts), "ZCFpv_Beta", bx + 55, by + 108, clr)
	draw.SimpleText(string.format("%.0f MAH", 800 + pct * 700), "ZCFpv_Beta", bx, by + 175, clr)

	local trX = sw - 50
	draw.SimpleText(string.format("%+d P", math.Round(ang.p)), "ZCFpv_Beta", trX, 50, clr, 2)
	draw.SimpleText(string.format("%+d R", math.Round(ang.r)), "ZCFpv_Beta", trX, 80, clr, 2)

	local brX, brY = sw - 50, sh - 150
	draw.SimpleText(string.format("%+d M/S", math.Round(drone:GetVelocity().z / 39.37)), "ZCFpv_Beta", brX, brY, clr, 2)
	draw.SimpleText(string.format("U %.1fV", volts), "ZCFpv_Beta", brX, brY + 35, clr, 2)
	draw.SimpleText(string.format("%d:%02d", math.floor(fTime / 60), math.floor(fTime % 60)), "ZCFpv_Beta", brX, brY + 70, clr, 2)

	surface.SetMaterial(FLYMN)
	surface.SetDrawColor(180, 180, 180, 255)
	surface.DrawTexturedRect(brX - 65, brY + 68, 26, 26)

	if pct < 0.33 and math.sin(ct * 10) > 0 then
		surface.SetMaterial(BAT_LOW)
		surface.SetDrawColor(180, 180, 180, 255)
		local th = 32
		local tw = (BAT_LOW:Width() / math.max(BAT_LOW:Height(), 1)) * th
		surface.DrawTexturedRect(math.floor(cx - tw * 0.5), math.floor(cy + 85), tw, th)
	end

	draw.SimpleText("HEALTH " .. math.max(0, math.Round(drone:Health())), "ZCFpv_Beta", 50, sh - 40, clr, 0)
	draw.SimpleText(string.format("km/h %d", math.Round(speed)), "ZCFpv_Beta", sw - 50, sh - 40, clr, 2)
end

local function DrawDigital(drone, sw, sh, cx, cy, sig)
	local vel = drone:GetVelocity()
	local air = math.Round(vel:Length() * 0.09144)
	local gnd = math.Round(Vector(vel.x, vel.y, 0):Length() * 0.09144)
	if not takeOffPos then takeOffPos = drone:GetPos() end
	local alt = math.max(0, math.Round((drone:GetPos().z - takeOffPos.z) / 39.37, 1))

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(M_CH)
	surface.DrawTexturedRect(cx - 32, cy - 32, 64, 64)

	local spdX, spdY = 50, sh - 175
	surface.SetMaterial(M_AIR)
	surface.DrawTexturedRect(spdX, spdY, 40, 26)
	draw.SimpleText(tostring(air), "ZCFpv_OSD", spdX + 120, spdY + 13, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	surface.SetMaterial(M_KMH)
	surface.DrawTexturedRect(spdX + 125, spdY - 2, 30, 30)
	surface.SetMaterial(M_GND)
	surface.DrawTexturedRect(spdX, spdY + 38, 40, 26)
	draw.SimpleText(tostring(gnd), "ZCFpv_OSD", spdX + 120, spdY + 51, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	surface.SetMaterial(M_KMH)
	surface.DrawTexturedRect(spdX + 125, spdY + 36, 30, 30)

	local rx = sw - 160
	surface.SetMaterial(M_MM)
	surface.DrawTexturedRect(rx + 10, spdY - 15, 30, 30)
	draw.SimpleText(string.format("%.1f", alt), "ZCFpv_OSD", rx - 10, spdY, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	local wifiX, wifiY = sw - 120, 40
	surface.SetMaterial(M_WIFI)
	surface.DrawTexturedRect(wifiX, wifiY, 36, 36)
	local bars = sig > 0.85 and M_P4 or sig > 0.65 and M_P3 or sig > 0.4 and M_P2 or sig > 0.2 and M_P1 or M_P0
	surface.SetMaterial(bars)
	surface.DrawTexturedRect(wifiX - 50, wifiY + 4, 44, 28)
	draw.SimpleText(math.floor(sig * 100) .. "%", "ZCFpv_OSD_Sm", wifiX + 18, wifiY + 40, sig < 0.35 and Color(255, 80, 80) or color_white, TEXT_ALIGN_CENTER)
end

local function enableVHS()
	if not REALISTICVHSEFFECT2_CFG or vhsOn then return end
	vhsOn = true
	RunConsoleCommand("realisticvhseffect2_enabled", "1")
	REALISTICVHSEFFECT2_CFG.channelssettings.chroma_noise_enabled = false
	REALISTICVHSEFFECT2_CFG.channelssettings.luma_noise_enabled = false
	REALISTICVHSEFFECT2_CFG.channelssettings.general_blur = 0.35
	REALISTICVHSEFFECT2_CFG.channelssettings.chroma_blur = 0.8
	REALISTICVHSEFFECT2_CFG.wave.enabled = false
	REALISTICVHSEFFECT2_CFG.lines.enabled = false
	REALISTICVHSEFFECT2_CFG.tubedelay.enabled = false
	REALISTICVHSEFFECT2_CFG.presize = true
	REALISTICVHSEFFECT2_CFG.viewtype = 0
	REALISTICVHSEFFECT2_CFG.sharpen.enabled = false
	REALISTICVHSEFFECT2_CFG.interlaced.enabled = false
	REALISTICVHSEFFECT2_CFG.osd.dateenabled = false
	REALISTICVHSEFFECT2_CFG.osd.vcr_text_enabled = false
	REALISTICVHSEFFECT2_CFG.osd.middletext = nil
	REALISTICVHSEFFECT2_CFG.comets.enabled = false
	if REALISTICVHSEFFECT2_CFG.currenthookclass ~= "RenderScreenspaceEffects" then
		RunConsoleCommand("realisticvhseffect2_changehook", "RenderScreenspaceEffects")
	end
end

local function disableVHS()
	local enabled = GetConVar("realisticvhseffect2_enabled")
	if not vhsOn and (not enabled or not enabled:GetBool()) then return end
	vhsOn = false
	RunConsoleCommand("realisticvhseffect2_enabled", "0")
	if REALISTICVHSEFFECT2_CFG then
		REALISTICVHSEFFECT2_CFG.comets.enabled = false
		REALISTICVHSEFFECT2_CFG.wave.enabled = false
		REALISTICVHSEFFECT2_CFG.lines.enabled = false
		REALISTICVHSEFFECT2_CFG.cameraclrdist.r = 0
		REALISTICVHSEFFECT2_CFG.cameraclrdist.g = 0
		REALISTICVHSEFFECT2_CFG.cameraclrdist.b = 0
		REALISTICVHSEFFECT2_CFG.postclrmod["pp_colour_colour"] = 1
	end
	desatVal = 1
end

local function updateVHS()
	if not REALISTICVHSEFFECT2_CFG or not vhsOn then return end
	REALISTICVHSEFFECT2_CFG.comets.enabled = false
	REALISTICVHSEFFECT2_CFG.interlaced.enabled = false
	REALISTICVHSEFFECT2_CFG.sharpen.enabled = false
	REALISTICVHSEFFECT2_CFG.cameraclrdist.r = 0
	REALISTICVHSEFFECT2_CFG.cameraclrdist.g = 0
	REALISTICVHSEFFECT2_CFG.cameraclrdist.b = 0
	REALISTICVHSEFFECT2_CFG.channelssettings.general_blur = 0.35
	REALISTICVHSEFFECT2_CFG.channelssettings.chroma_blur = 0.8
	REALISTICVHSEFFECT2_CFG.presize = true
	REALISTICVHSEFFECT2_CFG.viewtype = 0
	REALISTICVHSEFFECT2_CFG.wave.enabled = false
	REALISTICVHSEFFECT2_CFG.lines.enabled = false
	if GetConVar("zc_fpv_vhs_desat"):GetBool() then
		local ct = CurTime()
		if ct > desatNext then
			desatEnd = ct + math.Rand(0.5, 1)
			desatNext = ct + math.Rand(8, 25)
		end
		desatVal = Lerp(FrameTime() * 3, desatVal, ct < desatEnd and 0 or 1)
		REALISTICVHSEFFECT2_CFG.postclrmod["pp_colour_colour"] = desatVal
	else
		REALISTICVHSEFFECT2_CFG.postclrmod["pp_colour_colour"] = 1
	end
end

local kvnWhot = {
	["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = -0.02, ["$pp_colour_contrast"] = 1.55, ["$pp_colour_colour"] = 0,
	["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
}
local kvnBhot = {
	["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0.02, ["$pp_colour_contrast"] = -1.45, ["$pp_colour_colour"] = 0,
	["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
}

hook.Add("RenderScreenspaceEffects", "ZCFpv_WorldNoise", function()
	local drone = ZCFpv.GetLinkedDrone(LocalPlayer())
	if not IsValid(drone) then return end
	local cls = drone:GetClass()
	if string.sub(cls, 1, 14) == "ent_zc_fpv_kvn" then
		local mode = ZCFpv.KvnTherm or 0
		if mode > 0 then
			DrawColorModify(mode == 2 and kvnBhot or kvnWhot)
			DrawSobel(0.1)
		end
		return
	end
	if cls == "ent_zc_fpv_mavic" then return end

	local sig = drone:GetSignal() or 1
	local jam = drone:GetNWFloat("ZCFpvJam", 0)
	updateNoise(sig, jam)
	drone.SmoothNoise = smoothNoise
	if smoothNoise <= 1 then return end

	local sw, sh = ScrW(), ScrH()
	local ns = 25 + (sig < 0.12 and 35 or 0)
	local sx, sy = (CurTime() * ns) % 1, (CurTime() * ns * 1.2) % 1
	surface.SetMaterial(M_NOISE)
	surface.SetDrawColor(255, 255, 255, math.min(smoothNoise, 220))
	surface.DrawTexturedRectUV(0, 0, sw, sh, sx, sy, sx + 1, sy + 1)

	if sig < 0.1 then
		local sx2, sy2 = (CurTime() * -ns * 0.7) % 1, (CurTime() * ns * 2.1) % 1
		surface.SetDrawColor(255, 255, 255, math.min(smoothNoise * 0.55, 160))
		surface.DrawTexturedRectUV(0, 0, sw, sh, sx2, sy2, sx2 + 1.4, sy2 + 1.4)
		for i = 1, 5 do
			surface.SetDrawColor(255, 255, 255, math.random(25, 80))
			surface.DrawRect(0, math.random(0, sh), sw, math.random(1, 3))
		end
	end
end)

local colW = Color(255, 255, 255, 245)
local colDim = Color(255, 255, 255, 90)
local colShadow = Color(0, 0, 0, 160)
local colBlue = Color(32, 132, 255, 255)
local colDelay = Color(255, 196, 70, 255)
local colBad = Color(255, 78, 64, 255)
local colShade = Color(0, 0, 0, 120)
local colRec = Color(255, 42, 42, 255)

local function djiText(text, font, x, y, ax, ay, col)
	draw.SimpleText(text, font, x + 1, y + 1, colShadow, ax, ay)
	draw.SimpleText(text, font, x, y, col or colW, ax, ay)
end

local function disc(cx, cy, r, col)
	local d = math.max(r * 2, 2)
	draw.RoundedBox(r, cx - r, cy - r, d, d, col)
end

local function ring(cx, cy, r, seg, col)
	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	local step = math.pi * 2 / seg
	local px, py = cx + r, cy
	for i = 1, seg do
		local a = step * i
		local nx = cx + math.cos(a) * r
		local ny = cy + math.sin(a) * r
		surface.DrawLine(px, py, nx, ny)
		px, py = nx, ny
	end
end

local function arc(cx, cy, r, a0, a1, seg, col)
	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	local px, py
	for i = 0, seg do
		local a = math.rad(a0 + (a1 - a0) * (i / seg))
		local nx = cx + math.cos(a) * r
		local ny = cy + math.sin(a) * r
		if px then surface.DrawLine(px, py, nx, ny) end
		px, py = nx, ny
	end
end

local function S(n)
	return math.floor(n * math.max(ScrH() / 1080, 0.85))
end

local function fillDisc(cx, cy, r, col)
	local seg = 48
	local pts = {}
	for i = 0, seg - 1 do
		local a = (i / seg) * math.pi * 2
		pts[i + 1] = {x = cx + math.cos(a) * r, y = cy + math.sin(a) * r}
	end
	draw.NoTexture()
	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	surface.DrawPoly(pts)
end

local function mavicFrame(sw, sh)
	local mx = math.floor(sw * 0.11)
	local my = math.floor(sh * 0.07)
	return mx, my, sw - mx * 2, sh - my * 2
end

local function mavicBars(sw, sh)
	local x, y, w, h = mavicFrame(sw, sh)
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(0, 0, sw, y)
	surface.DrawRect(0, y + h, sw, sh - y - h)
	surface.DrawRect(0, y, x, h)
	surface.DrawRect(x + w, y, sw - x - w, h)
	return x, y, w, h
end

local function DrawMavic(drone, sw, sh, sig)
	local pos = drone:GetPos()
	local ct = CurTime()
	if not takeOffPos then takeOffPos = pos end
	if not flightStart then flightStart = ct end

	local vel = drone:GetVelocity()
	local hspd = Vector(vel.x, vel.y, 0):Length() / 39.37
	local vspd = vel.z / 39.37
	local alt = (pos.z - takeOffPos.z) / 39.37
	local homeFlat = Vector(takeOffPos.x, takeOffPos.y, 0)
	local distHome = Vector(pos.x, pos.y, 0):Distance(homeFlat) / 39.37
	local jam = drone:GetNWFloat("ZCFpvJam", 0)
	local maxHp = drone.MaxHP or 100
	if drone.GetMaxHealth then maxHp = drone:GetMaxHealth() end
	local bat = math.Clamp(drone:Health() / math.max(maxHp, 1), 0, 1)
	local sport = LocalPlayer():KeyDown(IN_SPEED)
	local fTime = ct - flightStart
	local bars = sig > 0.82 and 4 or sig > 0.58 and 3 or sig > 0.34 and 2 or sig > 0.12 and 1 or 0
	local barCol = bars <= 1 and colBad or colW
	render.SetScissorRect(0, 0, 0, 0, false)
	local x0, y0, vw, vh = mavicBars(sw, sh)

	local mode = sport and "Mode S" or "Mode P"
	surface.SetFont("ZCFpv_Dji")
	local modeW = surface.GetTextSize(mode)
	local lx, ly = x0 + S(22), y0 + S(16)
	surface.SetDrawColor(255, 255, 255, 240)
	for o = 0, 1 do
		surface.DrawLine(lx + S(9), ly + o, lx + o, ly + S(8))
		surface.DrawLine(lx + o, ly + S(8), lx + S(9), ly + S(16) - o)
	end
	djiText(mode, "ZCFpv_Dji", x0 + S(46), y0 + S(12), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	surface.SetDrawColor(255, 255, 255, 180)
	surface.DrawRect(x0 + S(46) + modeW + S(12), y0 + S(16), 1, S(18))
	djiText("In Flight", "ZCFpv_Dji", x0 + S(46) + modeW + S(24), y0 + S(12), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	local right = x0 + vw - S(22)
	local ty = y0 + S(14)
	for i = 0, 2 do
		disc(right, ty + S(6) + i * S(6), S(2), colW)
	end
	right = right - S(16)

	local timeStr = string.format("%d'%02d\"", math.floor(fTime / 60), math.floor(fTime % 60))
	surface.SetFont("ZCFpv_DjiMd")
	local tw = surface.GetTextSize(timeStr)
	djiText(timeStr, "ZCFpv_DjiMd", right, ty, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	right = right - tw - S(12)

	local bstr = tostring(math.floor(bat * 100))
	local bw = surface.GetTextSize(bstr)
	djiText(bstr, "ZCFpv_DjiMd", right, ty, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, bat < 0.2 and colBad or colW)
	right = right - bw - S(8)

	local batX, batY, batW, batH = right - S(30), ty + S(3), S(28), S(14)
	surface.SetDrawColor(255, 255, 255, 230)
	surface.DrawOutlinedRect(batX, batY, batW, batH, 1)
	surface.DrawRect(batX + batW, batY + S(4), S(2), batH - S(8))
	local fill = math.max(math.floor((batW - 4) * bat), 0)
	local fillCol = bat < 0.2 and colBad or colW
	surface.SetDrawColor(fillCol.r, fillCol.g, fillCol.b, 245)
	if fill > 0 then surface.DrawRect(batX + 2, batY + 2, fill, batH - 4) end
	right = batX - S(16)

	local wifiY = ty + S(16)
	local wifiCol = bars <= 1 and colBad or colW
	disc(right, wifiY, S(2), wifiCol)
	arc(right, wifiY, S(6), 200, 340, 7, wifiCol)
	arc(right, wifiY, S(10), 205, 335, 8, bars >= 2 and wifiCol or colDim)
	arc(right, wifiY, S(14), 210, 330, 9, bars >= 3 and wifiCol or colDim)
	right = right - S(28)

	for i = 1, 4 do
		local h = S(4 + i * 3)
		local x = right - S(22) + (i - 1) * S(5)
		local y = ty + S(16) - h
		local barDraw = i <= bars and barCol or colDim
		surface.SetDrawColor(barDraw.r, barDraw.g, barDraw.b, barDraw.a)
		surface.DrawRect(x, y, S(3), h)
	end

	local warnY = y0 + S(48)
	if jam > 0.2 then
		djiText("Interference", "ZCFpv_DjiSm", x0 + vw * 0.5, warnY, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, colBad)
		warnY = warnY + S(18)
	end
	local dly = ZCFpv.MavicDelay or 0
	if dly > 0.35 then
		djiText(string.format("Delay %.1fs", dly), "ZCFpv_DjiSm", x0 + vw * 0.5, warnY, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, dly > 1.3 and colBad or colDelay)
	end

	local hx, hy, hr = x0 + S(40), y0 + math.floor(vh * 0.46), S(16)
	ring(hx, hy, hr, 28, colW)
	ring(hx, hy, hr - 1, 28, colW)
	local view = ZCFpv.ViewAng or drone:GetAngles()
	local toHome = takeOffPos - pos
	local yaw = math.rad(view.y)
	local fwd = Vector(math.cos(yaw), math.sin(yaw), 0)
	local side = Vector(math.sin(yaw), -math.cos(yaw), 0)
	local a = math.atan2(toHome:Dot(side), toHome:Dot(fwd))
	if toHome:Length2DSqr() < 400 then a = 0 end
	local dx, dy = math.sin(a), -math.cos(a)
	local px, py = -dy, dx
	local len = S(8)
	draw.NoTexture()
	surface.SetDrawColor(255, 255, 255, 245)
	surface.DrawPoly({
		{x = hx + dx * len, y = hy + dy * len},
		{x = hx - dx * len * 0.55 + px * len * 0.45, y = hy - dy * len * 0.55 + py * len * 0.45},
		{x = hx - dx * len * 0.55 - px * len * 0.45, y = hy - dy * len * 0.55 - py * len * 0.45},
	})

	local tx = x0 + S(24)
	local by = y0 + vh - S(20)
	djiText(string.format("H %.0f m", alt), "ZCFpv_Dji", tx, by, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	djiText(string.format("D %.0f m", distHome), "ZCFpv_Dji", tx + S(148), by, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	djiText(string.format("%.1fm/s", hspd), "ZCFpv_DjiSm", tx, by - S(28), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	local vcol = vspd < -1.5 and colDelay or colW
	djiText(string.format("%.1fm/s", math.abs(vspd)), "ZCFpv_DjiSm", tx + S(148), by - S(28), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, vcol)

	local btnR = S(30)
	local btnX = x0 + vw - S(28) - btnR
	local btnY = y0 + math.floor(vh * 0.5)
	fillDisc(btnX + 1, btnY + 2, btnR + 1, colShade)
	fillDisc(btnX, btnY, btnR, colW)
	fillDisc(btnX, btnY, btnR - S(7), colRec)
	djiText(string.format("%.1fx", ZCFpv.MavicZoom or 1), "ZCFpv_DjiMd", x0 + vw * 0.5, y0 + vh - S(20), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

	surface.SetFont("ZCFpv_DjiSm")
	local videoW = surface.GetTextSize("VIDEO")
	local photoX = btnX - btnR - S(18)
	djiText("VIDEO", "ZCFpv_DjiSm", photoX, btnY, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	djiText("PHOTO", "ZCFpv_DjiSm", photoX - videoW - S(14), btnY, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, colDim)

	if updateAltitude(pos, drone) < 5 then
		djiText("Low Altitude", "ZCFpv_Dji", x0 + vw * 0.5, y0 + vh - S(200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, colBad)
	end
end

local function vtFrame(sw, sh)
	local w = math.floor(sh * 4 / 3)
	local h = sh
	if w > sw then
		w = sw
		h = math.floor(sw * 3 / 4)
	end
	return math.floor((sw - w) * 0.5), math.floor((sh - h) * 0.5), w, h
end

local function vtBars(sw, sh)
	local x, y, w, h = vtFrame(sw, sh)
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(0, 0, sw, y)
	surface.DrawRect(0, y + h, sw, math.max(sh - y - h, 0))
	surface.DrawRect(0, y, x, h)
	surface.DrawRect(x + w, y, math.max(sw - x - w, 0), h)
	return x, y, w, h
end

local function analogOsd(cls)
	return cls == "ent_zc_fpv_vt40" or cls == "ent_zc_fpv_vt40b" or string.sub(cls, 1, 17) == "ent_zc_fpv_crocus"
end

local maxFont = Material("osd/max7456.png", "noclamp")

local function maxGlyph(id, x, y, w, h, col)
	local c = id % 16
	local r = math.floor(id / 16)
	surface.SetMaterial(maxFont)
	if col then
		surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	else
		surface.SetDrawColor(255, 255, 255, 255)
	end
	surface.DrawTexturedRectUV(x, y, w, h, c * 48 / 1024, r * 72 / 4096, (c + 1) * 48 / 1024, (r + 1) * 72 / 4096)
end

local kvnInk = Color(236, 236, 236, 255)
local kvnWarn = Color(255, 72, 64, 255)

local function isKvn(cls)
	return string.sub(cls or "", 1, 14) == "ent_zc_fpv_kvn"
end

local function DrawVt(drone, x0, y0, vw, vh, sig)
	local pos = drone:GetPos()
	local ang = drone:GetAngles()
	local ct = CurTime()
	if not takeOffPos then takeOffPos = pos end
	if not flightStart then flightStart = ct end
	if vtMahEnt ~= drone then
		vtMahEnt = drone
		vtMah = 0
	end

	local vel = drone:GetVelocity()
	local spd = vel:Length() * 0.09144
	local throttle = math.Clamp(vel:Length() / (drone.MaxVel or 1600), 0.12, 1)
	local amps = 6 + throttle * 38
	vtMah = vtMah + amps * FrameTime() / 3.6
	local soc = math.Clamp(1 - vtMah / 1500, 0, 1)
	local volts = 14.2 + soc * 2.6 - (throttle - 0.12) * 0.9
	local cell = volts / 4
	local alt = updateAltitude(pos, drone)
	local distM = pos:Distance(takeOffPos) / 39.37
	local lq = math.Round(math.Clamp(sig, 0, 1) * 100)
	local rssi = math.Round(-30 - (1 - math.Clamp(sig, 0, 1)) * 100)
	local sats = math.floor(4 + math.Clamp(sig, 0, 1) * 11)
	local lat = 48.015 + pos.x / (111320 * 39.37)
	local lon = 37.802 + pos.y / (111320 * math.cos(math.rad(48.015)) * 39.37)
	local km = math.max(distM / 1000, 0.02)
	local nick = string.upper(LocalPlayer():Nick() or "")
	local clean = {}
	for i = 1, #nick do
		local b = string.byte(nick, i)
		if b and ((b >= 48 and b <= 57) or (b >= 65 and b <= 90) or b == 32 or b == 45) then
			clean[#clean + 1] = string.char(b)
		end
	end
	nick = table.concat(clean)
	if #nick > 12 then nick = string.sub(nick, 1, 12) end

	local cw, ch = vw / 30, vh / 16
	local function glyph(id, col, row)
		maxGlyph(id, x0 + col * cw, y0 + row * ch, cw + 0.5, ch + 0.5)
	end
	local function line(s, col, row)
		for i = 1, #s do
			glyph(string.byte(s, i), col + i - 1, row)
		end
	end
	local function lineR(s, col, row)
		line(s, col - #s + 1, row)
	end

	local batt = 0x63
	if soc < 0.17 then batt = 0x69
	elseif soc < 0.34 then batt = 0x68
	elseif soc < 0.5 then batt = 0x67
	elseif soc < 0.67 then batt = 0x66
	elseif soc < 0.83 then batt = 0x65
	elseif soc < 0.95 then batt = 0x64
	end

	line(tostring(lq), 1, 0)
	glyph(0x02, 0, 0)
	line(tostring(rssi), 1, 1)
	glyph(0x01, 0, 1)
	line(tostring(sats), 2, 2)
	glyph(0x08, 0, 2)
	glyph(0x09, 1, 2)

	line(string.format("ALT %.1fM", alt), 0, 7)
	line(string.format("%.0f", spd), 2, 8)
	glyph(0x88, 0, 8)
	glyph(0x90, 6, 8)

	local voltS = string.format("%.1f", volts)
	local mahS = string.format("%.0f", vtMah)
	line(voltS, 2, 12)
	glyph(batt, 0, 12)
	glyph(0x1F, 2 + #voltS, 12)
	line(mahS, 0, 13)
	glyph(0x99, #mahS + 1, 13)
	line(string.format("LAT %.6f", lat), 0, 15)

	lineR(nick, 29, 0)
	local craft = string.upper(drone.PrintName or "VT-40")
	if string.sub(drone:GetClass(), 1, 17) == "ent_zc_fpv_crocus" then craft = "CROCUS" end
	lineR(craft, 29, 1)
	lineR(string.format("R:%d:%d:P", math.Clamp(math.Round(sig * 4), 0, 4), math.Round(50 + sig * 150)), 29, 2)

	local thrS = string.format("%d", math.Round(throttle * 100))
	local ampS = string.format("%.2f", amps)
	local effS = string.format("%.0f", vtMah / km)
	glyph(0x95, 29 - #thrS, 6)
	line(thrS, 30 - #thrS, 6)
	line(ampS, 29 - #ampS, 7)
	glyph(0x6A, 29, 7)
	line(effS, 28 - #effS, 8)
	glyph(0x6B, 28, 8)
	glyph(0x6C, 29, 8)
	lineR(drone:GetHover() and "ANGL" or "ACRO", 29, 10)

	local cellS = string.format("%.2f", cell)
	line(cellS, 13, 14)
	glyph(batt, 11, 14)
	glyph(0x1F, 13 + #cellS, 14)
	lineR(string.format("LON %.6f", lon), 29, 15)

	local toHome = takeOffPos - pos
	local rel = math.atan2(toHome:Dot(ang:Right()), toHome:Dot(ang:Forward()))
	if toHome:Length2DSqr() < 400 then rel = 0 end
	local deg = math.deg(rel) % 360
	if deg < 0 then deg = deg + 360 end
	glyph(0x13C + math.floor((deg + 11.25) / 22.5) % 16, 14, 2)
	local distS = string.format("%.0fM", distM)
	glyph(0x165, 12, 4)
	line(distS, 14, 4)

	if cell < 3.55 and math.sin(ct * 8) > 0 then
		line("LOW VOLTAGE", 9, 9)
	end
end

local function DrawKvn(drone, x0, y0, vw, vh)
	local pos = drone:GetPos()
	local ang = drone:GetAngles()
	local ct = CurTime()
	if not takeOffPos then takeOffPos = pos end
	if not flightStart then flightStart = ct end

	local vel = drone:GetVelocity()
	local throttle = math.Clamp(vel:Length() / (drone.MaxVel or 1400), 0.15, 1)
	local amps = 14 + throttle * 38
	local soc = math.Clamp(1 - (ct - flightStart) * (8 + throttle * 10) / 1800, 0, 1)
	local cellV = 3.55 + soc * 0.65 - (throttle - 0.15) * 0.1
	local pack = cellV * 6
	local alt = math.max(0, updateAltitude(pos, drone))
	local distM = pos:Distance(takeOffPos) / 39.37
	local spd = vel:Length() * 0.09144
	local lat = 48.015 + pos.x / (111320 * 39.37)
	local lon = 37.802 + pos.y / (111320 * math.cos(math.rad(48.015)) * 39.37)
	local head = (-ang.y + 90) % 360
	local fly = ct - flightStart
	local pad = S(20)
	local cx, cy = x0 + vw * 0.5, y0 + vh * 0.5
	local row = S(32)

	local function ink(s, font, x, y, ax, ay, col)
		draw.SimpleTextOutlined(s, font, x, y, col or kvnInk, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP, 1, color_black)
	end

	ink(string.upper(drone.PrintName or "KVN"), "ZCFpv_Kvn", x0 + pad, y0 + pad)
	local therm = ZCFpv.KvnTherm or 0
	if therm > 0 then
		ink(therm == 2 and "BHOT" or "WHOT", "ZCFpv_KvnSm", x0 + pad, y0 + pad + row)
	end

	ink(drone:GetHover() and "ANGLE" or "ACRO", "ZCFpv_Kvn", x0 + vw - pad, y0 + pad, TEXT_ALIGN_RIGHT)
	ink(string.format("%02d:%02d", math.floor(fly / 60), math.floor(fly % 60)), "ZCFpv_Kvn", x0 + vw - pad, y0 + pad + row, TEXT_ALIGN_RIGHT)

	local gap, arm = S(12), S(26)
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(cx - arm - gap - 1, cy - 1, arm + 2, 4)
	surface.DrawRect(cx + gap - 1, cy - 1, arm + 2, 4)
	surface.DrawRect(cx - 1, cy - arm - gap - 1, 4, arm + 2)
	surface.DrawRect(cx - 1, cy + gap - 1, 4, arm + 2)
	surface.SetDrawColor(236, 236, 236, 255)
	surface.DrawRect(cx - arm - gap, cy, arm, 2)
	surface.DrawRect(cx + gap, cy, arm, 2)
	surface.DrawRect(cx, cy - arm - gap, 2, arm)
	surface.DrawRect(cx, cy + gap, 2, arm)
	ink(string.format("%.1fA", amps), "ZCFpv_Kvn", cx, cy + S(78), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local leftY = y0 + vh - pad - S(36) - row * 4
	local distS = distM >= 1000 and string.format("%.2f KM", distM / 1000) or string.format("%.0f M", distM)
	ink(string.format("ALT %.0f M", alt), "ZCFpv_Kvn", x0 + pad, leftY)
	ink(string.format("SPD %.0f", spd), "ZCFpv_Kvn", x0 + pad, leftY + row)
	ink("DST " .. distS, "ZCFpv_Kvn", x0 + pad, leftY + row * 2)
	local voltCol = cellV < 3.6 and kvnWarn or kvnInk
	ink(string.format("%.1fV", pack), "ZCFpv_Kvn", x0 + pad, leftY + row * 3, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, voltCol)
	ink(string.format("%.2fV", cellV), "ZCFpv_KvnSm", x0 + pad, leftY + row * 4)

	local rightY = y0 + vh - pad - S(28) - row * 2
	ink(string.format("%.6f", lat), "ZCFpv_Kvn", x0 + vw - pad, rightY, TEXT_ALIGN_RIGHT)
	ink(string.format("%.6f", lon), "ZCFpv_Kvn", x0 + vw - pad, rightY + row, TEXT_ALIGN_RIGHT)
	ink(string.format("HDG %03d", math.Round(head) % 360), "ZCFpv_KvnSm", x0 + vw - pad, rightY + row * 2, TEXT_ALIGN_RIGHT)
end

function ZCFpv.DrawFPVEffects(drone)
	if not IsValid(drone) then return end

	local sw, sh = ScrW(), ScrH()
	local cx, cy = sw * 0.5, sh * 0.5
	local sig = drone:GetSignal() or 1
	local mavic = drone:GetClass() == "ent_zc_fpv_mavic"

	if mavic then
		DrawMavic(drone, sw, sh, sig)
		return
	end

	local cls = drone:GetClass()
	if isKvn(cls) then return end

	updateNoise(sig, drone:GetNWFloat("ZCFpvJam", 0))
	drone.SmoothNoise = smoothNoise

	if analogOsd(cls) then return end

	if drone.Strike or cls == "ent_zc_fpv_crocus" then
		DrawBetaflight(drone, sw, sh, cx, cy, sig)
	else
		DrawDigital(drone, sw, sh, cx, cy, sig)
	end

	if updateAltitude(drone:GetPos(), drone) < lowAltWarn and math.sin(CurTime() * 8) > 0 then
		draw.SimpleTextOutlined("снизьте скорость", "ZCFpv_OSD", cx, sh - 50, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	end

	if GetConVar("zc_fpv_vhs"):GetBool() then
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(0, 0, 10, sh)
		surface.DrawRect(sw - 10, 0, 10, sh)
		surface.DrawRect(0, 0, sw, 10)
		surface.DrawRect(0, sh - 10, sw, 10)
	end
end

hook.Add("Think", "ZCFpv_VHS", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local drone = ZCFpv.GetLinkedDrone(ply)
	local cls = IsValid(drone) and drone:GetClass() or ""
	local cleanFeed = cls == "ent_zc_fpv_mavic" or isKvn(cls)
	if IsValid(drone) and not cleanFeed and GetConVar("zc_fpv_vhs"):GetBool() then
		enableVHS()
		updateVHS()
	else
		if not IsValid(drone) then
			takeOffPos = nil
			flightStart = nil
			vtMah = 0
			vtMahEnt = nil
			ZCFpv.KvnTherm = 0
		end
		disableVHS()
	end
end)

hook.Add("PlayerButtonDown", "ZCFpv_KvnTherm", function(ply, btn)
	if ply ~= LocalPlayer() or btn ~= KEY_N then return end
	local drone = ZCFpv.GetLinkedDrone(ply)
	if not IsValid(drone) or not isKvn(drone:GetClass()) then return end
	ZCFpv.KvnTherm = ((ZCFpv.KvnTherm or 0) + 1) % 3
end)

hook.Add("HUDPaint", "ZCFpv_OSD", function()
	local drone = ZCFpv.GetLinkedDrone(LocalPlayer())
	if not IsValid(drone) then return end
	local cls = drone:GetClass()
	if cls == "ent_zc_fpv_mavic" or analogOsd(cls) or isKvn(cls) then return end
	ZCFpv.DrawFPVEffects(drone)
end)

local feed = {}
local feedN = 12
local feedDt = 0.2
local feedMax = 2.2
local feedWrite = 1
local feedNext = 0
local feedW, feedH = 0, 0
local feedSmooth = 0

hook.Add("PreDrawHUD", "ZCFpv_MavicFeed", function()
	local drone = ZCFpv.GetLinkedDrone(LocalPlayer())
	if not IsValid(drone) or drone:GetClass() ~= "ent_zc_fpv_mavic" then
		feedSmooth = 0
		ZCFpv.MavicDelay = 0
		for i = 1, feedN do
			if feed[i] then feed[i].t = nil end
		end
		return
	end

	local sw, sh = ScrW(), ScrH()
	if feedW ~= sw or feedH ~= sh then
		feedW, feedH = sw, sh
		feed = {}
		feedWrite = 1
		feedNext = 0
	end

	local now = CurTime()
	if now >= feedNext then
		feedNext = now + feedDt
		local slot = feed[feedWrite]
		if not slot or not slot.rt then
			local name = "zc_mavic_feed_" .. feedWrite .. "_" .. sw .. "x" .. sh
			local rt = GetRenderTarget(name, sw, sh)
			slot = {
				rt = rt,
				mat = CreateMaterial(name, "UnlitGeneric", {
					["$basetexture"] = rt:GetName(),
					["$ignorez"] = "1",
					["$nolod"] = "1",
				}),
			}
			feed[feedWrite] = slot
		end
		render.CopyRenderTargetToTexture(slot.rt)
		slot.mat:SetTexture("$basetexture", slot.rt)
		slot.t = now
		feedWrite = feedWrite % feedN + 1
	end

	local sig = math.Clamp(drone:GetSignal() or 1, 0, 1)
	local jam = math.Clamp(drone:GetNWFloat("ZCFpvJam", 0), 0, 1)
	local lose = math.max(1 - sig, jam)
	feedSmooth = Lerp(FrameTime() * 1.6, feedSmooth, (lose ^ 1.15) * feedMax)
	ZCFpv.MavicDelay = feedSmooth

	if feedSmooth >= feedDt then
		local want = now - feedSmooth
		local best, bestDt
		for i = 1, feedN do
			local slot = feed[i]
			if slot and slot.t and slot.mat then
				local d = math.abs(slot.t - want)
				if not bestDt or d < bestDt then
					best, bestDt = slot, d
				end
			end
		end
		if best then
			surface.SetMaterial(best.mat)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(0, 0, sw, sh)
		end
	end

	mavicBars(sw, sh)
end)

hook.Add("PostDrawHUD", "ZCFpv_MavicBars", function()
	local drone = ZCFpv.GetLinkedDrone(LocalPlayer())
	if not IsValid(drone) or drone:GetClass() ~= "ent_zc_fpv_mavic" then return end
	ZCFpv.DrawFPVEffects(drone)
end)

hook.Add("PostDrawHUD", "ZCFpv_VtFrame", function()
	local drone = ZCFpv.GetLinkedDrone(LocalPlayer())
	if not IsValid(drone) then return end
	local cls = drone:GetClass()
	if not analogOsd(cls) then return end
	local sw, sh = ScrW(), ScrH()
	local x, y, w, h = vtBars(sw, sh)
	DrawVt(drone, x, y, w, h, drone:GetSignal() or 1)
end)

hook.Add("PostDrawHUD", "ZCFpv_KvnFrame", function()
	local drone = ZCFpv.GetLinkedDrone(LocalPlayer())
	if not IsValid(drone) or not isKvn(drone:GetClass()) then return end
	local sw, sh = ScrW(), ScrH()
	local mx = math.floor(sw * 0.07)
	local my = math.floor(sh * 0.055)
	local w, h = sw - mx * 2, sh - my * 2
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(0, 0, sw, my)
	surface.DrawRect(0, my + h, sw, sh - my - h)
	surface.DrawRect(0, my, mx, h)
	surface.DrawRect(mx + w, my, sw - mx - w, h)
	surface.SetDrawColor(28, 28, 28, 255)
	surface.DrawOutlinedRect(mx, my, w, h)
	DrawKvn(drone, mx, my, w, h)
end)

hook.Add("HUDShouldDraw", "ZCFpv_MavicFrame", function(name)
	local drone = ZCFpv.GetLinkedDrone(LocalPlayer())
	if not IsValid(drone) then return end
	local cls = drone:GetClass()
	if cls ~= "ent_zc_fpv_mavic" and not analogOsd(cls) and not isKvn(cls) then return end
	if name == "CHudChat" then return end
	return false
end)
