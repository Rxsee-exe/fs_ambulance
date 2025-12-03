local DeadPlayers = {}
local ActionCooldowns = {}
local ActionEvents = {}
local ActionsInProgress = {}

AddEventHandler("txAdmin:events:healedPlayer", function(eventData)
	if GetInvokingResource() ~= "monitor" or type(eventData) ~= "table" or type(eventData.id) ~= "number" then
		return
	end

	if DeadPlayers[eventData.id] then
		TriggerClientEvent("esx_ambulancejob:revive", eventData.id, true)
		DeadPlayers[eventData.id] = nil
	end
end)

RegisterNetEvent("esx:onPlayerDeath")
AddEventHandler("esx:onPlayerDeath", function(data)
	local source = source
    
	DeadPlayers[source] = true
	SetDeadStateBag(source, true)

    exports["jobs_creator"]:setHandcuffs(source, false)
end)

RegisterNetEvent("esx:onPlayerSpawn")
AddEventHandler("esx:onPlayerSpawn", function()
	local source = source

	if DeadPlayers[source] then
		DeadPlayers[source] = nil
		SetDeadStateBag(source, false)
	end
end)

AddEventHandler("esx:playerDropped", function(source, reason)
	if DeadPlayers[source] then
		DeadPlayers[source] = nil
		SetDeadStateBag(source, false)
	end
end)

RegisterNetEvent("esx_ambulancejob:setDeathStatus")
AddEventHandler("esx_ambulancejob:setDeathStatus", function(state)
    local source = source
	local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer then 
        if state then 
            Query("UPDATE users SET is_dead = @state WHERE identifier = @identifier", {
                ["@state"] = 1,
                ["@identifier"] = xPlayer.identifier
            }, function()
                SetDeadStateBag(xPlayer.source, true)
            end)   
        else
            Query("UPDATE users SET is_dead = @state WHERE identifier = @identifier", {
                ["@state"] = 0,
                ["@identifier"] = xPlayer.identifier
            }, function()
                SetDeadStateBag(xPlayer.source, false)
            end)   
        end
    end
end)

RegisterNetEvent("jobs_creator:actions:revive")
AddEventHandler("jobs_creator:actions:revive", function(target)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer then 
        local xTarget = ESX.GetPlayerFromId(target)

        if not xTarget then 
            return 
        end

        if xPlayer.getJob().name ~= "ambulance" then 
            exports["WaveShield"]:banPlayer(xPlayer.source, "Cheating (revive)", "Nicht hier.", 31536000) 
            return
        end

        if not IsNearSource(xPlayer.source, xTarget.source) then 
            return
        end

        if xPlayer.getInventoryItem("medikit").count <= 0 then 
            TriggerClientEvent("frp_hud:notify", xPlayer.source, "error", "Information", "Du benötigst ein Medikit um diese Aktion auszuführen", 5000)
            return 
        end
        
        if not ActionCooldowns[xPlayer.source] then 
            ActionCooldowns[xPlayer.source] = {}
        end

        if not ActionEvents[xPlayer.sourceurce] then 
            ActionEvents[xPlayer.source] = {}
        end

        if ActionsInProgress[xPlayer.source] then 
            TriggerClientEvent("frp_hud:notify", xPlayer.source, "error", "Information", "Du führst bereits eine Aktion aus", 5000)
            return 
        end

        if ActionsInProgress[xTarget.source] then 
            TriggerClientEvent("frp_hud:notify", xPlayer.source, "error", "Information", "Diese Person wird bereits wiederbelebt", 5000)
            return 
        end

        if ActionCooldowns[xPlayer.source]["revive"] then 
            TriggerClientEvent("frp_hud:notify", xPlayer.source, "error", "Information", "Bitte warte einen Moment bevor du diese Aktion erneut ausführst", 5000)
            return 
        end

        if (ActionEvents[xPlayer.source]["revive"] or 0) > 5 then 
            DropPlayer(xPlayer.source, "Du hast zu viele Aktionen hintereinander ausgeführt")
            return 
        end

        ActionEvents[xPlayer.source]["revive"] = (ActionEvents[source]["revive"] or 0) + 1
        ActionCooldowns[xPlayer.source]["revive"] = true
        ActionsInProgress[xPlayer.source] = true
        ActionsInProgress[xTarget.source] = true
        TriggerClientEvent("frp_hud:notify", xTarget.source, "info", "Information", ("Du wirst von %s wiederbelebt"):format(xPlayer.getName()), 5000)

        SetTimeout(12000, function()
            xPlayer.addMoney(350)
            TriggerClientEvent("frp_hud:notify", xTarget.source, "info", "Information", ("Du wurdest von %s wiederbelebt"):format(xPlayer.getName()), 5000)
            TriggerClientEvent("frp_hud:notify", xPlayer.source, "info", "Information", ("Du hast %s wiederbelebt und hast $1000 erhalten"):format(xTarget.getName()), 5000)
            ActionsInProgress[xPlayer.source] = nil
        end)

        SetTimeout(40000, function()
            ActionEvents[xPlayer.source]["revive"] = nil
            ActionCooldowns[xPlayer.source]["revive"] = nil
            ActionsInProgress[xTarget.source] = nil
        end)
    end
end)

RegisterNetEvent("jobs_creator:actions:healBig")
AddEventHandler("jobs_creator:actions:healBig", function(target)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer then 
        local xTarget = ESX.GetPlayerFromId(target)

        if not xTarget then
            return 
        end

        if xPlayer.getJob().name ~= "ambulance" then
            exports["WaveShield"]:banPlayer(source, "Cheating (healing)", "Nicht hier.", 31536000)
            return 
        end

        if not IsNearSource(xPlayer.source, xTarget.source) then 
            return
        end

        if xPlayer.getInventoryItem("bandage").count < 1 then 
            TriggerClientEvent("frp_hud:notify", xPlayer.source, "error", "Information", "Du benötigst ein Verband um diese Aktion auszuführen", 5000)
            return 
        end

        TriggerClientEvent("frp_hud:notify", xTarget.source, "info", "Information", ("Du wirst von %s behandelt"):format(xPlayer.getName()), 5000)

        SetTimeout(12000, function()
            TriggerClientEvent("frp_hud:notify", xTarget.source, "info", "Information", ("Du wurdest von %s behandelt"):format(xPlayer.getName()), 5000)
            TriggerClientEvent("frp_hud:notify", xPlayer.source, "info", "Information", ("Du hast %s behandelt"):format(xTarget.getName()), 5000)
        end)
    end
end)

ESX.RegisterServerCallback("esx_ambulancejob:getDeathStatus", function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer then 
        Query("SELECT is_dead FROM users WHERE identifier = @identifier", {
            ["@identifier"] = xPlayer.identifier
        }, function(result)            
            if result and result[1] then 
                if result[1].is_dead then 
                    cb(true)
                else
                    cb(false)
                end
            end
        end)
    end
end)

function SetDeadStateBag(src, bool)
	if not src or bool == nil then 
        return 
    end

    local ped = GetPlayerPed(src)

    Entity(ped).state.IsDead = bool
	Player(src).state:set("isDead", bool, true)
end

function IsNearSource(source, target)
    if not source or not target then 
        return false
    end

    local sourceCoords = GetEntityCoords(GetPlayerPed(source))
    local targetCoords = GetEntityCoords(GetPlayerPed(target))
    local distance = #(sourceCoords - targetCoords)

    return distance < 15.0
end