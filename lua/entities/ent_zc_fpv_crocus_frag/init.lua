AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
local function saveWindows(pos)
	local windows = {}
	for _, ent in ipairs(ents.FindInSphere(pos, 900)) do
		local class = ent:GetClass()
		if class ~= "func_breakable_surf" and (class ~= "func_breakable" or ent:GetMaterialType() ~= MAT_GLASS) then
			continue
		end
		windows[#windows + 1] = {
			ent = ent, -- хуйня
			class = class,
			model = ent:GetModel(),
			pos = ent:GetPos(),
			center = ent:LocalToWorld(ent:OBBCenter()),
			ang = ent:GetAngles(),
			name = ent:GetName(),
			health = math.max(ent:GetInternalVariable("m_iHealth") or ent:Health(), 1),
			material = ent:GetInternalVariable("m_Material") or 0,
		}
	end
	return windows
end

local function cutByGlass(windows, attacker, inflictor)
	local victims = {}
	for _, data in ipairs(windows) do
		for _, ply in ipairs(player.GetAll()) do
			if not ply:Alive() then continue end
			local target = ply:WorldSpaceCenter()
			local dist = target:Distance(data.center)
			if dist > 140 then continue end
			local tr = util.TraceLine({
				start = data.center,
				endpos = target,
				filter = {data.ent, inflictor},
				mask = MASK_SHOT,
			})
			if tr.Hit and tr.Entity ~= ply then continue end
			local frac = 1 - dist / 140
			local damage = 4 + frac * 12
			if not victims[ply] or damage > victims[ply].damage then
				victims[ply] = {
					damage = damage,
					pos = data.center,
				}
			end
		end
	end
	for ply, data in pairs(victims) do
		local dir = (ply:WorldSpaceCenter() - data.pos):GetNormalized()
		local dmg = DamageInfo()
		dmg:SetAttacker(attacker)
		dmg:SetInflictor(inflictor)
		dmg:SetDamage(data.damage)
		dmg:SetDamageType(DMG_SLASH)
		dmg:SetDamagePosition(ply:WorldSpaceCenter())
		dmg:SetDamageForce(dir * data.damage * 80)
		ply:TakeDamageInfo(dmg)
	end
end

local function restoreWindows(windows)
	timer.Simple(20, function()
		for _, data in ipairs(windows) do
			local ent = data.ent
			if not IsValid(ent) then
				ent = ents.Create(data.class)
				if not IsValid(ent) then continue end
				ent:SetModel(data.model)
				ent:SetPos(data.pos)
				ent:SetAngles(data.ang)
				ent:SetKeyValue("health", data.health)
				ent:SetKeyValue("material", data.material)
				if data.name ~= "" then ent:SetKeyValue("targetname", data.name) end
			end
			ent:Spawn()
			ent:Activate()
			ent:SetSaveValue("m_bIsBroken", false)
			ent:SetHealth(data.health)
			ent:SetNoDraw(false)
			ent:SetNotSolid(false)
			ent:Fire("Enable")
		end
	end)
end

function ENT:OnDetonate()
	local pos = self:GetPos()
	local owner = self:GetOwner()
	local attacker = IsValid(owner) and owner or self
	local cfg = ZCFpv.Types and ZCFpv.Types.crocus_frag or {}
	local windows = saveWindows(pos)
	if not self:HgBoom(cfg.expType, cfg.expForce, cfg.expMass) then
		self:Break(true)
		return
	end
	cutByGlass(windows, attacker, self)
	restoreWindows(windows)
end
