ZCFpv = ZCFpv or {}

local function fpvExpo(x, amount)
	local ax = math.abs(x)
	local s = x < 0 and -1 or 1
	return s * (ax * (1 - amount) + ax * ax * ax * amount)
end

local function mouseStick(ply)
	if not IsValid(ply) then return 0, 0 end
	local mx = ply.ZCFpvMouseX or 0
	local my = ply.ZCFpvMouseY or 0
	return fpvExpo(math.Clamp(mx * 0.028, -1, 1), 0.38), fpvExpo(math.Clamp(my * 0.028, -1, 1), 0.38)
end

local function pushAngles(ent, phys, want, dt, gain)
	local cur = ent.TargetAng or ent:GetAngles()
	cur.p = math.ApproachAngle(cur.p, want.p, 620 * dt)
	cur.y = math.ApproachAngle(cur.y, want.y, 480 * dt)
	cur.r = math.ApproachAngle(cur.r, want.r, 680 * dt)
	ent.TargetAng = cur

	local diff = ent:WorldToLocalAngles(cur)
	local angVel = phys:GetAngleVelocity()
	phys:AddAngleVelocity(Vector(
		math.Clamp(diff.r * gain, -900, 900),
		math.Clamp(diff.p * gain, -900, 900),
		math.Clamp(diff.y * gain, -700, 700)
	) * dt - angVel * 0.34)
end

local function softCap(force, vel, mass, maxVel)
	local speed = vel:Length()
	if speed <= maxVel then return force end
	return force - vel:GetNormalized() * (mass * (speed - maxVel) * 3)
end

function ZCFpv.SimulateQuad(ent, phys, dt)
	if ent.Dead or ent.ZCFpvNetTrapped or not ent:GetPowered() then
		return vector_origin, vector_origin, SIM_NOTHING
	end

	dt = math.min(math.max(dt, 0), 0.05)
	phys:Wake()

	local linked, _, fwd, side, _, boost = ent:ReadPilotInput()
	local ang = ent:GetAngles()
	local mass = phys:GetMass()
	local grav = mass * 600
	local vel = phys:GetVelocity()
	local pos = ent:GetPos()

	if not linked then
		if not ent:GetHover() then
			ent:SetThrottleFrac(0)
			return vector_origin, vector_origin, SIM_NOTHING
		end

		ent:SetThrottleFrac(0.42)
		local zErr = (ent.HoverZ or pos.z) - pos.z
		local force = Vector(0, 0, grav + zErr * 48 - vel.z * 10)
		return vector_origin, force - Vector(vel.x, vel.y, 0) * (mass * 0.8), SIM_GLOBAL_FORCE
	end

	if ent:GetHover() then ent:SetHover(false) end

	local ply = ent:GetController()
	local rollStick, pitchStick = mouseStick(ply)
	local jam = 1 / (1 + ent:GetNWFloat("ZCFpvJam", 0) * 6)
	side = math.Approach(ent.StickS or 0, side, dt * 5)
	ent.StickS = side

	local downSpeed = math.max(0, -vel.z)
	local spoolDown = 2.05
	local spoolUp = 0.9 * (1 + (boost and 0.22 or 0))
	if fwd > 0 and downSpeed > 40 then spoolUp = spoolUp * 1.7 end
	local spool = fwd >= 0 and spoolUp or spoolDown
	ent.RealAcroThrottle = math.Clamp((ent.RealAcroThrottle or 0.58) + fwd * spool * dt, 0, 1.48)
	local thr = ent.RealAcroThrottle
	ent:SetThrottleFrac(math.Clamp(thr / 1.48, 0, 1))

	local thrFrac = math.Clamp(thr / 0.95, 0, 1)
	local auth = 0.55 + 0.45 * thrFrac
	local rawRate = Vector(
		rollStick * 210 * jam * auth,
		pitchStick * 190 * jam * auth,
		side * 120 * jam * auth
	)
	local blend = math.Clamp(dt * 5.5, 0, 1)
	ent.RealAcroRateTarget = LerpVector(blend, ent.RealAcroRateTarget or rawRate, rawRate)

	local desired = ent.RealAcroRateTarget
	local current = phys:GetAngleVelocity()
	local safeDt = math.min(math.max(dt, 0), 0.05)
	phys:AddAngleVelocity(Vector(
		math.Clamp(desired.x - current.x, -340 * safeDt, 340 * safeDt),
		math.Clamp(desired.y - current.y, -310 * safeDt, 310 * safeDt),
		math.Clamp(desired.z - current.z, -220 * safeDt, 220 * safeDt)
	))

	local up = ang:Up()
	local force = up * (grav * thr * (ent.HoverForce or 1.05))
	if fwd < 0 then
		force = force - Vector(0, 0, grav * 0.45 * (-fwd))
	end
	force = force - ang:Right() * vel:Dot(ang:Right()) * mass * 0.22
	force = force - vel * (mass * 0.08)
	if fwd > 0 and downSpeed > 25 then
		force = force + Vector(0, 0, downSpeed * mass * 1.8)
	end
	local climb = math.max(0, vel.z)
	if climb > 18 then
		force = force - Vector(0, 0, climb * mass * 0.55)
	end

	local cap = math.min(ent.MaxVel or 2500, 1750)
	local speed = vel:Length()
	if speed > cap then
		local over = speed / cap - 1
		force = force - vel:GetNormalized() * over * over * mass * 18
	end

	return vector_origin, force, SIM_GLOBAL_FORCE
end

function ZCFpv.SimulateMavic(ent, phys, dt)
	if ent.Dead or ent.ZCFpvNetTrapped or not ent:GetPowered() then
		return vector_origin, vector_origin, SIM_NOTHING
	end

	dt = math.min(math.max(dt, 0), 0.05)
	phys:Wake()

	local linked, _, fwd, side, up, boost = ent:ReadPilotInput()
	local ang = ent:GetAngles()
	local mass = phys:GetMass()
	local grav = mass * 600
	local vel = phys:GetVelocity()
	local jam = 1 / (1 + ent:GetNWFloat("ZCFpvJam", 0) * 6)
	ent.MavicYaw = ent.MavicYaw or ang.y

	if not linked then
		if not ent:GetHover() then
			ent:SetThrottleFrac(0)
			return vector_origin, vector_origin, SIM_NOTHING
		end

		ent:SetThrottleFrac(0.4)
		pushAngles(ent, phys, Angle(0, ent.MavicYaw, 0), dt, 36)

		local zErr = (ent.HoverZ or ent:GetPos().z) - ent:GetPos().z
		local force = Vector(0, 0, grav + zErr * 40 - vel.z * 8) - Vector(vel.x, vel.y, 0) * (mass * 1.4)
		return vector_origin, force, SIM_GLOBAL_FORCE
	end

	ent:SetThrottleFrac(math.Clamp(0.35 + math.abs(fwd) * 0.4 + math.abs(up) * 0.25 + (boost and 0.15 or 0), 0, 1))
	local yawRate = side * (boost and 75 or 48) * jam
	local scale = ent.SpeedScale or 1
	local speed = (boost and 790 or 550) * jam * scale
	local climb = (boost and 236 or 197) * scale
	ent.MavicYaw = ent.MavicYaw + yawRate * dt

	local maxTilt = boost and 22 or 14
	pushAngles(ent, phys, Angle(fwd * maxTilt, ent.MavicYaw, 0), dt, 34)

	if up ~= 0 then ent.HoverZ = ent:GetPos().z end
	local zErr = (ent.HoverZ or ent:GetPos().z) - ent:GetPos().z
	local wishZ = up ~= 0 and up * climb or math.Clamp(zErr * 2.2, -140, 140)
	local flat = Angle(0, ent.MavicYaw, 0):Forward() * fwd * speed
	local acc = Vector(flat.x - vel.x, flat.y - vel.y, wishZ - vel.z)
	acc.x = math.Clamp(acc.x, -260, 260)
	acc.y = math.Clamp(acc.y, -260, 260)
	acc.z = math.Clamp(acc.z, -180, 210)

	return vector_origin, Vector(0, 0, grav) + acc * mass, SIM_GLOBAL_FORCE
end

function ZCFpv.SimulatePlane(ent, phys, dt)
	if ent.Dead or ent.ZCFpvNetTrapped or not ent:GetPowered() or ent.CatapultMounted then
		return vector_origin, vector_origin, SIM_NOTHING
	end

	dt = math.min(math.max(dt, 0), 0.05)
	phys:Wake()

	local linked, _, fwd, side, _, boost = ent:ReadPilotInput()
	local ang = ent:GetAngles()
	local vel = phys:GetVelocity()
	local mass = phys:GetMass()
	local grav = mass * 600
	local stall = ent.StallSpeed or 650
	local jam = 1 / (1 + ent:GetNWFloat("ZCFpvJam", 0) * 6)
	local steering = ent.SteeringPower or 1
	local pitchRate, rollRate, yawRate = 0, 0, 0

	local guiding = ent.GeranAim
	local pMin, pMax, rMax = -25, 35, 55
	if guiding then
		local to = ent.GeranAim - ent:GetPos()
		if to:LengthSqr() > 40000 then
			local want = to:Angle()
			local yawErr = math.AngleDifference(want.y, ang.y)
			local pitchErr = math.AngleDifference(want.p, ang.p)
			local bankMax = ent.MaxBank or 65
			local bank = math.Clamp(-yawErr * 1.35, -bankMax, bankMax)
			rollRate = math.Clamp((bank - ang.r) * 3.2, -140, 140) * jam
			pitchRate = math.Clamp(pitchErr * 2.1, -90, 100) * jam
			yawRate = math.Clamp(yawErr * 0.2, -35, 35) * jam
		end
		ent.Thr = 1
		pMin, pMax, rMax = -28, 50, ent.MaxBank or 65
	elseif linked then
		local ply = ent:GetController()
		local rollStick, pitchStick = mouseStick(ply)
		pitchRate = pitchStick * 70 * jam
		rollRate = rollStick * 90 * jam * steering
		yawRate = side * 30 * jam
		local slew = boost and 0.32 or 0.16
		ent.Thr = math.Clamp((ent.Thr or 0.9) + fwd * slew * dt, 0.45, 1)
	else
		ent.Thr = ent.Thr or 0.9
		pitchRate = -ang.p * 1.4
		rollRate = -ang.r * 1.1
	end

	local forwardSpeed = math.max(vel:Dot(ang:Forward()), 0)
	local airspeed = math.Clamp(forwardSpeed / stall, 0, 1.6)
	local yawFromBank = -math.sin(math.rad(ang.r)) * (guiding and 52 or 42) * airspeed * steering
	if forwardSpeed > 200 then
		local damp = guiding and 0.45 or 0.75
		pitchRate = pitchRate - math.AngleDifference(ang.p, vel:Angle().p) * damp * airspeed
	end

	local cur = ent.TargetAng or ang
	local pitchStep = guiding and 70 or 40
	local rollStep = guiding and 90 or 50
	cur.p = math.ApproachAngle(cur.p, math.Clamp(cur.p + pitchRate * dt, pMin, pMax), pitchStep * dt)
	cur.r = math.ApproachAngle(cur.r, math.Clamp(cur.r + rollRate * dt, -rMax, rMax), rollStep * dt)
	cur.y = ang.y
	ent.TargetAng = cur
	local diff = ent:WorldToLocalAngles(cur)
	local angVel = phys:GetAngleVelocity()
	local rollPush = math.Clamp(diff.r * 16 * steering, -150, 150)
	local pitchPush = math.Clamp(diff.p * 14 * steering, -130, 130)
	local yawPush = yawRate + yawFromBank
	local angDamp = 0.08
	if guiding then
		rollPush = math.Clamp(diff.r * 18, -320, 320)
		pitchPush = math.Clamp(diff.p * 18, -420, 420)
		yawPush = yawPush * 1.25
		angDamp = 0.16
	end
	phys:AddAngleVelocity(Vector(rollPush, pitchPush, yawPush) * dt - angVel * angDamp)

	local thr = ent.Thr or 0.9
	ent:SetThrottleFrac(thr)
	local lift = math.Clamp((forwardSpeed / stall) ^ 2, 0, 1.08)
	local force = ang:Forward() * (ent.EngineForce or 180000) * thr
	force = force + ang:Up() * grav * lift
	force = force - vel * (mass * 0.06)
	force = force - ang:Right() * vel:Dot(ang:Right()) * mass * 1.5
	force = force - ang:Up() * vel:Dot(ang:Up()) * mass * 0.25
	force = softCap(force, vel, mass, ent.MaxVel or 2000)

	if ent.HardSpeedLimit then
		local speed = vel:Length()
		local maxVel = ent.MaxVel or 2000
		if speed > maxVel then
			vel = vel / speed * maxVel
			phys:SetVelocity(vel)
			speed = maxVel
		end
		if speed >= maxVel then
			local dir = vel:GetNormalized()
			local outward = force:Dot(dir)
			if outward > 0 then force = force - dir * outward end
		end
	end

	return vector_origin, force, SIM_GLOBAL_FORCE
end
