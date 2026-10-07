local MODE = MODE

MODE.name = "sandbox"
MODE.PrintName = "Sandbox"
MODE.Description = "No rounds, no teams, no combat modes."
MODE.randomSpawns = true
MODE.LootSpawn = false
MODE.GuiltDisabled = true
MODE.Chance = 1

function MODE:CanLaunch()
	return true
end

function MODE:Intermission()
end

function MODE:RoundStart()
end

function MODE:RoundThink()
end

function MODE:EndRound()
end

function MODE:GiveEquipment()
end

function MODE:ShouldRoundEnd()
	return false
end

function MODE:CanSpawn()
	return true
end

function MODE:GetTeamSpawn()
	return {}, {}
end
