local isOpen = false
local autoRefresh = false
local refreshInterval = 5000
local debugMode = false
local debugBlips = {}
local debugMarkers = {}

-- Props de vêtements/accessoires connus (hash models)
local clothingProps = {
    -- Chapeaux / Casquettes
    [`p_michael_hat_01`] = "Chapeau",
    [`prop_cop_hat_01`] = "Casquette Police",
    [`prop_hat_boxers`] = "Casquette Boxeur",
    [`prop_hat_biker`] = "Casque Biker",
    [`prop_helmet_01`] = "Casque",
    -- Lunettes
    [`prop_cs_sunglasses`] = "Lunettes",
    [`prop_glasses_01`] = "Lunettes",
    -- Sacs
    [`prop_ld_bag_01`] = "Sac",
    [`prop_poly_bag_01`] = "Sac Plastique",
    [`prop_bag_canvas_01`] = "Sac Canvas",
    [`prop_duffle_bag_01`] = "Duffle Bag",
    [`hei_p_m_bag_var22_arm_s`] = "Sac",
    -- Masques
    [`prop_mask_ballistic`] = "Masque Balistique",
    [`prop_mask_cs_01`] = "Masque",
    -- Parachutes
    [`p_parachute_s`] = "Parachute",
    [`prop_parachute`] = "Parachute",
    -- Gilets
    [`prop_armour_pickup`] = "Gilet Armure",
    -- Accessoires divers
    [`prop_ld_headset_01`] = "Casque Audio",
    [`prop_headphones_01`] = "Ecouteurs",
    [`prop_watch_01`] = "Montre",
    [`prop_jewel_02a`] = "Bijou",
    [`prop_jewel_02b`] = "Bijou",
    [`prop_jewel_03a`] = "Bijou",
}

-- Patterns de noms pour détecter les props vêtements
local clothingPatterns = {
    "hat", "cap", "helmet", "mask", "glasses", "sunglasses",
    "bag", "backpack", "parachute", "armour", "armor",
    "watch", "jewel", "chain", "ring", "earring",
    "headset", "headphone", "scarf", "tie", "glove"
}

-- Ouvrir/Fermer le monitor
function ToggleMonitor()
    isOpen = not isOpen
    SetNuiFocus(isOpen, isOpen)
    SendNUIMessage({
        action = isOpen and 'open' or 'close'
    })

    if isOpen then
        RequestStats()
    end
end

-- Demander les stats
function RequestStats()
    -- Collecter les stats locales
    local localStats = CollectLocalStats()

    -- Envoyer au serveur pour agrégation
    TriggerServerEvent('entityMonitor:requestStats')
    TriggerServerEvent('entityMonitor:sendStats', localStats, GetPlayerServerId(PlayerId()))

    -- Demander la finalisation après un court délai
    SetTimeout(300, function()
        TriggerServerEvent('entityMonitor:finishCollection')
    end)
end

-- Collecter les statistiques locales (côté client)
function CollectLocalStats()
    local stats = {
        byResource = {},
        totals = {
            vehicles = 0,
            peds = 0,
            objects = 0
        },
        nearbyEntities = {}
    }

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    -- Compter les véhicules
    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            stats.totals.vehicles = stats.totals.vehicles + 1

            -- Déterminer la ressource propriétaire
            local owner = GetEntityPopulationType(vehicle)
            local resourceName = GetResourceNameFromEntity(vehicle)

            if resourceName and resourceName ~= "" then
                if not stats.byResource[resourceName] then
                    stats.byResource[resourceName] = {vehicles = 0, peds = 0, objects = 0}
                end
                stats.byResource[resourceName].vehicles = stats.byResource[resourceName].vehicles + 1
            end

            -- Entités proches (dans un rayon de 100m)
            local dist = #(playerCoords - GetEntityCoords(vehicle))
            if dist < 100.0 then
                table.insert(stats.nearbyEntities, {
                    type = 'vehicle',
                    model = GetEntityModel(vehicle),
                    distance = dist,
                    resource = resourceName or 'unknown'
                })
            end
        end
    end

    -- Compter les peds
    local peds = GetGamePool('CPed')
    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
            stats.totals.peds = stats.totals.peds + 1

            local resourceName = GetResourceNameFromEntity(ped)

            if resourceName and resourceName ~= "" then
                if not stats.byResource[resourceName] then
                    stats.byResource[resourceName] = {vehicles = 0, peds = 0, objects = 0}
                end
                stats.byResource[resourceName].peds = stats.byResource[resourceName].peds + 1
            end

            local dist = #(playerCoords - GetEntityCoords(ped))
            if dist < 100.0 then
                table.insert(stats.nearbyEntities, {
                    type = 'ped',
                    model = GetEntityModel(ped),
                    distance = dist,
                    resource = resourceName or 'unknown'
                })
            end
        end
    end

    -- Compter les objets
    local objects = GetGamePool('CObject')
    for _, object in ipairs(objects) do
        if DoesEntityExist(object) then
            stats.totals.objects = stats.totals.objects + 1

            local resourceName = GetResourceNameFromEntity(object)

            if resourceName and resourceName ~= "" then
                if not stats.byResource[resourceName] then
                    stats.byResource[resourceName] = {vehicles = 0, peds = 0, objects = 0}
                end
                stats.byResource[resourceName].objects = stats.byResource[resourceName].objects + 1
            end

            local dist = #(playerCoords - GetEntityCoords(object))
            if dist < 100.0 then
                table.insert(stats.nearbyEntities, {
                    type = 'object',
                    model = GetEntityModel(object),
                    distance = dist,
                    resource = resourceName or 'unknown'
                })
            end
        end
    end

    return stats
end

-- Essayer de déterminer la ressource d'une entité
function GetResourceNameFromEntity(entity)
    -- Utiliser le décorateur si disponible (certains scripts marquent leurs entités)
    -- Sinon, on analyse le type de population
    local popType = GetEntityPopulationType(entity)

    -- PopType 0 = unknown, 7 = mission/script created
    if popType == 7 then
        -- Entité créée par un script, mais on ne peut pas savoir lequel côté client
        return "script_spawned"
    elseif popType == 0 then
        return "unknown"
    else
        -- Entités du jeu (traffic, ambient, etc.)
        return "game_native"
    end
end

-- Recevoir les stats du serveur
RegisterNetEvent('entityMonitor:receiveStats', function(stats)
    -- Ajouter les stats locales détaillées
    local localStats = CollectLocalStats()
    stats.localStats = localStats

    SendNUIMessage({
        action = 'updateStats',
        stats = stats
    })
end)

-- Collecter les stats et les envoyer au serveur
RegisterNetEvent('entityMonitor:collectStats', function(requesterId)
    local localStats = CollectLocalStats()
    TriggerServerEvent('entityMonitor:sendStats', localStats, requesterId)
end)

-- Toggle depuis le serveur
RegisterNetEvent('entityMonitor:toggle', function()
    ToggleMonitor()
end)

-- Callbacks NUI
RegisterNUICallback('close', function(data, cb)
    isOpen = false
    SetNuiFocus(false, false)
    autoRefresh = false
    cb('ok')
end)

RegisterNUICallback('refresh', function(data, cb)
    RequestStats()
    cb('ok')
end)

RegisterNUICallback('toggleAutoRefresh', function(data, cb)
    autoRefresh = data.enabled
    cb('ok')
end)

-- Auto-refresh thread
CreateThread(function()
    while true do
        Wait(refreshInterval)
        if isOpen and autoRefresh then
            RequestStats()
        end
    end
end)

-- Keybind pour toggle (F7)
RegisterCommand('+entitymonitor', function()
    TriggerServerEvent('entityMonitor:requestStats')
    ToggleMonitor()
end, false)

RegisterKeyMapping('+entitymonitor', 'Ouvrir Entity Monitor', 'keyboard', 'F7')

-- Debug Mode: Afficher les entités unknown sur la map
function ToggleDebugMode()
    debugMode = not debugMode

    if debugMode then
        StartDebugMode()
    else
        StopDebugMode()
    end

    SendNUIMessage({
        action = 'debugModeChanged',
        enabled = debugMode
    })
end

function StartDebugMode()
    -- Nettoyer les anciens blips
    StopDebugMode()

    local unknownEntities = GetUnknownEntities()
    local mloZones = {}

    for _, entity in ipairs(unknownEntities) do
        local coords = GetEntityCoords(entity.handle)

        -- Créer un blip pour chaque entité
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

        if entity.type == 'vehicle' then
            SetBlipSprite(blip, 225) -- Car icon
            SetBlipColour(blip, 5) -- Yellow
        elseif entity.type == 'ped' then
            SetBlipSprite(blip, 480) -- Person icon
            SetBlipColour(blip, 2) -- Green
        else
            SetBlipSprite(blip, 478) -- Box icon
            SetBlipColour(blip, 17) -- Orange
        end

        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(("[%s] %s"):format(entity.type:upper(), entity.model))
        EndTextCommandSetBlipName(blip)

        table.insert(debugBlips, blip)

        -- Détecter les zones MLO (clusters d'entités)
        local zoneKey = ("%d_%d"):format(math.floor(coords.x / 50), math.floor(coords.y / 50))
        if not mloZones[zoneKey] then
            mloZones[zoneKey] = {
                coords = coords,
                count = 0,
                entities = {}
            }
        end
        mloZones[zoneKey].count = mloZones[zoneKey].count + 1
        table.insert(mloZones[zoneKey].entities, entity)
    end

    -- Identifier les MLO potentiels (zones avec beaucoup d'entités)
    local potentialMLOs = {}
    for zoneKey, zone in pairs(mloZones) do
        if zone.count >= 5 then -- 5+ entités dans une zone = probable MLO
            table.insert(potentialMLOs, {
                coords = zone.coords,
                count = zone.count,
                interior = GetInteriorAtCoords(zone.coords.x, zone.coords.y, zone.coords.z)
            })

            -- Créer un blip spécial pour le MLO
            local mloBlip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
            SetBlipSprite(mloBlip, 492) -- Warning icon
            SetBlipColour(mloBlip, 1) -- Red
            SetBlipScale(mloBlip, 1.2)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(("MLO SUSPECT - %d entites"):format(zone.count))
            EndTextCommandSetBlipName(mloBlip)

            table.insert(debugBlips, mloBlip)
        end
    end

    -- Envoyer les infos MLO à la NUI
    SendNUIMessage({
        action = 'updateMLOInfo',
        mlos = potentialMLOs,
        totalUnknown = #unknownEntities
    })

    print(("^3[EntityMonitor]^0 Debug mode ON - %d entités unknown, %d MLO suspects"):format(#unknownEntities, #potentialMLOs))
end

function StopDebugMode()
    for _, blip in ipairs(debugBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    debugBlips = {}
    debugMarkers = {}
    print("^3[EntityMonitor]^0 Debug mode OFF")
end

function GetUnknownEntities()
    local unknown = {}
    local playerPed = PlayerPedId()

    -- Véhicules
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) then
            local popType = GetEntityPopulationType(vehicle)
            -- PopType 7 = script spawned sans ressource identifiée
            if popType == 7 or popType == 0 then
                table.insert(unknown, {
                    handle = vehicle,
                    type = 'vehicle',
                    model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)) or 'unknown',
                    coords = GetEntityCoords(vehicle)
                })
            end
        end
    end

    -- Peds
    for _, ped in ipairs(GetGamePool('CPed')) do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
            local popType = GetEntityPopulationType(ped)
            if popType == 7 or popType == 0 then
                table.insert(unknown, {
                    handle = ped,
                    type = 'ped',
                    model = GetEntityModel(ped),
                    coords = GetEntityCoords(ped)
                })
            end
        end
    end

    -- Objects
    for _, object in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(object) then
            local popType = GetEntityPopulationType(object)
            if popType == 7 or popType == 0 then
                table.insert(unknown, {
                    handle = object,
                    type = 'object',
                    model = GetEntityModel(object),
                    coords = GetEntityCoords(object)
                })
            end
        end
    end

    return unknown
end

-- Téléporter vers une entité unknown
function TeleportToEntity(coords)
    local playerPed = PlayerPedId()
    SetEntityCoords(playerPed, coords.x, coords.y, coords.z + 1.0, false, false, false, false)
end

-- Callback NUI pour debug
RegisterNUICallback('toggleDebug', function(data, cb)
    ToggleDebugMode()
    cb('ok')
end)

RegisterNUICallback('teleportToMLO', function(data, cb)
    if data.coords then
        TeleportToEntity(vector3(data.coords.x, data.coords.y, data.coords.z))
    end
    cb('ok')
end)

-- Thread pour afficher les markers en debug mode
CreateThread(function()
    while true do
        if debugMode then
            local playerCoords = GetEntityCoords(PlayerPedId())

            for _, entity in ipairs(GetUnknownEntities()) do
                local dist = #(playerCoords - entity.coords)
                if dist < 50.0 then
                    -- Marker au dessus de l'entité
                    local color = {r = 255, g = 255, b = 0} -- Yellow par défaut
                    if entity.type == 'vehicle' then
                        color = {r = 0, g = 150, b = 255}
                    elseif entity.type == 'ped' then
                        color = {r = 0, g = 255, b = 100}
                    elseif entity.type == 'object' then
                        color = {r = 255, g = 150, b = 0}
                    end

                    DrawMarker(
                        1, -- Type
                        entity.coords.x, entity.coords.y, entity.coords.z + 2.0,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        0.5, 0.5, 0.5,
                        color.r, color.g, color.b, 150,
                        true, false, 2, false, nil, nil, false
                    )

                    -- Texte 3D
                    if dist < 15.0 then
                        Draw3DText(entity.coords.x, entity.coords.y, entity.coords.z + 2.5,
                            ("[%s]\n%s"):format(entity.type:upper(), entity.model))
                    end
                end
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Helper: Texte 3D
function Draw3DText(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- Vérifier si un objet est un prop de vêtement
function IsClothingProp(model)
    -- Vérifier dans la liste connue
    if clothingProps[model] then
        return true, clothingProps[model]
    end
    return false, nil
end

-- Obtenir tous les props de vêtements orphelins
function GetOrphanClothingProps()
    local orphans = {}
    local objects = GetGamePool('CObject')

    for _, object in ipairs(objects) do
        if DoesEntityExist(object) then
            local model = GetEntityModel(object)
            local isClothing, clothingType = IsClothingProp(model)

            if isClothing then
                -- Vérifier si attaché à un ped
                local isAttached = IsEntityAttached(object)
                local attachedTo = nil

                if isAttached then
                    attachedTo = GetEntityAttachedTo(object)
                    -- Si attaché à un ped joueur, c'est normal
                    if attachedTo and DoesEntityExist(attachedTo) and IsEntityAPed(attachedTo) and IsPedAPlayer(attachedTo) then
                        goto continue
                    end
                end

                -- C'est un prop orphelin ou attaché à un PNJ
                table.insert(orphans, {
                    handle = object,
                    model = model,
                    type = clothingType or "Accessoire",
                    coords = GetEntityCoords(object),
                    isAttached = isAttached,
                    attachedTo = attachedTo
                })
            end
            ::continue::
        end
    end

    return orphans
end

-- Analyser tous les problèmes potentiels
function AnalyzePoolProblems()
    local problems = {
        clothing = GetOrphanClothingProps(),
        orphanVehicles = {},
        outOfBounds = {},
        duplicates = {}
    }

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    -- Véhicules orphelins (sans conducteur, loin des joueurs)
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) then
            local driver = GetPedInVehicleSeat(vehicle, -1)
            if not DoesEntityExist(driver) or not IsPedAPlayer(driver) then
                local vehCoords = GetEntityCoords(vehicle)
                local closestPlayer = GetClosestPlayer(vehCoords)
                if closestPlayer > 100.0 then -- Plus de 100m de tout joueur
                    table.insert(problems.orphanVehicles, {
                        handle = vehicle,
                        model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)),
                        coords = vehCoords,
                        distanceToPlayer = closestPlayer
                    })
                end
            end
        end
    end

    -- Entités hors map
    for _, entity in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(entity) then
            local coords = GetEntityCoords(entity)
            -- Sous la map ou très haut
            if coords.z < -50.0 or coords.z > 1500.0 then
                table.insert(problems.outOfBounds, {
                    handle = entity,
                    type = 'object',
                    coords = coords
                })
            end
        end
    end

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) then
            local coords = GetEntityCoords(vehicle)
            if coords.z < -50.0 or coords.z > 1500.0 then
                table.insert(problems.outOfBounds, {
                    handle = vehicle,
                    type = 'vehicle',
                    model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)),
                    coords = coords
                })
            end
        end
    end

    -- Détecter les duplicatas (entités au même endroit exact)
    local positionMap = {}
    for _, object in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(object) then
            local coords = GetEntityCoords(object)
            local key = string.format("%.1f_%.1f_%.1f", coords.x, coords.y, coords.z)
            if not positionMap[key] then
                positionMap[key] = {count = 0, entities = {}, coords = coords}
            end
            positionMap[key].count = positionMap[key].count + 1
            table.insert(positionMap[key].entities, object)
        end
    end

    for key, data in pairs(positionMap) do
        if data.count > 3 then -- Plus de 3 objets au même endroit = suspect
            table.insert(problems.duplicates, {
                coords = data.coords,
                count = data.count,
                entities = data.entities
            })
        end
    end

    return problems
end

-- Distance au joueur le plus proche
function GetClosestPlayer(coords)
    local closestDist = 9999.0
    local players = GetActivePlayers()

    for _, player in ipairs(players) do
        local ped = GetPlayerPed(player)
        if DoesEntityExist(ped) then
            local playerCoords = GetEntityCoords(ped)
            local dist = #(coords - playerCoords)
            if dist < closestDist then
                closestDist = dist
            end
        end
    end

    return closestDist
end

-- Supprimer les props vêtements orphelins
function CleanOrphanClothing()
    local orphans = GetOrphanClothingProps()
    local count = 0

    for _, prop in ipairs(orphans) do
        if DoesEntityExist(prop.handle) then
            DeleteEntity(prop.handle)
            count = count + 1
        end
    end

    print(("^2[EntityMonitor]^0 %d props de vêtements supprimés"):format(count))
    return count
end

-- Callback NUI pour analyser les problèmes
RegisterNUICallback('analyzeProblems', function(data, cb)
    local problems = AnalyzePoolProblems()
    cb(problems)
end)

RegisterNUICallback('cleanClothing', function(data, cb)
    local count = CleanOrphanClothing()
    cb({cleaned = count})
end)

RegisterNUICallback('deleteEntity', function(data, cb)
    if data.handle and DoesEntityExist(data.handle) then
        DeleteEntity(data.handle)
        cb({success = true})
    else
        cb({success = false})
    end
end)

print("^2[EntityMonitor]^0 Client chargé - F7 pour ouvrir (si admin)")
