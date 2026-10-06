ZCFpv = ZCFpv or {}

local profiles = {
	quad = {
		near = 980,
		far = 7100,
		fall = 0.9,
		edgeFar = 1575,
		pmin = 68,
		pmax = 158,
		spoolUp = 9,
		spoolDown = 5,
		shape = true,
		edge = 0.22,
		edgePitch = 1.46,
		wind = 0.46,
		doppler = 1,
		flutter = 2.1,
		load = 8,
	},
	mavic = {
		near = 510,
		far = 4330,
		fall = 0.85,
		edgeFar = 800,
		pmin = 90,
		pmax = 124,
		spoolUp = 3.4,
		spoolDown = 2.2,
		shape = true,
		edge = 0.1,
		edgePitch = 1.2,
		wind = 0.16,
		doppler = 0.65,
		flutter = 0.5,
		load = 3,
	},
	heavy = {
		near = 1200,
		far = 9000,
		fall = 0.85,
		edgeFar = 1800,
		pmin = 62,
		pmax = 142,
		spoolUp = 6,
		spoolDown = 3.5,
		shape = true,
		edge = 0.16,
		edgePitch = 1.32,
		wind = 0.4,
		doppler = 1,
		flutter = 1.4,
		load = 6,
	},
	bomber = {
		near = 1400,
		far = 11000,
		fall = 0.8,
		edgeFar = 2000,
		pmin = 58,
		pmax = 118,
		spoolUp = 3,
		spoolDown = 1.8,
		shape = true,
		edge = 0.1,
		edgePitch = 1.18,
		wind = 0.28,
		doppler = 0.8,
		flutter = 0.6,
		load = 3,
	},
	geran = {
		near = 1600,
		far = 82000,
		fall = 0.58,
		pmin = 93,
		pmax = 103,
		spoolUp = 0.4,
		spoolDown = 0.18,
		shape = false,
		edge = 0,
		edgePitch = 1,
		wind = 0.3,
		doppler = 1.15,
		flutter = 0.35,
		load = 1.2,
	},
}

local function ensure(ent, key, path)
	local snd = ent[key]
	if snd then return snd end
	snd = CreateSound(ent, path)
	if not snd then return end
	snd:SetSoundLevel(0)
	snd:PlayEx(0, 100)
	ent[key] = snd
	return snd
end

function ZCFpv.StopMotorSound(ent)
	if not ent then return end
	if ent.MotorPatch then ent.MotorPatch:Stop() end
	if ent.MotorEdge then ent.MotorEdge:Stop() end
	if ent.MotorWind then ent.MotorWind:Stop() end
	ent.MotorPatch = nil
	ent.MotorEdge = nil
	ent.MotorWind = nil
	ent.MotorRpm = nil
	ent.MotorKick = nil
	ent.MotorThr = nil
end

function ZCFpv.UpdateMotorSound(ent)
	if not IsValid(ent) then return end

	local cls = ent:GetClass()
	local profile = profiles.quad
	if cls == "ent_zc_fpv_mavic" then
		profile = profiles.mavic
	elseif cls == "ent_zc_fpv_vt40b" then
		profile = profiles.bomber
	elseif cls == "ent_zc_fpv_vt40" then
		profile = profiles.heavy
	elseif cls == "ent_zc_fpv_geran2" then
		profile = profiles.geran
	end

	local ft = math.min(math.max(RealFrameTime(), 0.001), 0.05)
	local powered = ent:GetPowered()
	local thr = powered and math.Clamp(ent:GetThrottleFrac() or 0, 0, 1) or 0
	local rpm = ent.MotorRpm or 0
	local rate = thr > rpm and profile.spoolUp or profile.spoolDown
	rpm = math.Approach(rpm, thr, rate * ft)
	ent.MotorRpm = rpm
	if not powered and rpm <= 0.015 then
		if ent.MotorPatch or ent.MotorEdge or ent.MotorWind then
			ZCFpv.StopMotorSound(ent)
		end
		return
	end

	local prev = ent.MotorThr or thr
	ent.MotorThr = thr
	local kick = ent.MotorKick or 0
	if thr > prev + 0.001 then
		kick = math.min(0.16, kick + (thr - prev) * 0.6)
	end
	kick = math.max(0, kick - ft * 1.15)
	ent.MotorKick = kick

	local vel = ent:GetVelocity()
	local speed = vel:Length()
	local view = render.GetViewSetup and render.GetViewSetup(true)
	local ear = view and view.origin or EyePos()
	local pos = ent:GetPos()
	local dist = ear:Distance(pos)
	local ply = LocalPlayer()
	local pilot = IsValid(ply) and ZCFpv.GetLinkedDrone(ply) == ent
	local earVel = pilot and vel or (IsValid(ply) and ply:GetVelocity() or vector_origin)

	local rel = 0
	if not pilot and dist > 48 then
		rel = (vel - earVel):Dot((ear - pos) / dist) * profile.doppler
	end
	local sos = 13504
	local shift = sos / math.max(sos * 0.55, sos - rel)
	shift = math.Clamp(shift, 0.8, 1.28)

	local dull = 0
	if not pilot then
		dull = math.Clamp(dist / (profile.far * 0.7), 0, 1)
	end

	local flutter = math.sin(CurTime() * (16 + rpm * 36)) * profile.flutter * rpm
	local load = 0
	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		load = math.Clamp(phys:GetAngleVelocity():Length() / 520, 0, 1) * profile.load
	end

	local shaped = math.Clamp(rpm + kick, 0, 1)
	if profile.shape then
		shaped = shaped * shaped * 0.35 + shaped * 0.65
	end
	local pitch = (Lerp(shaped, profile.pmin, profile.pmax) + flutter + load) * shift
	if dull > 0 then pitch = pitch * (1 - dull * 0.07) end
	pitch = math.Clamp(pitch, 50, 210)

	local atten = 1
	if not pilot and dist > profile.near then
		atten = (profile.near / dist) ^ profile.fall
	end
	if not pilot and dist >= profile.far then
		atten = 0
	elseif not pilot and dist > profile.far * 0.8 then
		atten = atten * (1 - (dist - profile.far * 0.8) / (profile.far * 0.2))
	end

	local drive = powered and (0.2 + rpm * 0.8) or rpm
	local vol = math.Clamp(drive * atten, 0, 0.92)
	local sig = 1
	if pilot and cls ~= "ent_zc_fpv_mavic" and string.sub(cls, 1, 14) ~= "ent_zc_fpv_kvn" then
		sig = math.Clamp(ent:GetSignal() or 1, 0, 1)
		if sig < 0.55 then
			local n = math.sin(CurTime() * 37)
			local gate = 0.45 + sig
			if sig < 0.22 then
				gate = n > 0.15 and (0.15 + sig) or 0.72
			end
			vol = vol * math.Clamp(gate, 0.05, 1)
			pitch = math.Clamp(pitch + (1 - sig) * n * 7, 50, 210)
		end
	end

	local body = ensure(ent, "MotorPatch", ent.IdleSound or "sw/crocus/crocus_idle.wav")
	if body then
		if vol > 0.02 and not body:IsPlaying() then body:PlayEx(vol, pitch) end
		body:ChangePitch(pitch, 0)
		body:ChangeVolume(vol, 0)
	end

	if profile.edge > 0 then
		local edgeFar = profile.edgeFar or (profile.near * 3)
		local edgeAtten = 1
		if not pilot and dist >= edgeFar then
			edgeAtten = 0
		elseif not pilot and dist > 96 then
			edgeAtten = (1 - dist / edgeFar) ^ 1.7
		end
		local edgeVol = math.Clamp(drive * profile.edge * edgeAtten * (rpm ^ 1.15), 0, 0.24)
		if pilot and sig < 0.55 then edgeVol = edgeVol * math.Clamp(sig + 0.25, 0.05, 1) end
		if edgeVol > 0.015 or ent.MotorEdge then
			local edge = ensure(ent, "MotorEdge", ent.IdleSound or "sw/crocus/crocus_idle.wav")
			if edge then
				if edgeVol > 0.02 and not edge:IsPlaying() then edge:PlayEx(edgeVol, pitch) end
				edge:ChangePitch(math.Clamp(pitch * profile.edgePitch, 60, 230), 0)
				edge:ChangeVolume(edgeVol, 0)
			end
		end
	end

	local spd = math.Clamp(speed / math.max(ent.MaxVel or 2500, 1), 0, 1)
	local windVol = (spd ^ 1.5) * profile.wind
	if pilot then
		windVol = windVol * 1.35
	else
		windVol = windVol * atten * 0.5
		if dist > profile.near * 2.5 then windVol = 0 end
	end
	windVol = math.Clamp(windVol, 0, 0.55)
	if windVol > 0.02 or ent.MotorWind then
		local wind = ensure(ent, "MotorWind", "vehicles/fast_windloop1.wav")
		if wind then
			if windVol > 0.02 and not wind:IsPlaying() then wind:PlayEx(windVol, 90) end
			wind:ChangePitch(78 + spd * 44, 0)
			wind:ChangeVolume(windVol, 0)
		end
	end
end
