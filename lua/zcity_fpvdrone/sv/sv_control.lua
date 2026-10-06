ZCFpv = ZCFpv or {}

function ZCFpv.GetJamStrength(drone)
	if not IsValid(drone) then return 0 end

	local strength = 0
	for _, ent in ipairs(ents.FindInSphere(drone:GetPos(), 6000)) do
		if not ent.ZCFpvJammer or not ent:GetNWBool("ZCFpvJammerActive", true) then continue end

		local range = ent.JamDistance or 6000
		local full = ent.FullJamDistance or 2000
		local dist = drone:GetPos():Distance(ent:GetPos())
		local frac = 1 - math.Clamp((dist - full) / math.max(range - full, 1), 0, 1)
		strength = math.max(strength, frac)
	end

	return strength
end

function ZCFpv.EnsureViewCam(drone)
	if not IsValid(drone) then return nil end
	if IsValid(drone.ViewCam) then return drone.ViewCam end

	local pos, ang = drone:GetViewPosAng()
	local cam = ents.Create("prop_dynamic")
	if not IsValid(cam) then return nil end

	cam:SetModel("models/hunter/plates/plate.mdl")
	cam:SetModelScale(0)
	cam:SetPos(pos)
	cam:SetAngles(ang)
	cam:Spawn()
	cam:SetSolid(SOLID_NONE)
	cam:SetMoveType(MOVETYPE_NONE)
	cam:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	cam:SetNoDraw(true)
	cam:DrawShadow(false)
	cam:SetNotSolid(true)
	cam.ZCFpvCam = true
	cam:AddEFlags(EFL_DONTBLOCKLOS)

	drone.ViewCam = cam
	return cam
end

function ZCFpv.DestroyViewCam(drone)
	if not IsValid(drone) then return end
	if IsValid(drone.ViewCam) then
		drone.ViewCam:Remove()
	end
	drone.ViewCam = nil
end

function ZCFpv.SyncViewCam(drone)
	if not IsValid(drone) or not IsValid(drone.ViewCam) then return end
	local pos, ang = drone:GetViewPosAng()
	if drone.FixedWing then
		ang = drone:GetAngles()
		pos = drone:LocalToWorld(Vector(drone:OBBMaxs().x + 1, 0, 2))
	elseif not drone.CamOffset then
		pos = pos - ang:Forward() * 3.5 + ang:Up() * 2
	end
	drone.ViewCam:SetPos(pos)
	drone.ViewCam:SetAngles(ang)
end

local fiberDrops = {}
local fiberMax = 15000 * 39.37

local function fiberHand(ply, drone)
	if not IsValid(ply) then return drone.FiberHand or drone:GetPos() end
	local bone = ply:LookupBone("ValveBiped.Bip01_R_Hand")
	if bone then
		local pos = ply:GetBonePosition(bone)
		if isvector(pos) then return pos end
	end
	return ply:EyePos()
end

local function clearLiveFiber(drone)
	if IsValid(drone.FiberTie) then drone.FiberTie:Remove() end
	if IsValid(drone.FiberRope) then drone.FiberRope:Remove() end
	if IsValid(drone.FiberAnchor) then drone.FiberAnchor:Remove() end
	drone.FiberTie = nil
	drone.FiberRope = nil
	drone.FiberAnchor = nil
	drone.FiberTied = nil
end

local function tieFiber(drone)
	local anchor = drone.FiberAnchor
	if not IsValid(anchor) or not IsValid(drone) then return end
	if IsValid(drone.FiberTie) then drone.FiberTie:Remove() end
	local len = math.max(drone.FiberLen or 300, 64)
	drone.FiberTie = constraint.Rope(anchor, drone, 0, 0, vector_origin, Vector(-12, 0, 1), len, 0, 500, 0, "", false)
	drone.FiberTied = IsValid(drone.FiberTie)
end

local function spawnChain(from, to, count)
	local nodes = {}
	count = math.max(count, 2)
	for i = 1, count do
		local frac = (i - 1) / (count - 1)
		local prop = ents.Create("prop_physics")
		if not IsValid(prop) then continue end
		prop:SetModel("models/hunter/blocks/cube025x025x025.mdl")
		prop:SetPos(LerpVector(frac, from, to) + Vector(0, 0, 6))
		prop:Spawn()
		prop:SetNoDraw(true)
		prop:DrawShadow(false)
		prop:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		local phys = prop:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(2)
			phys:Wake()
		end
		nodes[#nodes + 1] = prop
	end
	for i = 1, #nodes - 1 do
		local a, b = nodes[i], nodes[i + 1]
		local len = a:GetPos():Distance(b:GetPos())
		constraint.Rope(a, b, 0, 0, vector_origin, vector_origin, math.max(len, 8), 28, 0, 0.2, "zc_fiber/cable", false, Color(12, 12, 12))
	end
	return nodes
end

local function keepDrop(nodes)
	if #nodes == 0 then return end
	fiberDrops[#fiberDrops + 1] = nodes
	while #fiberDrops > 3 do
		local old = table.remove(fiberDrops, 1)
		for i = 1, #old do
			if IsValid(old[i]) then old[i]:Remove() end
		end
	end
	timer.Simple(6, function()
		for i = 1, #nodes do
			local ent = nodes[i]
			if not IsValid(ent) then continue end
			local phys = ent:GetPhysicsObject()
			if IsValid(phys) then phys:EnableMotion(false) end
		end
	end)
	timer.Simple(math.Rand(180, 240), function()
		for i = 1, #nodes do
			if IsValid(nodes[i]) then nodes[i]:Remove() end
		end
	end)
end

function ZCFpv.DropFiber(drone)
	if not IsValid(drone) or not drone.Fiber or drone.FiberDropped then return end
	if not IsValid(drone.FiberRope) and not IsValid(drone.FiberAnchor) then return end
	drone.FiberDropped = true

	local ply = drone.FiberPly
	local hand = fiberHand(ply, drone)
	local tip = drone:GetPos()
	clearLiveFiber(drone)

	local nodes = {}
	local function take(list)
		for i = 1, #list do
			nodes[#nodes + 1] = list[i]
		end
	end
	local dist = hand:Distance(tip)
	if dist < 500 then
		take(spawnChain(hand, tip, 4))
	else
		local dir = (tip - hand):GetNormalized()
		take(spawnChain(hand, hand - Vector(0, 0, 48) + dir * 70, 3))
		take(spawnChain(tip, tip - dir * math.min(dist, 1600), 8))
	end
	keepDrop(nodes)
	drone:EmitSound("physics/rubber/rubber_tire_impact_soft2.wav", 68, 90)
end

function ZCFpv.SnapFiber(drone, ply)
	if not IsValid(drone) or drone.FiberDropped or drone.Dead then return end
	ZCFpv.DropFiber(drone)
	drone:SetSignal(0)
	local ctl = IsValid(ply) and ply or drone:GetController()
	if not IsValid(ctl) or not drone:GetLinked() then return end
	net.Start("zc_fpv_hit")
		net.WriteBool(true)
	net.Send(ctl)
	ZCFpv.StopControl(ctl)
end

function ZCFpv.ThinkFiber(drone, ply, dist)
	if not IsValid(drone) or drone.FiberDropped or drone.Dead then return end
	if not IsValid(drone.FiberAnchor) then return end
	local hand = fiberHand(ply, drone)
	drone.FiberHand = hand
	local phys = drone.FiberAnchor:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetPos(hand)
		phys:EnableMotion(false)
	else
		drone.FiberAnchor:SetPos(hand)
	end

	if dist >= fiberMax or (drone.FiberTied and not IsValid(drone.FiberTie)) then
		ZCFpv.SnapFiber(drone, ply)
		return
	end

	local over = dist - (drone.FiberLen or dist)
	if over > 650 then
		ZCFpv.SnapFiber(drone, ply)
		return
	end

	local want = math.min(dist + 900, fiberMax)
	if not drone.FiberTied or want > (drone.FiberLen or 0) + 800 then
		drone.FiberLen = want
		tieFiber(drone)
	end
end

local function attachFiber(ply, drone)
	if not drone.Fiber or drone.FiberDropped then return end
	if IsValid(drone.FiberRope) then return end
	drone.FiberPly = ply
	local bone = ply:LookupBone("ValveBiped.Bip01_R_Hand") or 0
	local hand = fiberHand(ply, drone)
	drone.FiberHand = hand
	drone.FiberLen = hand:Distance(drone:GetPos()) + 900

	local anchor = ents.Create("prop_physics")
	if IsValid(anchor) then
		anchor:SetModel("models/hunter/plates/plate.mdl")
		anchor:SetPos(hand)
		anchor:Spawn()
		anchor:SetNoDraw(true)
		anchor:DrawShadow(false)
		anchor:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
		local phys = anchor:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
			phys:SetPos(hand)
		end
		drone.FiberAnchor = anchor
		tieFiber(drone)
	end

	local rope = constraint.CreateKeyframeRope(drone:GetPos(), 0.2, "zc_fiber/cable", nil, ply, vector_origin, bone, drone, Vector(-12, 0, 1), 0, {
		Slack = 140,
		Collide = 0,
		Type = 0,
		Subdiv = 7,
		TextureScale = 2,
	})
	if not IsValid(rope) then return end
	rope:SetColor(Color(8, 8, 8))
	drone.FiberRope = rope
end

function ZCFpv.StartControl(ply, drone)
	if not IsValid(ply) or not ZCFpv.IsDrone(drone) then return false end
	if not ply:Alive() then return false end
	if ply.organism and ply.organism.otrub then return false end
	if IsValid(ply.FakeRagdoll) then return false end
	if drone:GetOwner() ~= ply then return false end
	if drone.Dead or drone.ZCFpvNetTrapped then return false end
	if not drone:GetPowered() then return false end

	local old = ZCFpv.GetLinkedDrone(ply)
	if IsValid(old) and old ~= drone then
		ZCFpv.StopControl(ply)
	end

	if drone.Strike then
		local eye = ply:EyeAngles()
		ply:SetEyeAngles(Angle(0, eye.y, 0))
	end

	drone:SetController(ply)
	drone:SetLinked(true)
	drone.ControlEyeAng = ply:EyeAngles()
	drone.ControlBaseAng = Angle(0, drone:GetAngles().y, 0)
	drone.PilotYaw = drone:GetAngles().y
	drone.TiltRoll = 0
	drone.LastEyeYaw = drone.ControlEyeAng.y
	drone.Thr = nil
	drone.Nose = 0
	drone.Bank = 0
	drone.Heading = drone:GetAngles().y
	if not drone.FixedWing and not drone.Stable then
		drone:SetHover(false)
	end
	ply.ZCFpvFeedLost = nil
	drone.TargetAng = Angle(0, drone:GetAngles().y, 0)
	drone.MavicYaw = drone:GetAngles().y
	drone.HoverZ = drone:GetPos().z
	drone.LaunchBoostUntil = 0

	local phys = drone:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(true)
		phys:Wake()
	end

	ply:SetNWEntity("ZCFpvDrone", drone)
	ply:SetNWAngle("ZCFpvBodyAng", Angle(0, ply:EyeAngles().y, 0))
	ply.ZCFpvLinked = drone
	ply.ZCFpvLockPos = ply:GetPos()
	ply:SetLocalVelocity(vector_origin)

	local cam = ZCFpv.EnsureViewCam(drone)
	ZCFpv.SyncViewCam(drone)
	if IsValid(cam) then
		ply:SetViewEntity(cam)
	else
		ply:SetViewEntity(drone)
	end

	net.Start("zc_fpv_link")
		net.WriteBool(true)
		net.WriteEntity(drone)
	net.Send(ply)

	attachFiber(ply, drone)
	return true
end

function ZCFpv.StopControl(ply, silent)
	if not IsValid(ply) then return end

	local drone = ply.ZCFpvLinked or ZCFpv.GetLinkedDrone(ply)
	ply.ZCFpvLinked = nil
	ply.ZCFpvLockPos = nil
	ply.ZCFpvButtons = nil
	ply:SetNWEntity("ZCFpvDrone", NULL)
	ply:SetViewEntity(NULL)

	if ZCFpv.IsDrone(drone) then
		drone:SetLinked(false)
		drone:SetController(NULL)
		drone.ControlEyeAng = nil
		drone.ControlBaseAng = nil

		local phys = drone:GetPhysicsObject()
		if drone.Stable and drone:GetPowered() then
			drone:SetHover(true)
			drone.HoverZ = drone:GetPos().z
			drone.MavicYaw = drone:GetAngles().y
			drone.TargetAng = Angle(0, drone.MavicYaw, 0)
		elseif drone.Strike then
			drone:SetHover(false)
			drone.MavicYaw = nil
		end

		if IsValid(phys) then phys:Wake() end
		ZCFpv.DestroyViewCam(drone)
	end

	if not silent then
		net.Start("zc_fpv_link")
			net.WriteBool(false)
			net.WriteEntity(NULL)
		net.Send(ply)
	end
end

function ZCFpv.ClearOwned(ply)
	ply.ZCFpvOwned = nil
	local list = {}
	for _, ent in ipairs(ents.FindByClass("ent_zc_fpv_*")) do
		if ZCFpv.IsDrone(ent) and ent:GetOwner() == ply and not ent.Dead then
			list[#list + 1] = ent
		end
	end
	for _, ent in ipairs(list) do
		if not IsValid(ent) or ent.Dead then continue end
		if ent:GetLinked() then ZCFpv.StopControl(ply) end
		ent:Break()
	end
end

local function shouldDrop(ply)
	if not IsValid(ply) then return true end
	if not ply:Alive() then return true end
	if ply.organism and ply.organism.otrub then return true end
	if IsValid(ply.FakeRagdoll) then return true end
	return false
end

local function clearFeed(ply)
	ply.ZCFpvFeedLost = nil
	ply.ZCFpvLockPos = nil
end

hook.Add("PlayerDeath", "ZCFpv_Death", function(ply)
	clearFeed(ply)
	ZCFpv.StopControl(ply)
end)

hook.Add("PlayerDisconnected", "ZCFpv_DC", function(ply)
	clearFeed(ply)
	ZCFpv.StopControl(ply, true)
	ZCFpv.ClearOwned(ply)
end)

hook.Add("PlayerSilentDeath", "ZCFpv_SilentDeath", function(ply)
	clearFeed(ply)
	ZCFpv.StopControl(ply)
end)

hook.Add("PlayerSpawn", "ZCFpv_Spawn", function(ply)
	clearFeed(ply)
	ZCFpv.StopControl(ply)
end)

hook.Add("Think", "ZCFpv_Organism", function()
	for _, ply in ipairs(player.GetAll()) do
		if ply.ZCFpvFeedLost and (shouldDrop(ply) or CurTime() > (ply.ZCFpvFeedLostAt or 0) + 2.5) then
			clearFeed(ply)
		end
		if not ply.ZCFpvLinked then continue end
		if shouldDrop(ply) then
			ZCFpv.StopControl(ply)
		end
	end
end)

net.Receive("zc_fpv_feed_clear", function(_, ply)
	if not IsValid(ply) or not ply.ZCFpvFeedLost then return end
	if CurTime() < (ply.ZCFpvFeedLostAt or 0) + 1 then return end
	if CurTime() < (ply.ZCFpvFeedClearNext or 0) then return end
	ply.ZCFpvFeedClearNext = CurTime() + 0.2
	clearFeed(ply)
end)

net.Receive("zc_fpv_geran_aim", function(_, ply)
	if not IsValid(ply) then return end
	local drone = ply.ZCFpvLinked
	if not IsValid(drone) or drone:GetClass() ~= "ent_zc_fpv_geran2" or drone.Dead then return end
	if CurTime() < (drone.NextGeranAim or 0) then return end
	drone.NextGeranAim = CurTime() + 0.12

	local on = net.ReadBool()
	if not on then
		drone.GeranAim = nil
		drone:SetNWBool("ZCFpvGeranHasAim", false)
		return
	end

	local pos = net.ReadVector()
	if pos:DistToSqr(drone:GetPos()) > 300000 * 300000 then return end
	drone.GeranAim = pos
	drone:SetNWBool("ZCFpvGeranHasAim", true)
	drone:SetNWVector("ZCFpvGeranAim", pos)
end)

hook.Add("StartCommand", "ZCFpv_Freeze", function(ply, cmd)
	if not ply.ZCFpvLinked and not ply.ZCFpvFeedLost then return end
	ply.ZCFpvButtons = cmd:GetButtons()
	ply.ZCFpvMouseX = cmd:GetMouseX()
	ply.ZCFpvMouseY = cmd:GetMouseY()
	local drone = ply.ZCFpvLinked
	local block = bit.bor(IN_JUMP, IN_DUCK)
	if IsValid(drone) and drone:GetClass() == "ent_zc_fpv_geran2" then
		block = bit.bor(block, IN_ATTACK, IN_ATTACK2)
	end
	cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(block)))
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)
	cmd:SetUpMove(0)
end)

hook.Add("SetupMove", "ZCFpv_Freeze", function(ply, mv)
	if not ply.ZCFpvLinked and not ply.ZCFpvFeedLost then return end
	mv:SetMaxClientSpeed(0)
	mv:SetMaxSpeed(0)
	mv:SetForwardSpeed(0)
	mv:SetSideSpeed(0)
	mv:SetUpSpeed(0)
	mv:SetVelocity(vector_origin)
	if ply.ZCFpvLockPos then
		mv:SetOrigin(ply.ZCFpvLockPos)
	end
end)

hook.Add("Move", "ZCFpv_Freeze", function(ply, mv)
	if not ply.ZCFpvLinked and not ply.ZCFpvFeedLost then return end
	mv:SetVelocity(vector_origin)
	if ply.ZCFpvLockPos then
		mv:SetOrigin(ply.ZCFpvLockPos)
	end
end)

local pvsForward = {512, 1024, 2048, 4096, 8192}
local pvsForwardLong = {512, 1024, 2048, 4096, 8192, 16384, 32768}
local pvsMavic = {4096, 8192, 16384, 32768, 65536, 98304}
local pvsAround = {1024, 2048}

hook.Add("SetupPlayerVisibility", "ZCFpv_PVS", function(ply, viewEnt)
	local drone = ply.ZCFpvLinked
	if not IsValid(drone) then return end

	local origin = IsValid(viewEnt) and viewEnt:GetPos() or drone:GetPos()
	if IsValid(drone.ViewCam) then origin = drone.ViewCam:GetPos() end

	local ang = drone:GetAngles()
	if drone.Stable and drone.ControlEyeAng then
		ang = Angle(0, ang.y + math.AngleDifference(ply:EyeAngles().y, drone.ControlEyeAng.y), 0)
	end

	local fwd, right, up = ang:Forward(), ang:Right(), ang:Up()
	AddOriginToPVS(ply:GetPos())
	AddOriginToPVS(drone:GetPos())
	AddOriginToPVS(origin)

	if drone:GetClass() == "ent_zc_fpv_mavic" then
		for _, dist in ipairs(pvsMavic) do
			AddOriginToPVS(origin + fwd * dist)
			AddOriginToPVS(origin - fwd * dist)
			AddOriginToPVS(origin + right * dist)
			AddOriginToPVS(origin - right * dist)
		end
		AddOriginToPVS(origin - Vector(0, 0, 8000))
		AddOriginToPVS(origin - Vector(0, 0, 16000))
	else
		for _, dist in ipairs((drone.SignalRangeMul or 1) > 1 and pvsForwardLong or pvsForward) do
			AddOriginToPVS(origin + fwd * dist)
		end

		for _, dist in ipairs(pvsAround) do
			AddOriginToPVS(origin - fwd * dist)
			AddOriginToPVS(origin + right * dist)
			AddOriginToPVS(origin - right * dist)
			AddOriginToPVS(origin + up * dist)
			AddOriginToPVS(origin - up * dist)
		end
	end
end)
