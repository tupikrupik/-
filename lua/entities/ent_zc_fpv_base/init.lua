AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	local cfg
	if ZCFpv and ZCFpv.Types then
		for _, v in pairs(ZCFpv.Types) do
			if v.class == self:GetClass() then
				cfg = v
				break
			end
		end
	end
	if cfg then
		self.DroneModel = cfg.model
		self.IdleSound = cfg.sound
		self.MaxHP = cfg.maxHealth
		self.MaxVel = cfg.maxVelocity
		self.Mass = cfg.mass
		self.Thrust = cfg.thrust
		self.TurnRate = cfg.turnRate
		self.HoverForce = cfg.hoverForce
		self.Strike = cfg.strike
		self.SignalRangeMul = cfg.signalRangeMultiplier or self.SignalRangeMul
		self.CollideDetonate = cfg.collideDetonateSpeed or self.CollideDetonate
		self.CollideBreak = cfg.collideBreakSpeed or self.CollideBreak
	end
	self:SetModel(self.DroneModel or "models/sw/avia/crocus/crocus_pg7.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:SetUseType(SIMPLE_USE)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:SetMass(self.Mass or 8)
		phys:EnableGravity(true)
		phys:EnableDrag(true)
		phys:SetAngleDragCoefficient(4)
		phys:SetDamping(0.4, 0.8)
	end
	self:StartMotionController()
	self:SetHealth(self.MaxHP or 5)
	self:SetMaxHealth(self.MaxHP or 5)
	self:SetLinked(false)
	self:SetHover(false)
	self:SetPowered(false)
	self:SetSignal(0)
	self.Dead = false
	self.NextSignal = 0
	self.HoverZ = self:GetPos().z
	self.TargetAng = self:GetAngles()
	self.Throttle = 0
	self.WasReload = false
	self.LastImpactPos = self:GetPos()
end

function ENT:SetPower(on)
	if self.WaterDead then return end
	on = on and true or false
	if self:GetPowered() == on then return end
	self:SetPowered(on)
	self:SetHover(on)
	self:SetSignal(on and 1 or 0)
	self.HoverZ = self:GetPos().z
	self.TargetAng = self:GetAngles()
	self.Throttle = 0
	self:SetThrottleFrac(0)
	self.LastImpactPos = self:GetPos()
	self.LaunchBoostUntil = on and CurTime() + 1.25 or 0
	if on then
		self.LaunchSafeUntil = CurTime() + 1
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(true)
			phys:Wake()
		end
		return
	end
	if self:GetLinked() then
		local ply = self:GetController()
		if IsValid(ply) then ZCFpv.StopControl(ply) end
	end
end

function ENT:Use(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	if self.Dead or self.WaterDead or self.ZCFpvNetTrapped then return end
	local wep = ply:GetActiveWeapon()
	if self.DropPayload and IsValid(wep) and wep.ENT == "ent_hg_grenade_rgd5" and not self:GetNWBool("ZCFpvRGD") then return end
	if CurTime() < (self.NextPowerUse or 0) then return end
	local owner = self:GetOwner()
	if IsValid(owner) and owner ~= ply then return end
	if not IsValid(owner) then self:SetOwner(ply) end
	self.NextPowerUse = CurTime() + 0.5
	self:SetPower(not self:GetPowered())
	self:EmitSound(self:GetPowered() and "buttons/button14.wav" or "buttons/button19.wav", 55, self:GetPowered() and 115 or 90)
end

function ENT:OnRemove()
	if ZCFpv.DropFiber then ZCFpv.DropFiber(self) end
	ZCFpv.DestroyViewCam(self)
	if IsValid(self.PayloadGrenade) then self.PayloadGrenade:Remove() end
	local owner = self:GetOwner()
	if IsValid(owner) and owner.ZCFpvOwned == self then
		owner.ZCFpvOwned = nil
	end
	if self:GetLinked() then
		local ctl = self:GetController()
		if IsValid(ctl) then
			ZCFpv.StopControl(ctl)
		end
	end
end

function ENT:CheckPlayerImpact()
	local pos = self:GetPos()
	local old = self.LastImpactPos or pos
	self.LastImpactPos = pos
	if old:DistToSqr(pos) < 1 then return false end
	local owner = self:GetOwner()
	local tr = util.TraceHull({
		start = old,
		endpos = pos,
		mins = Vector(-5, -5, -5),
		maxs = Vector(5, 5, 5),
		filter = {self, owner, self.ViewCam},
		mask = MASK_SHOT,
		collisiongroup = COLLISION_GROUP_NONE,
	})
	local hit = tr.Entity
	if not IsValid(hit) or not hit:IsPlayer() then return false end
	if self.Strike then
		self:Detonate(true)
		return true
	end
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		local vel = phys:GetVelocity()
		local dir = vel:GetNormalized()
		self:SetPos(tr.HitPos - dir * 6)
		phys:SetVelocity(-vel * 0.15)
		if vel:Length() >= (self.CollideBreak or 400) then
			self:TakeDroneDamage(vel:Length() / 20)
		end
	end

	return true
end

function ENT:Think()
	if self.Dead then return end
	if self.ZCFpvNetTrapped then
		self:NextThink(CurTime() + 0.1)
		return true
	end
	if self:GetNWBool("ZCFpvRGD") and not IsValid(self.PayloadGrenade) then
		self:SetNWEntity("ZCFpvPayload", NULL)
		self:SetNWBool("ZCFpvRGD", false)
	end
	local inWater = self:WaterLevel() > 0 or bit.band(util.PointContents(self:GetPos()), CONTENTS_WATER) ~= 0
	if inWater and not self.WaterDead then
		self.WaterDead = true
		self.WaterBreakAt = CurTime() + math.Rand(3, 5)
		self:SetPowered(false)
		self:SetHover(false)
		self:SetThrottleFrac(0)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(true)
			phys:EnableGravity(true)
			phys:Wake()
		end
	end
	if self.WaterDead then
		local ply = self:GetController()
		if IsValid(ply) and self:GetLinked() then
			ZCFpv.SyncViewCam(self)
		end
		if CurTime() >= (self.WaterBreakAt or 0) then
			if IsValid(ply) and self:GetLinked() then
				net.Start("zc_fpv_hit")
					net.WriteBool(true)
				net.Send(ply)
			end
			self:Crash()
		end
		self:NextThink(CurTime())
		return true
	end
	if not self:GetPowered() then
		self.LastImpactPos = self:GetPos()
		self:NextThink(CurTime())
		return true
	end
	if self:CheckPlayerImpact() then return end
	if CurTime() >= (self.NextAdrenaline or 0) then
		self.NextAdrenaline = CurTime() + 1
		local pos = self:GetPos()
		for _, ply in ipairs(player.GetAll()) do
			local org = ply.organism
			if not ply:Alive() or not org or (org.adrenaline or 0) >= 2.5 then continue end
			local dist = ply:WorldSpaceCenter():Distance(pos)
			if dist > 1400 then continue end
			local frac = 1 - dist / 1400
			if ply.AddNaturalAdrenaline then
				ply:AddNaturalAdrenaline(0.01 + frac * 0.035)
			else
				org.adrenalineAdd = (org.adrenalineAdd or 0) + 0.01 + frac * 0.035
			end
		end
	end
	if CurTime() >= (self.NextSignal or 0) then
		self.NextSignal = CurTime() + (ZCFpv.SignalCheckInterval or 0.2)
		self:UpdateSignal()
	end
	local ply = self:GetController()
	if IsValid(ply) and self:GetLinked() then
		ZCFpv.SyncViewCam(self)

		if not self.FixedWing then
			local down = ply:KeyDown(IN_RELOAD)
			if down and not self.WasReload then
				self:SetHover(not self:GetHover())
				if self:GetHover() then
					self.HoverZ = self:GetPos().z
				end
			end
			self.WasReload = down
		end

		local attack = bit.band(ply.ZCFpvButtons or 0, IN_ATTACK) ~= 0
		if attack and not self.WasPayloadAttack and self.ReleasePayload then
			self:ReleasePayload(ply)
		end
		self.WasPayloadAttack = attack
	else
		self.WasReload = false
		self.WasPayloadAttack = false
	end

	self:NextThink(CurTime())
	return true
end

function ENT:UpdateSignal()
	local owner = self:GetOwner()
	if not IsValid(owner) then
		self:SetSignal(0)
		self:SetNWFloat("ZCFpvJam", 0)
		if self:GetLinked() then
			local ctl = self:GetController()
			if IsValid(ctl) then ZCFpv.StopControl(ctl) end
		end
		return
	end
	local dist = owner:GetPos():Distance(self:GetPos())
	if self.Fiber then
		self:SetNWFloat("ZCFpvJam", 0)
		self:SetNWFloat("ZCFpvCableM", dist / 39.37)
		self.JamDropAt = nil
		if ZCFpv.ThinkFiber then ZCFpv.ThinkFiber(self, owner, dist) end
		if not self.FiberDropped then self:SetSignal(1) end
		return
	end
	local rangeMul = self.SignalRangeMul or 1
	local range = (ZCFpv.SignalRange or 11000) * rangeMul
	local grace = (ZCFpv.SignalGrace or 3500) * rangeMul
	local hard = range + grace
	local mavic = self:GetClass() == "ent_zc_fpv_mavic"
	local frac
	if dist <= range then
		local t = dist / range
		if mavic then
			local knee = math.Clamp((t - 0.5) / 0.5, 0, 1)
			frac = math.Clamp(1 - (knee ^ 1.2) * 0.95, 0.05, 1)
		else
			frac = math.Clamp(1 - (t ^ 1.35) * 0.85, 0.12, 1)
		end
	elseif dist <= hard then
		local g = (dist - range) / grace
		local base = mavic and 0.05 or 0.12
		frac = math.Clamp(base * (1 - g * g), 0.01, base)
	else
		frac = 0
	end
	local tr = util.TraceLine({
		start = owner:EyePos(),
		endpos = self:GetPos(),
		filter = {owner, self, self.ViewCam},
		mask = MASK_SOLID_BRUSHONLY,
	})
	if tr.Hit and not self.Fiber then
		frac = frac * (mavic and 0.62 or 0.82)
	end

	local jam = 0
	if not self.Fiber then
		jam = ZCFpv.GetJamStrength and ZCFpv.GetJamStrength(self) or 0
	end
	self:SetNWFloat("ZCFpvJam", jam)
	if not self.Fiber then
		frac = frac * (1 - jam * jam * jam * 0.94)
	end
	self.SignalSmooth = self.SignalSmooth or frac
	self.SignalSmooth = Lerp(0.25, self.SignalSmooth, frac)
	self:SetSignal(self.SignalSmooth)
	if self:GetLinked() and dist > hard then
		ZCFpv.StopControl(owner)
		if self.Strike then self:SetHover(false) end
	end
	if jam >= 0.98 and self:GetLinked() then
		self.JamDropAt = self.JamDropAt or CurTime() + 1.25
		if CurTime() >= self.JamDropAt then
			ZCFpv.StopControl(owner)
			if self.Strike then self:SetHover(false) end
		end
	else
		self.JamDropAt = nil
	end
end

function ENT:ReadPilotInput()
	local ply = self:GetController()
	if not IsValid(ply) or not self:GetLinked() then
		return false, Angle(0, 0, 0), 0, 0, 0, false
	end
	local buttons = ply.ZCFpvButtons or 0
	local eye = ply:EyeAngles()
	local fwd = (bit.band(buttons, IN_FORWARD) ~= 0 and 1 or 0) - (bit.band(buttons, IN_BACK) ~= 0 and 1 or 0)
	local side = (bit.band(buttons, IN_MOVELEFT) ~= 0 and 1 or 0) - (bit.band(buttons, IN_MOVERIGHT) ~= 0 and 1 or 0)
	local rise = bit.band(buttons, IN_JUMP) ~= 0 or (self.Strike and bit.band(buttons, IN_ATTACK) ~= 0)
	local up = (rise and 1 or 0) - (bit.band(buttons, IN_DUCK) ~= 0 and 1 or 0)
	return true, eye, fwd, side, up, bit.band(buttons, IN_SPEED) ~= 0
end

function ENT:PhysicsSimulate(phys, dt)
	if self.Stable or self:GetClass() == "ent_zc_fpv_mavic" then
		return ZCFpv.SimulateMavic(self, phys, dt)
	end
	return ZCFpv.SimulateQuad(self, phys, dt)
end

function ENT:PhysicsCollide(data)
	if self.Crashing then
		if not self.CrashHit and (data.Speed or 0) > 100 then
			self.CrashHit = true
			self:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(1, 3) .. ".wav", 75, math.random(90, 110))

			local ed = EffectData()
			ed:SetOrigin(data.HitPos)
			ed:SetNormal(data.HitNormal)
			ed:SetMagnitude(1)
			ed:SetScale(1)
			util.Effect("Sparks", ed, true, true)
		end
		return
	end
	if CurTime() < (self.LaunchSafeUntil or 0) then return end
	if self.Dead or not self:GetPowered() then return end
	local speed = data.Speed or 0
	local hit = data.HitEntity
	if IsValid(hit) and hit.ZCFpvAntiNet then
		hit:CatchDrone(self)
		return
	end
	if IsValid(hit) and (hit == self:GetOwner() or hit == self:GetController() or hit.ZCFpvCam) and speed < (self.CollideDetonate or 200) then
		return
	end
	if self.Strike then
		if speed >= (self.CollideDetonate or 200) or (IsValid(hit) and not hit:IsWorld()) then
			if self.DetonateQueued then return end
			self.DetonateQueued = true
			timer.Simple(0, function()
				if not IsValid(self) then return end
				self:Detonate(true)
			end)
			return
		end
	else
		if speed >= (self.CollideBreak or 400) then
			self:TakeDroneDamage(speed / 20)
		end
	end
end

function ENT:OnTakeDamage(dmg)
	if self.Dead then return end
	if self.LiveCharge and dmg:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then
		self:Detonate()
		return
	end
	self:TakeDroneDamage(dmg:GetDamage())
end

function ENT:TakeDroneDamage(amt)
	if self.Dead then return end
	local hp = self:Health() - amt
	self:SetHealth(hp)
	if hp <= 0 then
		if self:GetClass() == "ent_zc_fpv_mavic" or self.Strike and math.Rand(0, 1) <= 0.4 then
			self:Crash()
		elseif self.Strike then
			self:Detonate()
		else
			self:Crash()
		end
	end
end

function ENT:Crash()
	if self.Dead then return end
	if ZCFpv.DropFiber then ZCFpv.DropFiber(self) end
	self.Dead = true
	self.Crashing = true
	self:SetHealth(0)
	self:SetPowered(false)
	self:SetHover(false)
	self:SetSignal(0)

	local ctl = self:GetController()
	if IsValid(ctl) then ZCFpv.StopControl(ctl) end

	local owner = self:GetOwner()
	if IsValid(owner) and owner.ZCFpvOwned == self then
		owner.ZCFpvOwned = nil
	end

	timer.Simple(0, function()
		if not IsValid(self) then return end
		self:StopMotionController()
		local phys = self:GetPhysicsObject()
		if not IsValid(phys) then return end
		phys:EnableMotion(true)
		phys:EnableGravity(true)
		phys:Wake()
		phys:AddAngleVelocity(VectorRand() * 180)
	end)

	timer.Simple(20, function()
		if IsValid(self) then self:Remove() end
	end)
end

function ENT:Detonate(contact)
	if self.Dead then return end
	if ZCFpv.DropFiber then ZCFpv.DropFiber(self) end
	self.Dead = true
	local ctl = self:GetController()
	if IsValid(ctl) then
		if contact then
			net.Start("zc_fpv_hit")
				net.WriteBool(false)
			net.Send(ctl)
		end
		ZCFpv.StopControl(ctl)
		if contact then
			ctl.ZCFpvFeedLost = true
			ctl.ZCFpvFeedLostAt = CurTime()
			ctl.ZCFpvLockPos = ctl:GetPos()
		end
	end
	self:OnDetonate()
end

function ENT:OnDetonate()
	local cfg
	if ZCFpv and ZCFpv.Types then
		for _, v in pairs(ZCFpv.Types) do
			if v.class == self:GetClass() then
				cfg = v
				break
			end
		end
	end

	if self.Heat and cfg and cfg.heatDamage then
		local pos = self:GetPos()
		local ang = self:GetAngles()
		local owner = self:GetOwner()
		local attacker = IsValid(owner) and owner or self
		local heatLen = cfg.heatLength or 180
		local heatHull = math.max(cfg.heatHull or 2, 12)
		local fwd, right, up = ang:Forward(), ang:Right(), ang:Up()
		local rays = {
			fwd,
			(fwd + right * 0.22):GetNormalized(),
			(fwd - right * 0.22):GetNormalized(),
			(fwd + up * 0.22):GetNormalized(),
			(fwd - up * 0.22):GetNormalized(),
		}
		local hit = {}
		local mins, maxs = Vector(-heatHull, -heatHull, -heatHull), Vector(heatHull, heatHull, heatHull)
		for i = 1, #rays do
			local tr = util.TraceHull({
				start = pos,
				endpos = pos + rays[i] * heatLen,
				mins = mins,
				maxs = maxs,
				filter = self,
				mask = MASK_SHOT,
			})
			local ent = tr.Entity
			if not IsValid(ent) or hit[ent] then continue end
			hit[ent] = true
			local dmg = DamageInfo()
			dmg:SetDamage(cfg.heatDamage)
			dmg:SetAttacker(attacker)
			dmg:SetInflictor(self)
			dmg:SetDamageType(bit.bor(DMG_BLAST, DMG_CLUB))
			dmg:SetDamageForce(rays[i] * (cfg.heatForce or 50000))
			dmg:SetDamagePosition(tr.HitPos)
			ent:TakeDamageInfo(dmg)
		end
		self:FireBullets({
			Attacker = attacker,
			Damage = cfg.heatDamage * 0.35,
			Force = (cfg.heatForce or 50000) * 0.02,
			Dir = fwd,
			Src = pos,
			Tracer = 0,
			HullSize = heatHull,
			Distance = heatLen,
			IgnoreEntity = self,
			Spread = Vector(0.04, 0.04, 0),
			Num = 5,
		})
	end

	if cfg and cfg.expType then
		if not self:HgBoom(cfg.expType, cfg.expForce, cfg.expMass) then
			self:Break(true)
		end
		return
	end
	self:Break(true)
end

function ENT:HgBoom(expType, force, mass)
	if self.HasExploded then return true end
	if not hg or not hg.PropExplosion then return false end
	local owner = self:GetOwner()
	self.owner = IsValid(owner) and owner or self
	if math.Rand(0, 1) <= 0.25 and CreateVFire then
		local pos = self:GetPos()
		local tr = util.QuickTrace(pos, Vector(0, 0, -180), {self})
		local hit = tr.Hit and tr.HitPos or pos
		local normal = tr.Hit and tr.HitNormal or vector_up
		local fire = CreateVFire(game.GetWorld(), hit, normal, 8, self.owner)
		if IsValid(fire) then fire:ChangeLife(12) end
		CreateVFireBall(12, 6, hit + normal * 8, vector_up * 90 + VectorRand() * 30, self.owner)
	end
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_NONE)
	hg.PropExplosion(self, expType or "Normal", force or 40, mass or 10)
	return true
end

function ENT:Break(silent)
	if self.Removing then return end
	if ZCFpv.DropFiber then ZCFpv.DropFiber(self) end
	self.Removing = true
	self.Dead = true
	local ctl = self:GetController()
	if IsValid(ctl) and self:GetLinked() then
		ZCFpv.StopControl(ctl)
	end
	local owner = self:GetOwner()
	if IsValid(owner) and owner.ZCFpvOwned == self then
		owner.ZCFpvOwned = nil
	end
	if not silent and self.Strike and not self.HasExploded then
		self.Removing = nil
		if self:HgBoom("Normal", 45, self.Mass or 8) and not IsValid(self) then return end
		self.Removing = true
	elseif not silent then
		local ed = EffectData()
		ed:SetOrigin(self:GetPos())
		ed:SetScale(0.4)
		util.Effect("cball_explode", ed, true, true)
		self:EmitSound("physics/metal/metal_box_break1.wav", 75, 120)
	end
	self:Remove()
end
