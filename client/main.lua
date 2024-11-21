local ownedTrain, bombTable, ModelsLoaded = {}, {}, false

local shopMenu = {
    id = 'shop_menu',
    title = 'Train Shop',
    options = {}
}

local garageMenu = {
    id = 'garage_menu',
    title = 'Train Station',
    options = {}
}

local pathMenu = {
    id = 'path_menu',
    title = Config.Lang["ChooseTrail"],
    options = {}
}

function loadData()
    Citizen.Wait(5000)
    if Config.FrameWork == "custom" then
        TriggerServerEvent("az_train:getTrains")
    else
        Config.CallBack(
            "az_train:getMyTrain",
            function(result)
                for k, v in pairs(result) do
                    ownedTrain[k] = {}
                    for x, w in pairs(v) do
                        ownedTrain[k][x] = w
                    end
                end
            end
        )
    end
end

RegisterNetEvent(
    "az_train:getTrains",
    function(result)
        for k, v in pairs(result) do
            ownedTrain[k] = {}
            for x, w in pairs(v) do
                ownedTrain[k][x] = w
            end
        end
    end
)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName == GetCurrentResourceName() then
            for k, v in pairs(Config.Stations) do
                DeleteEntity(v.pnj)
                RemoveBlip(v.blip)
            end
            for k, v in pairs(Config.TrainShop) do
                DeleteEntity(v.pnj)
                RemoveBlip(v.blip)
            end
        end
    end
)

AddEventHandler(
    "onResourceStart",
    function(resourceName)
        if resourceName == GetCurrentResourceName() then
            loadData()
        end
    end
)

RegisterNetEvent(
    "az_train:newTrain",
    function(data)
        table.insert(ownedTrain, data)
        Config.SendNotification(Config.Lang["Bought"] .. data.label)
        Config.SendNotification(string.format(Config.Lang["TrainStockIn"], Config.Stations[data.station].label))
    end
)

function openMenu(index)
    local menuOptions = {}

    for k, v in pairs(Config.TrainShop[index].traintobuy) do
        for x, w in pairs(Config.Trains) do
            if w.trainindex == v then
                local canAccess = Config.CanAccess(Config.TrainShop[index].job)
                table.insert(menuOptions, {
                    title = w.label,
                    description = canAccess and
                        string.format(Config.Lang["TrainInfos"], w.price, w.storage) or
                        Config.Lang["AccessDenied"],
                    onSelect = function()
                        TriggerServerEvent("az_train:buyTrain", w)
                    end,
                    disabled = not canAccess
                })
            end
        end
    end

    shopMenu.options = menuOptions
    exports.ox_lib:registerContext(shopMenu)
    exports.ox_lib:showContext('shop_menu')
end

function openGarageMenu(index)
    local menuOptions = {}

    for k, v in pairs(ownedTrain) do
        if Config.Stations[index].metrostation and v.trainindex ~= Config.MetroIndex then
            goto skipThisTrain
        end
        if v.station == index then
            table.insert(menuOptions, {
                title = string.format(Config.Lang["GetOutTrain"], v.label),
                description = string.format(Config.Lang["TrainInfos"], v.price, v.storage),
                onSelect = function()
                    openPathMenu(v.uniqueID, index)
                end,
                disabled = v.state ~= "in"
            })
        end
        ::skipThisTrain::
    end

    garageMenu.options = menuOptions
    exports.ox_lib:registerContext(garageMenu)
    exports.ox_lib:showContext('garage_menu')
end

function openPathMenu(uniqueID, index)
    local menuOptions = {}

    for k, v in pairs(Config.Stations[index].path) do
        table.insert(menuOptions, {
            title = Config.Lang["Track"] .. k,
            onSelect = function()
                getOutTrain(uniqueID, v)
            end,
            onActive = function()
                DrawMarker(
                    20,
                    v.x,
                    v.y,
                    v.z + 1.1,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    180.0,
                    0.0,
                    0.3,
                    0.,
                    0.3,
                    255,
                    255,
                    255,
                    200,
                    1,
                    true,
                    2,
                    0,
                    nil,
                    nil,
                    0
                )
            end
        })
    end

    pathMenu.options = menuOptions
    exports.ox_lib:registerContext(pathMenu)
    exports.ox_lib:showContext('path_menu')
end
--[[
function getOutTrain(uniqueID, coords)
    if ModelsLoaded then
        for k, v in pairs(ownedTrain) do
            if v.uniqueID == uniqueID and coords ~= nil and v.trainindex ~= nil then
                local tempTrain = CreateMissionTrain(v.trainindex, coords.x, coords.y, coords.z, false)
                while not DoesEntityExist(tempTrain) do
                    Citizen.Wait(500)
                end
                NetworkRegisterEntityAsNetworked(tempTrain)
                SetTrainSpeed(tempTrain, 0)
                SetTrainCruiseSpeed(tempTrain, 0)
                TriggerServerEvent("az_train:syncAction", v.uniqueID, v.storage, VehToNet(tempTrain))
                TriggerServerEvent("az_train:changeState", v.uniqueID, "out")
                break
            end
        end
    else
        Config.SendNotification(Config.Lang["ProblemChargeTrain"])
    end
end
]]
function getOutTrain(uniqueID, coords)
    if ModelsLoaded then
        for k, v in pairs(ownedTrain) do
            if v.uniqueID == uniqueID and coords ~= nil and v.trainindex ~= nil then
                local tempTrain = CreateMissionTrain(v.trainindex, coords.x, coords.y, coords.z, false)
                while not DoesEntityExist(tempTrain) do
                    Citizen.Wait(500)
                end
                NetworkRegisterEntityAsNetworked(tempTrain)
                SetTrainSpeed(tempTrain, 0)
                SetTrainCruiseSpeed(tempTrain, 0)
                TriggerServerEvent("az_train:syncAction", v.uniqueID, v.storage, VehToNet(tempTrain))
                TriggerServerEvent("az_train:changeState", v.uniqueID, "out")

                -- Register targets for carriages
                registerCarriageTargets(tempTrain, uniqueID, v.storage)
                
                break
            end
        end
    else
        Config.SendNotification(Config.Lang["ProblemChargeTrain"])
    end
end

RegisterNetEvent(
    "az_train:syncAction",
    function(uniqueID, storage, vehNet)
        Citizen.CreateThread(
            function()
                local tempTrain = NetToVeh(vehNet)
                while tempTrain == 0 do
                    tempTrain = NetToVeh(vehNet)
                    Citizen.Wait(1000)
                end
                local maxSpeed = 27
                for k, v in pairs(ownedTrain) do
                    if v.uniqueID == uniqueID then
                        maxSpeed = v.maxSpeed
                        break
                    end
                end
                Citizen.CreateThread(
                    function()
                        while DoesEntityExist(tempTrain) do
                            local wait = 1000
                            if
                                GetDistanceBetweenCoords(
                                    GetEntityCoords(PlayerPedId()),
                                    GetEntityCoords(tempTrain),
                                    true
                                ) < 40
                             then
                                wait = 0
                                if
                                    GetDistanceBetweenCoords(
                                        GetEntityCoords(PlayerPedId()),
                                        GetEntityCoords(tempTrain),
                                        true
                                    ) < 7 and not IsPedInAnyVehicle(PlayerPedId(), true)
                                 then
                                    --Config.HelpNotification(Config.Lang["TrainInfo"])
                                    if IsControlJustReleased(0, 23) then
                                        SetPedIntoVehicle(PlayerPedId(), tempTrain, -1)
                                        Citizen.Wait(1000)
                                        local speed = 0
                                        Citizen.CreateThread(
                                            function()
                                                while GetPedInVehicleSeat(tempTrain, -1) == PlayerPedId() do
                                                    local wait2 = 1000
                                                    for x, w in pairs(Config.Stations) do
                                                        if
                                                            GetDistanceBetweenCoords(
                                                                GetEntityCoords(tempTrain),
                                                                w.coordsdeletetrain,
                                                                true
                                                            ) < 20
                                                         then
                                                            wait2 = 0
                                                            Config.HelpNotification(Config.Lang["StowTrain"])
                                                            if IsControlJustReleased(0, 38) then
                                                                DeleteMissionTrain(tempTrain)
                                                                TriggerServerEvent(
                                                                    "az_train:changeState",
                                                                    uniqueID,
                                                                    "in",
                                                                    x
                                                                )
                                                            end
                                                        end
                                                    end
                                                    Citizen.Wait(wait2)
                                                end
                                            end
                                        )
                                        Citizen.CreateThread(function()
											local speed = 0
											local maxSpeed = 20 -- Adjust this value as needed

											while GetPedInVehicleSeat(tempTrain, -1) == PlayerPedId() do
												-- Handle exiting the vehicle
												if IsControlJustReleased(0, 23) then
													speed = 0
													SetTrainCruiseSpeed(tempTrain, speed)
													TaskLeaveVehicle(PlayerPedId(), tempTrain, 0)
												end

												-- Handle train speed control
												if IsControlPressed(0, 71) then -- Forward (W)
													if speed < maxSpeed then
														speed = speed + 0.02
													end
												elseif IsControlPressed(0, 72) then -- Backwards (S)
													if speed > -10 then -- Adjusted condition for reverse speed
														speed = speed - 0.05
													end
												elseif IsControlPressed(0, 73) then -- E Break (X)
													speed = 0
												end

												-- Apply the calculated speed to the train
												SetTrainCruiseSpeed(tempTrain, speed)
												Citizen.Wait(0)
											end
										end)
                                    end
                                end
                            end
                            Citizen.Wait(wait)
                        end
                    end
                )
            end
        )
    end
)





Citizen.CreateThread(
    function()
        DeleteAllTrains()
        RequestModelSync("freight")
        RequestModelSync("freightcar")
        RequestModelSync("freightcar2")
        RequestModelSync("freightgrain")
        RequestModelSync("freightcont1")
        RequestModelSync("freightcont2")
        RequestModelSync("freighttrailer")
        RequestModelSync("tankercar")
        RequestModelSync("metrotrain")
        RequestModelSync("s_m_m_lsmetro_01")
        ModelsLoaded = true
        for k, v in pairs(Config.TrainShop) do
            if not Config.UseMetro and v.metrostation then
                goto skipThisTrainShop
            end
          --  v.blip = Config.CreateBlip(v.coordspnj.xyz, 0.5, string.format(Config.Lang["TrainShop"], k), 569, 0)
            v.pnj = Config.CreatePNJ(v.coordspnj, v.pedmodel, false)
            if Config.UseOxTarget then
                exports.ox_target:addLocalEntity(
                    v.pnj,
                    {
                        {
                            icon = "fa-solid fa-train",
                            label = Config.Lang["OpenShopOxTarget"],
                            canInteract = function(entity, distance, coords)
                                return true
                            end,
                            onSelect = function(data)
                                openMenu(k)
                            end
                        }
                    }
                )
            else
                Citizen.CreateThread(
                    function()
                        while true do
                            local wait = 1000
                            if GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), v.coordspnj.xyz, true) < 2 then
                                wait = 0
                                Config.HelpNotification(Config.Lang["OpenTrainShop"])
                                if IsControlJustReleased(0, 38) then
                                    openMenu(k)
                                end
                            end
                            Citizen.Wait(wait)
                        end
                    end
                )
            end
            ::skipThisTrainShop::
        end
        for k, v in pairs(Config.Stations) do
            if not Config.UseMetro and v.metrostation then
                goto skipThisStation
            end
          --  v.blip =
          --      Config.CreateBlip(
          --      v.coordspnj.xyz,
          --      0.5,
          --      string.format(Config.Lang["TrainStation"], v.label),
          --      v.metrostation and 435 or 309,
          --      0
          --  )
            v.pnj = Config.CreatePNJ(v.coordspnj, v.pedmodel, false)
            if Config.UseOxTarget then
                exports.ox_target:addLocalEntity(
                    v.pnj,
                    {
                        {
                            icon = "fa-solid fa-train",
                            label = Config.Lang["OpenStationOxTarget"],
                            canInteract = function(entity, distance, coords)
                                return true
                            end,
                            onSelect = function(data)
                                openGarageMenu(k)
                            end
                        }
                    }
                )
            else
                Citizen.CreateThread(
                    function()
                        while true do
                            local wait = 1000
                            if GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), v.coordspnj.xyz, true) < 2 then
                                wait = 0
                                Config.HelpNotification(Config.Lang["OpenStation"])
                                if IsControlJustReleased(0, 38) then
                                    openGarageMenu(k)
                                end
                            end
                            Citizen.Wait(wait)
                        end
                    end
                )
            end
            ::skipThisStation::
        end
    end
)

RegisterNetEvent(
    "az_train:changeState",
    function(uniqueID, state, lastStation)
        for k, v in pairs(ownedTrain) do
            if v.uniqueID == uniqueID then
                v.state = state
                if lastStation ~= nil then
                    v.station = lastStation
                end
            end
        end
    end
)

RegisterNetEvent(
    "az_train:poseBomb",
    function()
        Config.SendNotification(Config.Lang["BombPose"])
        -- Do some animation here
    end
)

RegisterNetEvent(
    "az_train:removeBomb",
    function(position)
        for k, v in pairs(bombTable) do
            if v.position == position then
                DeleteEntity(v.object)
                break
            end
        end
    end
)

RegisterNetEvent(
    "az_train:repairTrain",
    function()
        Config.SendNotification(Config.Lang["RepairInProgress"])
        local vehicle, distance = GetClosetVehicle()
        if distance < 15 and GetVehicleClass(vehicle) == 21 then
            SetRenderTrainAsDerailed(vehicle, false)
            FreezeEntityPosition(vehicle, false)
        end
    end
)

RegisterNetEvent(
    "az_train:poseBombAll",
    function(position)
        if not HasModelLoaded("prop_ld_bomb") then
            RequestModel("prop_ld_bomb")
            while not HasModelLoaded("prop_ld_bomb") do
                Citizen.Wait(500)
            end
        end
        local bombObject = CreateObject(GetHashKey("prop_ld_bomb"), position.xyz, false, false, false)
        PlaceObjectOnGroundProperly(bombObject)
        SetEntityRotation(bombObject, -100.0, 0.0, 0.0, 0.0, false)
        FreezeEntityPosition(bombObject, true)
        table.insert(bombTable, {position = position, object = bombObject})
        Citizen.CreateThread(
            function()
                while DoesEntityExist(bombObject) do
                    local wait = 1000
                    if GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), position, true) < 30 then
                        wait = 500
                        if
                            GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), position, true) < 15 and
                                GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 and
                                GetVehicleClass(GetVehiclePedIsIn(PlayerPedId(), false)) == 21
                         then
                            wait = 0
                            AddExplosion(position, 81, 50, true, false, true, true)
                            SetRenderTrainAsDerailed(GetVehiclePedIsIn(PlayerPedId(), false), true)
                            SetTrainCruiseSpeed(GetVehiclePedIsIn(PlayerPedId(), false), 0)
                            FreezeEntityPosition(GetVehiclePedIsIn(PlayerPedId(), false), true)
                            TriggerServerEvent("az_train:removeBomb", position)
                        elseif GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), position, true) < 2 then
                            wait = 0
                            Config.HelpNotification(Config.Lang["BombDefuse"])
                            if IsControlJustReleased(0, 38) then
                                Config.SendNotification(Config.Lang["BombRemove"])
                                TriggerServerEvent("az_train:removeBomb", position)
                            end
                        end
                    end
                    Citizen.Wait(wait)
                end
            end
        )
    end
)

function RequestModelSync(mod)
    tempmodel = GetHashKey(mod)
    RequestModel(tempmodel)
    while not HasModelLoaded(tempmodel) do
        Citizen.Wait(1)
    end
end

function GetClosetVehicle()
    local vehicle = 0
    local distance = 100

    local pPos = GetEntityCoords(PlayerPedId())
    for k, v in pairs(GetGamePool("CVehicle")) do
        local position = GetEntityCoords(v)
        local distanceToVehicle = GetDistanceBetweenCoords(pPos, position, true)
        if distanceToVehicle < distance then
            vehicle = v
            distance = distanceToVehicle
        end
    end

    return vehicle, distance
end

function registerCarriageTargets(tempTrain, uniqueID, storage)
    for i = 0, 100 do
        local carriage = GetTrainCarriage(tempTrain, i)
        if carriage == 0 then
            break
        end
        local backTrailer = GetOffsetFromEntityInWorldCoords(carriage, 0.0, -8.3, 1.0)

        exports.ox_target:addLocalEntity(carriage, {
            {
                icon = "fa-solid fa-box",
                label = Config.Lang["OpenStash"],
                onSelect = function()
                    Config.OpenStash(uniqueID, storage, i)
                end
            }
        })
    end
end

-- 
local currentTrain = nil -- Variable to store the current train

local function handleDoorAnimation(currentTrain, carriage, doorIndices, opening)
    local doorstate = opening and 0.0 or 1.0
    local step = opening and 0.01 or -0.01
    local waitTime = opening and 1 or 2

    while (opening and doorstate <= 1.0) or (not opening and doorstate >= 0.0) do
        for _, index in ipairs(doorIndices) do
            SetTrainDoorOpenRatio(currentTrain, index, doorstate)
            SetTrainDoorOpenRatio(carriage, index, doorstate)
        end
        doorstate = doorstate + step
        Citizen.Wait(waitTime)
    end
end

Citizen.CreateThread(function()
    SetTrainsForceDoorsOpen(0)
    while true do
        Citizen.Wait(0)
        if IsPedInAnyVehicle(PlayerPedId(), true) then
            currentTrain = GetVehiclePedIsIn(PlayerPedId(), false) -- Get the current train the player is in
            if currentTrain then
                local carriage = GetTrainCarriage(currentTrain, 1)
                local serverId = GetPlayerServerId(PlayerId())

                if IsControlJustReleased(0, 108) then
                    local doorstate = GetTrainDoorOpenRatio(currentTrain, 0)
                    local opening = doorstate <= 0.05
                    TriggerServerEvent('Train:' .. (opening and 'opendoor' or 'closeDoor'), 1, NetworkGetNetworkIdFromEntity(currentTrain), NetworkGetNetworkIdFromEntity(carriage), serverId)
                    handleDoorAnimation(currentTrain, carriage, {0, 2}, opening)
                elseif IsControlJustReleased(0, 109) then
                    local doorstate = GetTrainDoorOpenRatio(currentTrain, 1)
                    local opening = doorstate <= 0.05
                    TriggerServerEvent('Train:' .. (opening and 'opendoor' or 'closeDoor'), 0, NetworkGetNetworkIdFromEntity(currentTrain), NetworkGetNetworkIdFromEntity(carriage), serverId)
                    handleDoorAnimation(currentTrain, carriage, {1, 3}, opening)
                    if opening then
                        SetVehicleDoorOpen(currentTrain, 1, false, false)
                        SetVehicleDoorOpen(currentTrain, 3, false, false)
                        SetVehicleDoorOpen(carriage, 0, false, false)
                        SetVehicleDoorOpen(carriage, 2, false, false)
                    else
                        SetVehicleDoorShut(currentTrain, 1, false)
                        SetVehicleDoorShut(currentTrain, 3, false)
                        SetVehicleDoorShut(carriage, 0, false)
                        SetVehicleDoorShut(carriage, 2, false)
                    end
                end
            end
        end
    end
end)

RegisterNetEvent('Train:opendoor')
AddEventHandler('Train:opendoor', function(direction, trainNetworkId, carriageNetworkId, serverId)
    if not NetworkDoesEntityExistWithNetworkId(trainNetworkId) or not NetworkDoesEntityExistWithNetworkId(carriageNetworkId) then
        print("No such entity: train or carriage does not exist")
        return
    end
    if serverId == GetPlayerServerId(PlayerId()) then
        return
    end
    local train = NetworkGetEntityFromNetworkId(trainNetworkId)
    local carriage = NetworkGetEntityFromNetworkId(carriageNetworkId)
    handleDoorAnimation(train, carriage, direction == 1 and {0, 2} or {1, 3}, true)
end)

RegisterNetEvent('Train:closeDoor')
AddEventHandler('Train:closeDoor', function(direction, trainNetworkId, carriageNetworkId, serverId)
    if not NetworkDoesEntityExistWithNetworkId(trainNetworkId) or not NetworkDoesEntityExistWithNetworkId(carriageNetworkId) then
        print("No such entity: train or carriage does not exist")
        return
    end
    if serverId == GetPlayerServerId(PlayerId()) then
        return
    end
    local train = NetworkGetEntityFromNetworkId(trainNetworkId)
    local carriage = NetworkGetEntityFromNetworkId(carriageNetworkId)
    handleDoorAnimation(train, carriage, direction == 1 and {0, 2} or {1, 3}, false)
end)