if SERVER then
	AddCSLuaFile()
end

SWEP.Base = "weapon_tpik1_base"
SWEP.PrintName = "FPV Controller"
SWEP.Author = "informal1337"
SWEP.Instructions = "no"
SWEP.Category = "ZCity FPV"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.IconOverride = "entities/sw_crocus_pg7.png"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/dronesrewrite/w_controller/w_controller.mdl"
SWEP.UseHands = false
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.HoldType = "normal"
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.Slot = 4
SWEP.SlotPos = 6
SWEP.setrhik = true
SWEP.setlhik = true
SWEP.ModelFollowRightHand = false
SWEP.LHPos = Vector(0, -6.4, 0)
SWEP.LHAng = Angle(-55, 0, 180)
SWEP.RHPosOffset = Vector(0, 0, -6)
SWEP.RHAngOffset = Angle(0, 90, -90)
SWEP.LHPosOffset = Vector(0, 0, -0.2)
SWEP.LHAngOffset = Angle(30, 0, 0)
SWEP.offsetVec = Vector(-0, -0, -4)
SWEP.offsetAng = Angle(-50, -180, 90)
SWEP.ModelScale = 1.65
SWEP.HeadPosOffset = Vector(15, 1.7, -8)
SWEP.HeadAngOffset = Angle(-90, 0, -90)
SWEP.BaseBone = "ValveBiped.Bip01_Head1"
SWEP.HoldLH = "normal"
SWEP.HoldRH = "normal"
SWEP.HoldClampMax = 35
SWEP.HoldClampMin = -35
SWEP.Skin = 0

function SWEP:SetupDataTables()
	self:NetworkVar("Int", 0, "DroneType")
end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
	self:SetDroneType(1)
	self.NextDeploy = 0
	self.NextTypeSwitch = 0
end

function SWEP:GetTypeKey()
	local order = ZCFpv and ZCFpv.TypeOrder or {"crocus", "mavic"}
	local i = math.Clamp(self:GetDroneType(), 1, #order)
	return order[i], ZCFpv and ZCFpv.Types[order[i]]
end

function SWEP:Deploy()
	self:SetHoldType(self.HoldType)
	return true
end

function SWEP:Holster()
	return true
end

function SWEP:Reload()
	if CurTime() < (self.NextTypeSwitch or 0) then return end
	self.NextTypeSwitch = CurTime() + 0.35
	if CLIENT then return end

	local order = ZCFpv and ZCFpv.TypeOrder or {"crocus", "mavic"}
	local i = self:GetDroneType() + 1
	if i > #order then i = 1 end
	self:SetDroneType(i)
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.4)
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	if ply.ZCFpvFeedLost then return end
	local linked = ZCFpv and ZCFpv.GetLinkedDrone(ply)
	if IsValid(linked) then
		return
	end
	if CLIENT then return end
	if CurTime() < (self.NextDeploy or 0) then return end
	local _, cfg = self:GetTypeKey()
	if not cfg then return end
	local tr = util.TraceLine({
		start = ply:EyePos(),
		endpos = ply:EyePos() + ply:EyeAngles():Forward() * 120,
		filter = ply,
		mask = MASK_SOLID,
	})
	local pos = tr.HitPos - ply:EyeAngles():Forward() * 18 + Vector(0, 0, 12)
	if not tr.Hit then
		pos = ply:EyePos() + ply:EyeAngles():Forward() * 80
	end
	local ang = Angle(0, ply:EyeAngles().y, 0)
	local drone = ents.Create(cfg.class)
	if not IsValid(drone) then return end
	drone:SetPos(pos)
	drone:SetAngles(ang)
	drone:SetOwner(ply)
	drone:Spawn()
	drone:Activate()
	drone.HoverZ = pos.z
	drone.TargetAng = ang
	ply.ZCFpvOwned = drone
	self.NextDeploy = CurTime() + (ZCFpv.DeployCooldown or 1.5)
	ply:EmitSound("buttons/button14.wav", 60, 110)
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.5)
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	if CLIENT then return end
	if ply.ZCFpvFeedLost then return end
	local linked = ZCFpv.GetLinkedDrone(ply)
	if IsValid(linked) then
		ZCFpv.StopControl(ply)
		return
	end
	local tr = util.TraceLine({
		start = ply:EyePos(),
		endpos = ply:EyePos() + ply:GetAimVector() * 4000,
		filter = ply,
		mask = MASK_SHOT,
	})
	local hit = tr.Entity
	local owned
	if ZCFpv.IsDrone(hit) and hit:GetOwner() == ply and not hit.Dead then
		owned = hit
	else
		owned = ply.ZCFpvOwned
		if not ZCFpv.IsDrone(owned) or owned.Dead then
			local best
			local bestDist = math.huge
			for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), 500)) do
				if ZCFpv.IsDrone(ent) and not ent.Dead and ent:GetOwner() == ply and not ent.CatapultMounted then
					local dist = ply:GetPos():DistToSqr(ent:GetPos())
					if dist < bestDist then
						best = ent
						bestDist = dist
					end
				end
			end
			owned = best
		end
		if not ZCFpv.IsDrone(owned) or owned.Dead then return end
		local dir = (owned:GetPos() - ply:EyePos()):GetNormalized()
		if ply:GetAimVector():Dot(dir) < 0.55 and ply:GetPos():Distance(owned:GetPos()) > 500 then
			return
		end
	end

	ply.ZCFpvOwned = owned

	if owned:GetOwner() ~= ply then
		owned:SetOwner(ply)
	end
	if not owned:GetPowered() then
		owned:SetPower(true)
	end
	if not owned:GetPowered() then return end

	ZCFpv.StartControl(ply, owned)
end

function SWEP:Think()
	if CLIENT then return end
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	if ply:KeyPressed(IN_USE) then
		local linked = ZCFpv.GetLinkedDrone(ply)
		if IsValid(linked) then
			ZCFpv.StopControl(ply)
		end
	end
end

if CLIENT then
	function SWEP:DrawHUD()
		local ply = LocalPlayer()
		if ZCFpv.GetLinkedDrone(ply) then return end
		local key, cfg = self:GetTypeKey()
		draw.SimpleText("Type: " .. (cfg and cfg.name or key), "ZCity_Tiny", ScrW() * 0.5, ScrH() - 60, color_white, TEXT_ALIGN_CENTER)
		draw.SimpleText("LMB deploy  |  RMB link  |  R switch", "ZCity_Tiny", ScrW() * 0.5, ScrH() - 32, Color(200, 200, 200), TEXT_ALIGN_CENTER)
	end
end
