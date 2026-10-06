ZCFpv = ZCFpv or {}

local linked
local linkedDrone
local viewStartEye
local mavicTargetPitch = 0
local mavicTargetYaw = 0
local mavicShowPitch = 0
local mavicShowYaw = 0
local mavicZoom = 1
local mavicZoomWant = 1
local camLag = 1
local camStep = 0.05
local camSlots = 40
local camHist = {}
local camWrite = 1
local camNext = 0
local freezeOn
local noSignalAt = 0
local capRT, capMat, capW, capH

surface.CreateFont("ZCFpv_Lost", {
	font = "Arial",
	size = 72,
	weight = 700,
	antialias = false,
	extended = true,
})
local portalsPrev
local attachTarget
local attachStart
local attachSent
local payloadNotice
local payloadNoticeUntil = 0
local dropMat = Material("models/sw/avia/mavic2/drop")
local geranX, geranY
local geranAim
local geranHeld
local geranAlt

net.Receive("zc_fpv_payload_notice", function()
	payloadNotice = net.ReadString()
	payloadNoticeUntil = CurTime() + 2.5
	attachTarget = nil
	attachStart = nil
	attachSent = nil
end)

local function buildView(drone, fov, znear, zfar)
	local mavic = drone.Stable
	local fixedWing = drone.FixedWing
	local angles

	if mavic then
		drone:SetPoseParameter("yaw", mavicShowYaw)
		drone:SetPoseParameter("pitch", -mavicShowPitch)
		drone:InvalidateBoneCache()
	end

	local origin
	if drone.CamOffset then
		origin = drone:LocalToWorld(drone.CamOffset)
		angles = angles or drone:GetAngles()
	else
		local id = drone:LookupAttachment("view")
		local att = id and id > 0 and drone:GetAttachment(id)
		if att then
			origin = att.Pos
			angles = angles or att.Ang
		else
			origin = mavic and drone:LocalToWorld(Vector(2, 0, -2)) or drone:LocalToWorld(Vector(4, 0, 2))
			angles = angles or drone:GetAngles()
		end
	end

	if fixedWing then
		angles = drone:GetAngles()
		origin = drone:LocalToWorld(Vector(drone:OBBMaxs().x + 1, 0, 2))
	elseif mavic and not drone.CamOffset then
		angles = drone:LocalToWorldAngles(Angle(mavicShowPitch, mavicShowYaw, 0))
		local scale = drone.ModelScale or 1
		if scale ~= 1 then
			local mins = drone:GetModelBounds()
			local lp = drone:WorldToLocal(origin) * scale
			lp.z = lp.z + mins.z * (1 - scale)
			origin = drone:LocalToWorld(lp)
		end
		origin = origin - drone:GetUp() * 2 * scale + angles:Forward() * 0.5 * scale
	elseif not drone.CamOffset then
		origin = origin - angles:Forward() * 3.5 + angles:Up() * 2
	end

	local viewFov = drone.CamFOV or (fixedWing and 90 or ZCFpv.FOV or fov or 60)
	if mavic and mavicZoom > 1 then
		viewFov = math.deg(2 * math.atan(math.tan(math.rad(viewFov * 0.5)) / mavicZoom))
	end

	ZCFpv.ViewOrigin = origin
	ZCFpv.ViewAng = angles
	ZCFpv.ViewFov = viewFov
	return {
		origin = origin,
		angles = angles,
		fov = viewFov,
		znear = fixedWing and 2 or 0.3,
		zfar = zfar,
		drawviewer = true,
	}
end

local function enableOverride()
	zb = zb or {}
	if ZCFpv._overrideSet then return end
	ZCFpv._overrideSet = true
	ZCFpv._prevOverride = zb.OverrideCalcView

	zb.OverrideCalcView = function(ply, origin, angles, fov, znear, zfar)
		if ZCFpv.MapCapture and ZCFpv.MapView then
			return ZCFpv.MapView
		end
		local drone = linkedDrone
		if not IsValid(drone) then
			drone = ZCFpv.GetLinkedDrone(ply)
		end
		if IsValid(drone) and ply == LocalPlayer() then
			return buildView(drone, fov, znear, zfar)
		end
		if ZCFpv._prevOverride then
			return ZCFpv._prevOverride(ply, origin, angles, fov, znear, zfar)
		end
	end
end

local function disableOverride()
	if not ZCFpv._overrideSet then return end
	ZCFpv._overrideSet = false
	if zb then
		zb.OverrideCalcView = ZCFpv._prevOverride
	end
	ZCFpv._prevOverride = nil
end

local function clearCamHist()
	camNext = 0
	camWrite = 1
	for i = 1, camSlots do
		if camHist[i] then camHist[i].t = nil end
	end
end

local function clearLink()
	linked = false
	linkedDrone = nil
	viewStartEye = nil
	mavicTargetPitch = 0
	mavicTargetYaw = 0
	mavicShowPitch = 0
	mavicShowYaw = 0
	mavicZoom = 1
	mavicZoomWant = 1
	ZCFpv.MavicZoom = 1
	geranX, geranY, geranAim = nil, nil, nil
	clearCamHist()
	if portalsPrev ~= nil then
		RunConsoleCommand("r_portalsopenall", tostring(portalsPrev))
		portalsPrev = nil
	end
	disableOverride()
end

net.Receive("zc_fpv_link", function()
	local on = net.ReadBool()
	local ent = net.ReadEntity()

	if on and IsValid(ent) then
		freezeOn = false
		linked = true
		linkedDrone = ent
		viewStartEye = LocalPlayer():EyeAngles()
		mavicTargetPitch = 0
		mavicTargetYaw = 0
		mavicShowPitch = 0
		mavicShowYaw = 0
		mavicZoom = 1
		mavicZoomWant = 1
		ZCFpv.MavicZoom = 1
		clearCamHist()
		local portals = GetConVar("r_portalsopenall")
		if portals then
			portalsPrev = portals:GetInt()
			RunConsoleCommand("r_portalsopenall", "1")
		end
		enableOverride()
	else
		clearLink()
	end
end)

hook.Add("Think", "ZCFpv_Unstick", function()
	if not linked then return end
	if IsValid(linkedDrone) or IsValid(ZCFpv.GetLinkedDrone(LocalPlayer())) then return end
	clearLink()
end)

-- areaportals follow proxy cam; CalcView from drone attachment (wire in frame)
hook.Add("CalcView", "ZCFpv_ViewEnt", function(ply, origin, angles, fov, znear, zfar)
	if ZCFpv.MapCapture then return ZCFpv.MapView end
	if ply ~= LocalPlayer() then return end
	local drone = linkedDrone or ZCFpv.GetLinkedDrone(ply)
	if not IsValid(drone) then return end
	return buildView(drone, fov, znear, zfar)
end)

hook.Add("PostPostHGCalcView", "ZCFpv_View", function(ply, view)
	if ZCFpv.MapCapture then return ZCFpv.MapView end
	if ply ~= LocalPlayer() then return end
	local drone = linkedDrone or ZCFpv.GetLinkedDrone(ply)
	if not IsValid(drone) then return end

	local v = buildView(drone, view.fov, view.znear, view.zfar)
	view.origin = v.origin
	view.angles = v.angles
	view.fov = v.fov
	view.drawviewer = true
	return view
end)

hook.Add("ShouldDrawLocalPlayer", "ZCFpv_DrawSelf", function(ply)
	if ply ~= LocalPlayer() then return end
	if linked or IsValid(linkedDrone) or IsValid(ZCFpv.GetLinkedDrone(ply)) then
		return true
	end
end)

local vecFull = Vector(1, 1, 1)

hook.Add("PrePlayerDraw", "ZCFpv_ShowHead", function(ply)
	local drone = ply:GetNWEntity("ZCFpvDrone")
	if IsValid(drone) then
		ply:SetRenderAngles(ply:GetNWAngle("ZCFpvBodyAng"))
		ply:SetPoseParameter("aim_yaw", 0)
		ply:SetPoseParameter("aim_pitch", 0)
		ply:SetPoseParameter("head_yaw", 0)
		ply:SetPoseParameter("head_pitch", 0)
	end

	if ply ~= LocalPlayer() or not IsValid(drone) then return end
	local bone = ply:LookupBone("ValveBiped.Bip01_Head1")
	if bone then
		ply:ManipulateBoneScale(bone, vecFull)
	end
end)

local function isGeran(drone)
	return IsValid(drone) and drone:GetClass() == "ent_zc_fpv_geran2"
end

local function screenDir(ang, fov, x, y)
	local tan = math.tan(math.rad(fov) * 0.5)
	local aspect = ScrW() / ScrH()
	local nx = (x / ScrW() - 0.5) * 2 * tan * aspect
	local ny = (0.5 - y / ScrH()) * 2 * tan
	return (ang:Forward() + ang:Right() * nx + ang:Up() * ny):GetNormalized()
end

local function projectAim(pos)
	local origin, ang = ZCFpv.ViewOrigin, ZCFpv.ViewAng
	local fov = ZCFpv.ViewFov or 90
	if not origin or not ang then return end
	local to = pos - origin
	local fwd = to:Dot(ang:Forward())
	if fwd < 8 then return end
	local tan = math.tan(math.rad(fov) * 0.5)
	local aspect = ScrW() / ScrH()
	local x = ScrW() * 0.5 + (to:Dot(ang:Right()) / fwd) / (tan * aspect) * ScrW() * 0.5
	local y = ScrH() * 0.5 - (to:Dot(ang:Up()) / fwd) / tan * ScrH() * 0.5
	return x, y
end

local function strokeRect(x, y, w, h)
	surface.SetDrawColor(0, 0, 0, 210)
	surface.DrawRect(x - 1, y - 1, w + 2, h + 2)
	surface.SetDrawColor(245, 245, 245, 235)
	surface.DrawRect(x, y, w, h)
end

local function lockBox(x, y, scale)
	local s = math.floor(48 * scale)
	local len = math.floor(16 * scale)
	strokeRect(x - s, y - s, len, 2)
	strokeRect(x - s, y - s, 2, len)
	strokeRect(x + s - len, y - s, len, 2)
	strokeRect(x + s - 2, y - s, 2, len)
	strokeRect(x - s, y + s - 2, len, 2)
	strokeRect(x - s, y + s - len, 2, len)
	strokeRect(x + s - len, y + s - 2, len, 2)
	strokeRect(x + s - 2, y + s - len, 2, len)
	strokeRect(x - 7, y - 1, 14, 2)
	strokeRect(x - 1, y - 7, 2, 14)
end

local function geranClear()
	geranAim = false
	net.Start("zc_fpv_geran_aim")
		net.WriteBool(false)
	net.SendToServer()
end

local function geranPick()
	local origin, ang = ZCFpv.ViewOrigin, ZCFpv.ViewAng
	if not origin or not ang or not geranX then return end
	local dir = screenDir(ang, ZCFpv.ViewFov or 90, geranX, geranY)
	local tr = util.TraceLine({
		start = origin,
		endpos = origin + dir * 250000,
		filter = {LocalPlayer(), linkedDrone, linkedDrone.ViewCam},
		mask = MASK_SOLID,
	})
	if not tr.Hit then return end
	geranAim = tr.HitPos
	net.Start("zc_fpv_geran_aim")
		net.WriteBool(true)
		net.WriteVector(tr.HitPos)
	net.SendToServer()
end

hook.Add("CreateMove", "ZCFpv_Freeze", function(cmd)
	if not linked and not IsValid(linkedDrone) then return end
	if IsValid(linkedDrone) and linkedDrone.Stable then
		local mx, my = cmd:GetMouseX() / mavicZoom, cmd:GetMouseY() / mavicZoom
		mavicTargetYaw = math.Clamp(mavicTargetYaw - mx * 0.045, -90, 90)
		mavicTargetPitch = math.Clamp(mavicTargetPitch + my * 0.04, -90, 90)
		cmd:SetMouseX(0)
		cmd:SetMouseY(0)
	elseif isGeran(linkedDrone) then
		if not geranX then
			geranX, geranY = ScrW() * 0.5, ScrH() * 0.5
		end
		geranX = math.Clamp(geranX + cmd:GetMouseX(), 24, ScrW() - 24)
		geranY = math.Clamp(geranY + cmd:GetMouseY(), 24, ScrH() - 24)
		local atk, alt = cmd:KeyDown(IN_ATTACK), cmd:KeyDown(IN_ATTACK2)
		if atk and not geranHeld then geranPick() end
		if alt and not geranAlt then geranClear() end
		geranHeld, geranAlt = atk, alt
		cmd:SetMouseX(0)
		cmd:SetMouseY(0)
	end
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)
	cmd:SetUpMove(0)
end)

hook.Add("Think", "ZCFpv_MavicCamLag", function()
	if not linked or not IsValid(linkedDrone) or not linkedDrone.Stable then return end
	mavicZoom = Lerp(math.min(FrameTime() * 8, 1), mavicZoom, mavicZoomWant)
	ZCFpv.MavicZoom = mavicZoom
	local now = CurTime()
	if now >= camNext then
		camNext = now + camStep
		local slot = camHist[camWrite]
		if not slot then
			slot = {}
			camHist[camWrite] = slot
		end
		slot.t = now
		slot.p = mavicTargetPitch
		slot.y = mavicTargetYaw
		camWrite = camWrite % camSlots + 1
	end

	local want = now - camLag
	local prev, nxt
	for i = 1, camSlots do
		local h = camHist[i]
		if h and h.t then
			if h.t <= want and (not prev or h.t > prev.t) then prev = h end
			if h.t >= want and (not nxt or h.t < nxt.t) then nxt = h end
		end
	end
	if prev and nxt and nxt.t > prev.t then
		local u = (want - prev.t) / (nxt.t - prev.t)
		mavicShowPitch = prev.p + (nxt.p - prev.p) * u
		mavicShowYaw = prev.y + (nxt.y - prev.y) * u
	elseif prev then
		mavicShowPitch = prev.p
		mavicShowYaw = prev.y
	end
end)

hook.Add("PlayerBindPress", "ZCFpv_Block", function(ply, bind, pressed)
	if not linked and not IsValid(ZCFpv.GetLinkedDrone(ply)) then return end
	if pressed and IsValid(linkedDrone) and linkedDrone.Stable and (bind == "invnext" or bind == "invprev") then
		local zoom = bind == "invprev" and mavicZoomWant * 1.25 or mavicZoomWant / 1.25
		mavicZoomWant = math.Clamp(zoom, 1, 4)
		if mavicZoomWant < 1.05 then mavicZoomWant = 1 end
		return true
	end
	if bind == "invnext" or bind == "invprev" or bind == "slot1" or bind == "slot2" or bind == "slot3" or bind == "slot4" or bind == "slot5" or bind == "slot6" then
		return true
	end
end)

net.Receive("zc_fpv_hit", function()
	local immediate = net.ReadBool()
	freezeOn = true
	noSignalAt = CurTime() + (immediate and 0 or 1)
end)

local function clearFreeze()
	if not freezeOn then return end
	freezeOn = false
	net.Start("zc_fpv_feed_clear")
	net.SendToServer()
end

hook.Add("PostRender", "ZCFpv_FreezeCap", function()
	if freezeOn then return end
	if not linked and not IsValid(linkedDrone) then return end

	local sw, sh = ScrW(), ScrH()
	if not capRT or capW ~= sw or capH ~= sh then
		capW, capH = sw, sh
		capRT = GetRenderTarget("zc_fpv_freeze_" .. sw .. "x" .. sh, sw, sh)
		capMat = CreateMaterial("zc_fpv_freeze_" .. sw .. "x" .. sh, "UnlitGeneric", {
			["$basetexture"] = capRT:GetName(),
			["$ignorez"] = "1",
		})
	end

	render.CopyRenderTargetToTexture(capRT)
	capMat:SetTexture("$basetexture", capRT)
end)

hook.Add("PostDrawHUD", "ZCFpv_NoSignal", function()
	if not freezeOn then return end
	if CurTime() > noSignalAt + 1.5 then
		clearFreeze()
		return
	end

	local sw, sh = ScrW(), ScrH()
	if capMat then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(capMat)
		surface.DrawTexturedRect(0, 0, sw, sh)
	else
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(0, 0, sw, sh)
	end

	if CurTime() < noSignalAt then return end

	surface.SetDrawColor(90, 90, 90, 150)
	surface.DrawRect(0, 0, sw, sh)
	draw.SimpleTextOutlined("NO SIGNAL", "ZCFpv_Lost", sw * 0.5, sh * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
end)

hook.Add("HUDPaint", "ZCFpv_GeranBox", function()
	if not isGeran(linkedDrone) then return end
	local scale = math.max(ScrH() / 1080, 0.85)
	local aim = geranAim
	if aim == nil and linkedDrone:GetNWBool("ZCFpvGeranHasAim") then
		aim = linkedDrone:GetNWVector("ZCFpvGeranAim")
	end
	local locked = isvector(aim)
	if geranX and not locked then
		lockBox(geranX, geranY, scale)
	elseif geranX then
		strokeRect(geranX - 6, geranY - 1, 12, 2)
		strokeRect(geranX - 1, geranY - 6, 2, 12)
	end
	if not locked then return end
	local x, y = projectAim(aim)
	if not x then return end
	lockBox(x, y, scale)
end)

hook.Add("PlayerButtonDown", "ZCFpv_FeedClear", function(ply, btn)
	if ply ~= LocalPlayer() or not freezeOn then return end
	if CurTime() < noSignalAt then return end
	if btn ~= KEY_E and btn ~= MOUSE_RIGHT then return end
	clearFreeze()
end)

hook.Add("HUDPaint", "ZCFpv_Payload", function()
	local ply = LocalPlayer()
	local now = CurTime()

	if payloadNoticeUntil > now then
		if payloadNotice == "BOTTOM PAYLOAD RELEASED" then
			surface.SetMaterial(dropMat)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(ScrW() * 0.5 - 128, ScrH() * 0.72 - 64, 256, 128)
		else
			draw.SimpleTextOutlined(payloadNotice, "DermaLarge", ScrW() * 0.5, ScrH() * 0.72, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
		end
	end

	local hudDrone = IsValid(linkedDrone) and linkedDrone or ZCFpv.GetLinkedDrone(ply)
	if IsValid(hudDrone) then
		local jam = hudDrone:GetNWFloat("ZCFpvJam", 0)
		if jam > 0.05 and hudDrone:GetClass() ~= "ent_zc_fpv_mavic" then
			local col = Color(255, math.floor(180 * (1 - jam)), 35)
			draw.SimpleTextOutlined("EW JAM " .. math.floor(jam * 100) .. "%", "DermaDefaultBold", ScrW() * 0.5, 32, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black)
		end
	end

	if linked or IsValid(linkedDrone) then return end

	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or wep.ENT ~= "ent_hg_grenade_rgd5" then
		attachTarget = nil
		attachStart = nil
		attachSent = nil
		return
	end

	local tr = hg.eyeTrace(ply, 240)
	if not tr then
		attachTarget = nil
		attachStart = nil
		attachSent = nil
		return
	end
	local drone = tr.Entity
	if not IsValid(drone) or not drone.DropPayload or IsValid(drone:GetNWEntity("ZCFpvPayload")) then
		attachTarget = nil
		attachStart = nil
		attachSent = nil
		return
	end

	if attachTarget ~= drone then
		attachTarget = drone
		attachStart = nil
		attachSent = nil
	end

	local x, y = ScrW() * 0.5, ScrH() * 0.62
	draw.SimpleTextOutlined("HOLD E TO ATTACH RGD-5", "DermaLarge", x, y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)

	if not ply:KeyDown(IN_USE) then
		attachStart = nil
		attachSent = nil
		return
	end

	attachStart = attachStart or now
	local frac = math.Clamp((now - attachStart) / 0.8, 0, 1)
	surface.SetDrawColor(0, 0, 0, 180)
	surface.DrawRect(x - 101, y + 27, 202, 10)
	surface.SetDrawColor(230, 230, 230, 255)
	surface.DrawRect(x - 99, y + 29, 198 * frac, 6)

	if frac < 1 or attachSent then return end
	attachSent = true
	net.Start("zc_fpv_attach_rgd")
		net.WriteEntity(drone)
	net.SendToServer()
end)
