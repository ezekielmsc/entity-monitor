-- Vérifier si un joueur est admin
local function IsAdmin(source)
    return IsPlayerAceAllowed(source, "command")
end

-- Tracking des entités par ressource
local entityTracking = {
    vehicles = {},
    peds = {},
    objects = {}
}

-- Hook sur la création d'entités
AddEventHandler('entityCreated', function(entity)
    local entityType = GetEntityType(entity)
    local invokingResource = GetInvokingResource()

    if not invokingResource then
        invokingResource = "unknown"
    end

    if entityType == 1 then -- Ped
        entityTracking.peds[entity] = invokingResource
    elseif entityType == 2 then -- Vehicle
        entityTracking.vehicles[entity] = invokingResource
    elseif entityType == 3 then -- Object
        entityTracking.objects[entity] = invokingResource
    end
end)

-- Nettoyer les entités supprimées
AddEventHandler('entityRemoved', function(entity)
    entityTracking.vehicles[entity] = nil
    entityTracking.peds[entity] = nil
    entityTracking.objects[entity] = nil
end)

-- Collecter les données d'entités par ressource
local function GetEntityStats()
    local stats = {
        byResource = {},
        totals = {
            vehicles = 0,
            peds = 0,
            objects = 0,
            total = 0
        }
    }

    -- Compter les véhicules par ressource
    local vehicles = GetAllVehicles()
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            stats.totals.vehicles = stats.totals.vehicles + 1
            local res = entityTracking.vehicles[vehicle] or "unknown"
            if not stats.byResource[res] then
                stats.byResource[res] = {vehicles = 0, peds = 0, objects = 0}
            end
            stats.byResource[res].vehicles = stats.byResource[res].vehicles + 1
        end
    end

    -- Compter les peds par ressource
    local peds = GetAllPeds()
    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
            stats.totals.peds = stats.totals.peds + 1
            local res = entityTracking.peds[ped] or "unknown"
            if not stats.byResource[res] then
                stats.byResource[res] = {vehicles = 0, peds = 0, objects = 0}
            end
            stats.byResource[res].peds = stats.byResource[res].peds + 1
        end
    end

    -- Compter les objets par ressource
    local objects = GetAllObjects()
    for _, object in ipairs(objects) do
        if DoesEntityExist(object) then
            stats.totals.objects = stats.totals.objects + 1
            local res = entityTracking.objects[object] or "unknown"
            if not stats.byResource[res] then
                stats.byResource[res] = {vehicles = 0, peds = 0, objects = 0}
            end
            stats.byResource[res].objects = stats.byResource[res].objects + 1
        end
    end

    stats.totals.total = stats.totals.vehicles + stats.totals.peds + stats.totals.objects

    return stats
end

-- Collecter les statistiques des ressources (mémoire, état)
local function GetResourcesInfo()
    local resources = {}
    local numResources = GetNumResources()

    for i = 0, numResources - 1 do
        local resourceName = GetResourceByFindIndex(i)
        if resourceName then
            local state = GetResourceState(resourceName)
            if state == "started" then
                table.insert(resources, {
                    name = resourceName,
                    state = state
                })
            end
        end
    end

    return resources
end

-- Commande pour demander les stats aux clients
RegisterNetEvent('entityMonitor:requestStats', function()
    local source = source

    if not IsAdmin(source) then
        print(("[EntityMonitor] Accès refusé pour le joueur %s"):format(source))
        return
    end

    -- Demander à tous les clients de renvoyer leurs stats locales
    TriggerClientEvent('entityMonitor:collectStats', -1, source)
end)

-- Recevoir les stats d'un client
local clientStats = {}
local pendingRequests = {}

RegisterNetEvent('entityMonitor:sendStats', function(stats, requesterId)
    local source = source

    if not clientStats[requesterId] then
        clientStats[requesterId] = {
            byResource = {},
            byPlayer = {},
            totals = {vehicles = 0, peds = 0, objects = 0}
        }
    end

    -- Agréger les stats de ce client
    clientStats[requesterId].byPlayer[source] = stats

    -- Fusionner les stats par ressource
    for resourceName, data in pairs(stats.byResource or {}) do
        if not clientStats[requesterId].byResource[resourceName] then
            clientStats[requesterId].byResource[resourceName] = {vehicles = 0, peds = 0, objects = 0}
        end
        clientStats[requesterId].byResource[resourceName].vehicles =
            clientStats[requesterId].byResource[resourceName].vehicles + (data.vehicles or 0)
        clientStats[requesterId].byResource[resourceName].peds =
            clientStats[requesterId].byResource[resourceName].peds + (data.peds or 0)
        clientStats[requesterId].byResource[resourceName].objects =
            clientStats[requesterId].byResource[resourceName].objects + (data.objects or 0)
    end

    -- Mettre à jour les totaux
    clientStats[requesterId].totals.vehicles = clientStats[requesterId].totals.vehicles + (stats.totals.vehicles or 0)
    clientStats[requesterId].totals.peds = clientStats[requesterId].totals.peds + (stats.totals.peds or 0)
    clientStats[requesterId].totals.objects = clientStats[requesterId].totals.objects + (stats.totals.objects or 0)
end)

-- Finaliser et envoyer les stats agrégées
RegisterNetEvent('entityMonitor:finishCollection', function()
    local source = source

    if not IsAdmin(source) then return end

    -- Récupérer les stats serveur (avec tracking par ressource)
    local serverStats = GetEntityStats()

    local stats = {
        byResource = serverStats.byResource,
        totals = serverStats.totals,
        serverInfo = {
            players = #GetPlayers(),
            maxPlayers = GetConvarInt("sv_maxclients", 32),
            resources = GetResourcesInfo()
        }
    }

    -- Trier les ressources par nombre d'entités
    local sortedResources = {}
    for name, data in pairs(stats.byResource) do
        local total = (data.vehicles or 0) + (data.peds or 0) + (data.objects or 0)
        if total > 0 then
            table.insert(sortedResources, {
                name = name,
                vehicles = data.vehicles or 0,
                peds = data.peds or 0,
                objects = data.objects or 0,
                total = total
            })
        end
    end

    table.sort(sortedResources, function(a, b)
        return a.total > b.total
    end)

    stats.sortedResources = sortedResources

    TriggerClientEvent('entityMonitor:receiveStats', source, stats)

    -- Nettoyer
    clientStats[source] = nil
end)

-- Commande chat pour ouvrir le monitor
RegisterCommand('entitymonitor', function(source, args)
    if source == 0 then
        print("[EntityMonitor] Cette commande doit être exécutée en jeu")
        return
    end

    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {"Système", "Vous n'avez pas la permission d'utiliser cette commande."}
        })
        return
    end

    TriggerClientEvent('entityMonitor:toggle', source)
end, false)

-- Alias
RegisterCommand('em', function(source, args)
    if source == 0 then return end
    ExecuteCommand('entitymonitor')
end, false)

print("^2[EntityMonitor]^0 Script chargé - Utilisez /entitymonitor ou /em pour ouvrir le dashboard")
