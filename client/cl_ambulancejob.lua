local PlayerData = {}
local IsDead = false
local DeathCam
local angleY = 0.0
local angleZ = 0.0

Citizen.CreateThread(function()
    while not NetworkIsSessionStarted() do
		Citizen.Wait(0)
    end

	while not ESX do
		ESX = exports["es_extended"]:getSharedObject()
		Citizen.Wait(1000)
	end

	PlayerData = ESX.GetPlayerData()

    while not ESX.IsPlayerLoaded() do
        Citizen.Wait(1000)
    end

	Citizen.Wait(5000)

    -- ESX.TriggerServerCallback("esx_ambulancejob:getDeathStatus", function(dead)
    --     if dead then
    --         Citizen.Wait(1000)

    --         SetEntityHealth(PlayerPedId(), 0)
    --     end
    -- end)
end)

Citizen.CreateThread(function()
	local LetWait = 1000

	while true do
		Citizen.Wait(LetWait)

		if IsDead then
			local ped = PlayerPedId()
			local pedcoords = GetEntityCoords(ped)
			local newPos = GetNewCamCoords()
			LetWait = 0
			
			SetFocusArea(newPos.x, newPos.y, newPos.z, 0.0, 0.0, 0.0)
			SetCamCoord(DeathCam, newPos.x, newPos.y, newPos.z)
			PointCamAtCoord(DeathCam, pedcoords.x, pedcoords.y, pedcoords.z + 0.5)
			DisableFirstPersonCamThisFrame()
		else
			LetWait = 1000
		end
	end
end)

RegisterNetEvent("esx:playerLoaded", function(data)
    PlayerData = data
end)

RegisterNetEvent("esx:setJob", function(data)
	PlayerData.job = data
end)

AddEventHandler('esx:onPlayerDeath', function(data)
	OnPlayerDeath()
end)

RegisterNetEvent("esx_ambulancejob:revive")
AddEventHandler("esx_ambulancejob:revive", function(IsAdminRevive)
	local ped = PlayerPedId()
	local pedcoords = GetEntityCoords(ped)
	local _, ground = GetGroundZFor_3dCoord(pedcoords.x, pedcoords.y, pedcoords.z, true)
    local coords = vector3(pedcoords.x, pedcoords.y, ground)

	DoScreenFadeOut(800)

	exports["fs_deathscreen"]:SetState(false)
	SetDeathCamState(false)
	
	while not IsScreenFadedOut() do
		Wait(50)
	end

	SetTimeout(3000, function()
		TriggerServerEvent("esx_ambulancejob:setDeathStatus", false)
	end)

	RespawnPed(ped, coords, 0.0)
	IsDead = false
	ClearTimecycleModifier()
	SetPedMotionBlur(ped, false)
	ClearExtraTimecycleModifier()
	DoScreenFadeIn(800)

	if not IsAdminRevive then 
		Citizen.Wait(2000)
		ClearPedTasksImmediately(ped)
		SetEntityHealth(ped, 200)
	end
end)

function GetClosestRespawnPoint()
	local plyCoords = GetEntityCoords(PlayerPedId())
	local closestDist, closestHospital 
  
	for i=1, #Jobstuff.RespawnPoints do 
		local dist = #(plyCoords - Jobstuff.RespawnPoints[i].coords) 
  
		if not closestDist or dist <= closestDist then
			closestDist, closestHospital = dist, Jobstuff.RespawnPoints[i] 
		end 
	end 
	
	return closestHospital
  end

RegisterNetEvent("esx_ambulancejob:heal")
AddEventHandler("esx_ambulancejob:heal", function(type)
	local ped = PlayerPedId()
	local maxHealth = GetEntityMaxHealth(ped)

	if type == "small" then
		local health = GetEntityHealth(ped)
		local newHealth = math.min(maxHealth, math.floor(health + maxHealth / 8))
		SetEntityHealth(ped, newHealth)
	elseif type == "big" then
		SetEntityHealth(ped, maxHealth)
	end

	Notification("info", "Information", "Du wurdest behandelt und bist nun wieder gesund", 5000)
end)

function OnPlayerDeath()
	if LocalPlayer.state.IsInGW then
		return
	end

	if GetResourceState("fs_ffa") == "started" then
		if exports["fs_ffa"]:IsInZone() then
			return
		end
	end

 
	if GetResourceState("frp_airdrop") == "started" then
    	if exports["frp_airdrop"]:IsInZone() then
        	return
    	end
	end 

	if GetResourceState("frp_labore") == "started" then
   	 if exports["frp_labore"]:IsInZone() then
     	   return
    	end
	end 	

	if GetResourceState("frp_frakfights") == "started" then
    	if exports["frp_frakfights"]:IsInZone() then
       	 return
    	end
	end 
	
	local ped = PlayerPedId()
	SetPauseMenuActive(false)
	
	IsDead = true
	exports["fs_deathscreen"]:SetState(true)
    TriggerServerEvent("esx_ambulancejob:setDeathStatus", true)
	ClearPedTasksImmediately(ped)
	SetDeathCamState(true)
end

function RespawnPed(ped, coords, heading)
	SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
	NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
	SetPlayerInvincible(ped, false)
	ClearPedBloodDamage(ped)

	TriggerServerEvent("esx:onPlayerSpawn")
  	TriggerEvent("esx:onPlayerSpawn")
  	TriggerEvent("playerSpawned")

	Citizen.Wait(10)
	SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)

	FixColission()
end

function FixColission()
    ClearAllBrokenGlass()
    ClearAllHelpMessages()
    LeaderboardsReadClearAll()
    ClearBrief()
    ClearGpsFlags()
    ClearPrints()
    ClearSmallPrints()
    ClearReplayStats()
    LeaderboardsClearCacheData()
    ClearFocus()
    ClearHdArea()
    ClearPedBloodDamage(PlayerPedId())
    ClearPedWetness(PlayerPedId())
    ClearPedEnvDirt(PlayerPedId())
    ResetPedVisibleDamage(PlayerPedId())
end

function SetDeathCamState(state)
	local ped = PlayerPedId()

	if state then 
		ClearFocus()
		DeathCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", GetEntityCoords(ped), 0, 0, 0, GetGameplayCamFov())
		SetCamActive(DeathCam, true)
		RenderScriptCams(true, true, 1000, true, false)
	else
		ClearFocus()
		RenderScriptCams(false, false, 0, true, false)
		DestroyCam(DeathCam, false)
		DeathCam = nil
	end
end

function GetNewCamCoords()
	local mouseX = 0.0
	local mouseY = 0.0

	if (IsInputDisabled(0)) then
		mouseX = GetDisabledControlNormal(1, 1) * 8.0
		mouseY = GetDisabledControlNormal(1, 2) * 8.0
	else
		mouseX = GetDisabledControlNormal(1, 1) * 1.5	
		mouseY = GetDisabledControlNormal(1, 2) * 1.5
	end
  
	angleZ = angleZ - mouseX
	angleY = angleY + mouseY

	if (angleY > 89.0) then
		angleY = 89.0
	elseif (angleY < -89.0) then
		angleY = -89.0
	end

	local pCoords = GetEntityCoords(PlayerPedId())
	local behindCam = {
		x = pCoords.x + ((Cos(angleZ) * Cos(angleY)) + (Cos(angleY) * Cos(angleZ))) / 2 * (5.5 + 0.5),
		y = pCoords.y + ((Sin(angleZ) * Cos(angleY)) + (Cos(angleY) * Sin(angleZ))) / 2 * (5.5 + 0.5),
		z = pCoords.z + ((Sin(angleY))) * (5.5 + 0.5)
	}

	local rayHandle = StartShapeTestRay(pCoords.x, pCoords.y, pCoords.z + 0.5, behindCam.x, behindCam.y, behindCam.z, -1, PlayerPedId(), 0)
	local a, hitBool, hitCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
	local maxRadius = 1.9
	
	if (hitBool and Vdist(pCoords.x, pCoords.y, pCoords.z + 0.5, hitCoords) < 5.5 + 0.5) then
		maxRadius = Vdist(pCoords.x, pCoords.y, pCoords.z + 0.5, hitCoords)
	end
  
	local offset = {
		x = ((Cos(angleZ) * Cos(angleY)) + (Cos(angleY) * Cos(angleZ))) / 2 * maxRadius,
		y = ((Sin(angleZ) * Cos(angleY)) + (Cos(angleY) * Sin(angleZ))) / 2 * maxRadius, 
		z = ((Sin(angleY))) * maxRadius
	}
  
	return {x = pCoords.x + offset.x, y = pCoords.y + offset.y, z = pCoords.z + offset.z}
end