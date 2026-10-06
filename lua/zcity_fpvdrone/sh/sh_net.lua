ZCFpv = ZCFpv or {}

ZCFpv.BoomHearDist = 118110
ZCFpv.GeranBoomHearDist = 500000

if SERVER then
	util.AddNetworkString("zc_fpv_link")
	util.AddNetworkString("zc_fpv_hit")
	util.AddNetworkString("zc_fpv_feed_clear")
	util.AddNetworkString("zc_fpv_attach_rgd")
	util.AddNetworkString("zc_fpv_payload_notice")
	util.AddNetworkString("zc_fpv_boom")
	util.AddNetworkString("zc_fpv_geran_aim")

	function ZCFpv.PlayBoomSound(pos, closeSnd, farSnd, mapWide)
		if not pos then return end
		closeSnd = closeSnd or "snd_jack_bigsplodeclose.wav"
		farSnd = farSnd or "mortar_strike_far_dist_03.wav"

		if not mapWide then
			EmitSound(closeSnd, pos, 0, CHAN_AUTO, 1, 140)
		end

		net.Start("zc_fpv_boom")
			net.WriteVector(pos)
			net.WriteString(farSnd)
			net.WriteString(closeSnd)
			net.WriteBool(mapWide and true or false)
		net.Broadcast()
	end
end

function ZCFpv.IsDrone(ent)
	return IsValid(ent) and ent.ZCFpvDrone
end

function ZCFpv.GetLinkedDrone(ply)
	if not IsValid(ply) then return nil end
	local ent = ply:GetNWEntity("ZCFpvDrone")
	if ZCFpv.IsDrone(ent) then return ent end
end

function ZCFpv.GetOwnerDrone(ply)
	if not IsValid(ply) then return nil end
	return ply.ZCFpvOwned
end

if CLIENT then
	net.Receive("zc_fpv_boom", function()
		local pos = net.ReadVector()
		local farSnd = net.ReadString()
		local closeSnd = net.ReadString()
		local mapWide = net.ReadBool()
		local maxDist = mapWide and (ZCFpv.GeranBoomHearDist or 500000) or (ZCFpv.BoomHearDist or 118110)
		local view = render.GetViewSetup and render.GetViewSetup(true)
		local origin = view and view.origin or EyePos()
		local dist = origin:Distance(pos)
		if dist > maxDist then return end

		local delay = dist / 17836
		local farVol = mapWide and math.Clamp((3500 / math.max(dist, 200)) ^ 1.15, 0.06, 1)
			or math.Clamp(0.2 + (1 - dist / maxDist) * 0.8, 0.2, 1)
		local pitch = math.floor(math.Clamp(100 - dist / 2500, 78, 100))

		timer.Simple(delay, function()
			if dist < 4500 then
				local closeVol = math.Clamp(1 - dist / 4500, 0.12, 1)
				EmitSound(closeSnd, pos, 0, CHAN_AUTO, closeVol, mapWide and 0 or 145, 0, 100)
			end
			EmitSound(farSnd, pos, 0, CHAN_STATIC, farVol, mapWide and 0 or 160, 0, pitch)
		end)
	end)
end
