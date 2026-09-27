local lang = pr_lib.locale()
local pendingSlot = nil
local pendingBag = nil
local currentBagProp = nil
local currentPropModel = nil
local currentClothing = nil
local previewActive = false
local refreshGeneration = 0

BackpackProfiles = BackpackProfiles or {}
ItemModels = ItemModels or {}
Backpacks = BackpackProfiles

forgeBackpackClient = {}

local function ResetBackpack()
    if currentBagProp and DoesEntityExist(currentBagProp) then
        DeleteEntity(currentBagProp)
    end

    currentBagProp = nil
    currentPropModel = nil

    if currentClothing then
        SetPedComponentVariation(PlayerPedId(), 5, 0, 0, 0)
        currentClothing = nil
    end
end

local function ApplyBackpackClothing(bagConfig)
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local gender = (model == joaat("mp_f_freemode_01")) and "female" or "male"
    local clothing = bagConfig.clothing and bagConfig.clothing[gender]

    if not clothing then return end

    if GetPedDrawableVariation(ped, clothing.component) ~= clothing.drawable
        or GetPedTextureVariation(ped, clothing.component) ~= clothing.texture then
        SetPedComponentVariation(
            ped,
            clothing.component,
            clothing.drawable,
            clothing.texture,
            0
        )
    end
    currentClothing = clothing.drawable
end

local function ApplyBackpackProp(bagConfig)
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local gender = (model == joaat("mp_f_freemode_01")) and "female" or "male"
    local propModel = bagConfig.props[gender]
    local settings = bagConfig.propSettings[gender]

    if propModel ~= currentPropModel or not currentBagProp
        or not DoesEntityExist(currentBagProp) or not IsEntityAttachedToEntity(currentBagProp, ped) then
        ResetBackpack()
        local modelHash = joaat(propModel)
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do Wait(0) end
        currentBagProp = CreateObject(modelHash, 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(
            currentBagProp,
            ped,
            GetPedBoneIndex(ped, settings.bone),
            settings.x, settings.y, settings.z,
            settings.rx, settings.ry, settings.rz,
            true, true, false, true, 1, true
        )
        SetModelAsNoLongerNeeded(modelHash)
        currentPropModel = propModel
    end
end


CreateThread(function()
    local coords = Config.BackpackShop.coords
    local model = joaat(Config.BackpackShop.ped)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    local ped = CreatePed(
        0,
        model,
        coords.x,
        coords.y,
        coords.z - 1.0,
        coords.w,
        false,
        false
    )
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    if Config.BackpackShop.blip and Config.BackpackShop.blip.enabled then
        local blip = AddBlipForCoord(coords.xyz)
        SetBlipSprite(blip, Config.BackpackShop.blip.sprite)
        SetBlipScale(blip, Config.BackpackShop.blip.scale)
        SetBlipColour(blip, Config.BackpackShop.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(lang("shop.blip"))
        EndTextCommandSetBlipName(blip)
    end

    pr_lib.target.addLocalEntity(ped, {
        {
            icon = "fa-solid fa-store",
            label = lang("shop.target"),
            onSelect = function()
                TriggerEvent("forge-backpack:openShopMenu")
            end,
            distance = 2.0
        }
    })
end)

local function RefreshBackpack()
    if previewActive then return end
    if not pr_lib.framework.IsPlayerLoaded() then return end
    local items = pr_lib.inventory.GetPlayerItems and pr_lib.inventory.GetPlayerItems() or {}

    for _, item in pairs(items) do
        local bagConfig = forgeBackpack.ResolveFromItem(item, BackpackProfiles, ItemModels)
        if bagConfig then
            if Config.BackpackStyle == "clothing" then
                ApplyBackpackClothing(bagConfig)
            else
                ApplyBackpackProp(bagConfig)
            end
            return
        end
    end

    ResetBackpack()
end

AddEventHandler("forge-backpack:openShopMenu", function()
    local options = {}

    for profileId, data in pairs(BackpackProfiles) do
        if data.shopEnabled then
            local itemModel = data.itemModel or Config.BackpackItems[1]
            local modelData = ItemModels[itemModel] or {}
            local iconPath

            if modelData.image then
                local image = modelData.image
                if image:find("://") then
                    iconPath = image
                elseif pr_lib.inventory.getInventoryImg then
                    local file = image
                    if not (file:match("%.png$") or file:match("%.webp$") or file:match("%.jpg$") or file:match("%.jpeg$")) then
                        file = file .. ".png"
                    end
                    iconPath = pr_lib.inventory.getInventoryImg(file)
                elseif pr_lib.inventory.GetImagePath then
                    iconPath = pr_lib.inventory.GetImagePath(image)
                end
            end

            if not iconPath then
                if pr_lib.inventory.getInventoryImg then
                    iconPath = pr_lib.inventory.getInventoryImg(itemModel .. ".png")
                elseif pr_lib.inventory.GetImagePath then
                    iconPath = pr_lib.inventory.GetImagePath(itemModel)
                end
            end

            options[#options + 1] = {
                title = data.label,
                description = lang("shop.price", { price = data.price }),
                image = iconPath,
                onSelect = function()
                    pr_lib.callback.await("forge-backpack:server:buyBackpack", 5000, profileId)
                end
            }
        end
    end

    pr_lib.menus.RegisterContext({
        id = "backpack_shop",
        title = lang("shop.title"),
        options = options
    })

    pr_lib.menus.ShowContext("backpack_shop")
end)

pr_lib.callback.register('forge-backpack:client:use', function(data)
    if type(data) ~= 'table' or not tonumber(data.slot) then return false end

    local slot = tonumber(data.slot)
    local success, bagConfig = pr_lib.callback.await('forge-backpack:server:requestOpen', 5000, slot)
    if not success or not bagConfig then return end

    pendingSlot = slot
    pendingBag = bagConfig

    if bagConfig.fixedCode then
        if pr_lib.activeBridges.inventory == "ox" then
            local input = pr_lib.menus.InputDialog(lang("backpack.secure_title"), {
                { type = 'input', label = lang("backpack.secure_code"), password = true }
            })

            if not input then return end
            local correct = pr_lib.callback.await('forge-backpack:server:validateCode', 5000, slot, input[1])
            if not correct then
                pr_lib.notifications.Notify({
                    description = lang("backpack.wrong_code"),
                    type = 'error'
                })
                return
            end
            TriggerEvent('forge-backpack:playOpen')
        else
            local options = {
                {
                    title = lang("backpack.menu_open_title"),
                    description = lang("backpack.menu_open_desc"),
                    icon = "lock-open",
                    onSelect = function()
                        local input = pr_lib.menus.InputDialog(lang("backpack.secure_title"), {
                            { type = 'input', label = lang("backpack.secure_code"), password = true }
                        })

                        if not input then return end
                        local correct = pr_lib.callback.await('forge-backpack:server:validateCode', 5000, slot, input[1])
                        if not correct then
                            pr_lib.notifications.Notify({
                                description = lang("backpack.wrong_code"),
                                type = 'error'
                            })
                            return
                        end
                        TriggerEvent('forge-backpack:playOpen')
                    end
                },
                {
                    title = lang("backpack.menu_change_password_title"),
                    description = lang("backpack.menu_change_password_desc"),
                    icon = "key",
                    onSelect = function()
                        local inputCurrent = pr_lib.menus.InputDialog(lang("backpack.menu_change_password_title"), {
                            { type = 'input', label = lang("backpack.current_password"), password = true }
                        })

                        if not inputCurrent then return end
                        local currentCode = inputCurrent[1]

                        if currentCode ~= bagConfig.fixedCode then
                            pr_lib.notifications.Notify({
                                description = lang("backpack.wrong_code"),
                                type = 'error'
                            })
                            return
                        end

                        local inputNew = pr_lib.menus.InputDialog(lang("backpack.menu_change_password_title"), {
                            { type = 'input', label = lang("backpack.new_password"), password = true }
                        })

                        if not inputNew then return end
                        local newCode = inputNew[1]

                        if newCode:gsub("%s+", "") == "" then
                            pr_lib.notifications.Notify({
                                description = lang("backpack.invalid_password"),
                                type = 'error'
                            })
                            return
                        end

                        pr_lib.callback.await('forge-backpack:server:changePassword', 5000, slot, newCode)
                    end
                }
            }

            pr_lib.menus.RegisterContext({
                id = "secure_backpack_menu",
                title = bagConfig.label,
                options = options
            })

            pr_lib.menus.ShowContext("secure_backpack_menu")
        end
    else
        TriggerEvent('forge-backpack:playOpen')
    end
end)

AddEventHandler('forge-backpack:playOpen', function()
    local ped = PlayerPedId()
    local bagConfig = pendingBag
    RequestAnimDict(bagConfig.anim.dict)
    while not HasAnimDictLoaded(bagConfig.anim.dict) do Wait(0) end
    TaskPlayAnim(
        ped,
        bagConfig.anim.dict,
        bagConfig.anim.clip,
        8.0, -8.0,
        bagConfig.openTime,
        bagConfig.anim.flag,
        0, false, false, false
    )

    local success = pr_lib.progress.doProgressbar(
        bagConfig.openTime,
        lang("backpack.opening", { label = bagConfig.label }),
        { bagConfig.anim.dict, bagConfig.anim.clip }
    )

    ClearPedTasks(ped)
    if success then
        pr_lib.callback.await('forge-backpack:server:finishOpen', 5000, pendingSlot)
    end
end)

AddEventHandler('forge-backpack:openStash', function(stashId)
    local bagConfig = pendingBag

    if pr_lib.activeBridges.inventory == "ox" then
        pr_lib.inventory.openInventory('stash', stashId)
        return
    end

    pr_lib.inventory.openInventory('stash', {
        id = stashId,
        weight = bagConfig.weight,
        slots = bagConfig.slots
    })
end)

-- O inventario e a aparencia podem terminar de carregar depois do evento de login.
local function RefreshAfterSpawn()
    refreshGeneration = refreshGeneration + 1
    local generation = refreshGeneration
    CreateThread(function()
        for _ = 1, 20 do
            Wait(1000)
            if generation ~= refreshGeneration then return end
            RefreshBackpack()
        end
    end)
end

AddEventHandler('pr_bridge:client:OnPlayerLoaded', RefreshAfterSpawn)
AddEventHandler('pr_bridge:client:OnInventoryChanged', function()
    RefreshBackpack()
end)
AddEventHandler('pr_bridge:client:OnPlayerUnloaded', function()
    refreshGeneration = refreshGeneration + 1
    previewActive = false
    ResetBackpack()
end)
AddEventHandler('playerSpawned', RefreshAfterSpawn)
RegisterNetEvent('illenium-appearance:client:reloadSkin', RefreshAfterSpawn)
RegisterNetEvent('qb-clothing:client:reloadSkin', RefreshAfterSpawn)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    refreshGeneration = refreshGeneration + 1
    ResetBackpack()
end)

AddEventHandler('forge-backpack:client:changePasswordFromMenu', function(data)
    local slot = type(data) == "table" and data.slot or data
    local items = pr_lib.inventory.GetPlayerItems and pr_lib.inventory.GetPlayerItems() or {}
    local item = items[slot]
    if not item then return end

    local bagConfig = forgeBackpack.ResolveFromItem(item, BackpackProfiles, ItemModels)
    if not bagConfig then return end

    if not bagConfig.fixedCode then
        pr_lib.notifications.Notify({
            description = lang("backpack.not_secured"),
            type = 'error'
        })
        return
    end

    local inputCurrent = pr_lib.menus.InputDialog(lang("backpack.menu_change_password_title"), {
        { type = 'input', label = lang("backpack.current_password"), password = true }
    })

    if not inputCurrent then return end
    local currentCode = inputCurrent[1]

    if currentCode ~= bagConfig.fixedCode then
        pr_lib.notifications.Notify({
            description = lang("backpack.wrong_code"),
            type = 'error'
        })
        return
    end

    local inputNew = pr_lib.menus.InputDialog(lang("backpack.menu_change_password_title"), {
        { type = 'input', label = lang("backpack.new_password"), password = true }
    })

    if not inputNew then return end
    local newCode = inputNew[1]

    if newCode:gsub("%s+", "") == "" then
        pr_lib.notifications.Notify({
            description = lang("backpack.invalid_password"),
            type = 'error'
        })
        return
    end

    pr_lib.callback.await('forge-backpack:server:changePassword', 5000, slot, newCode)
end)

local function applySyncData(data)
    if type(data) ~= "table" then return end
    BackpackProfiles = data.profiles or data or {}
    ItemModels = data.itemModels or ItemModels
    Backpacks = BackpackProfiles
    RefreshBackpack()
end

pr_lib.callback.register('forge-backpack:client:syncData', function(data)
    applySyncData(data)
end)
pr_lib.callback.register('forge-backpack:client:syncBackpacks', function(profiles)
    applySyncData({ profiles = profiles })
end)

pr_lib.callback.register("forge-backpack:client:printInventorySnippet", function(modelName, modelData)
    if type(modelName) ~= "string" or modelName == "" then return end

    local oxSnippet = forgeBackpack.BuildOxInventorySnippet(modelName, modelData)
    local qbSnippet = forgeBackpack.BuildQbInventorySnippet(modelName, modelData)
    local imageFile = forgeBackpack.GetItemImageFile(modelName, modelData)

    print("^5" .. lang("debug.snippet_separator") .. "^7")
    print(lang("debug.snippet_saved", { model = modelName }))
    print(lang("debug.snippet_ox_title"))
    print(oxSnippet)
    print(lang("debug.snippet_qb_title"))
    print(qbSnippet)
    print(lang("debug.snippet_image", { image = imageFile }))
    print("^5" .. lang("debug.snippet_separator") .. "^7")
end)

CreateThread(function()
    RefreshAfterSpawn()
    local data = pr_lib.callback.await('forge-backpack:server:requestSync', 5000)
    if data then
        applySyncData(data)
    end
end)

function forgeBackpackClient.Preview(bagConfig)
    if type(bagConfig) == "string" then
        bagConfig = forgeBackpack.Resolve(bagConfig, BackpackProfiles, ItemModels)
    end
    if not bagConfig then return end
    previewActive = true

    if Config.BackpackStyle == "clothing" then
        ApplyBackpackClothing(bagConfig)
    else
        ApplyBackpackProp(bagConfig)
    end
end

function forgeBackpackClient.ResetPreview()
    previewActive = false
    ResetBackpack()
    RefreshBackpack()
end

function forgeBackpackClient.Refresh()
    RefreshBackpack()
end

pr_lib.addCommand('debugmochila', {
    help = lang("command.debugmochila_help")
}, function()
    print(lang("debug.debug_title"))
    print(lang("debug.active_bridge", { bridge = tostring(pr_lib.activeBridges.inventory) }))
    
    local success, clientItems = pcall(function() return pr_lib.inventory.Items() end)
    if not success then
        print(lang("debug.error_calling_inventory", { error = tostring(clientItems) }))
    else
        if clientItems and clientItems['large_backpack'] then
            print(lang("debug.item_found", { item = 'large_backpack' }))
            print(lang("debug.label", { label = tostring(clientItems['large_backpack'].label) }))
            print(lang("debug.buttons", { buttons = tostring(json.encode(clientItems['large_backpack'].buttons)) }))
        else
            print(lang("debug.item_not_found", { item = 'large_backpack' }))
        end
        
        if clientItems and clientItems['backpack'] then
            print(lang("debug.item_found", { item = 'backpack' }))
            print(lang("debug.buttons", { buttons = tostring(json.encode(clientItems['backpack'].buttons)) }))
        end
    end
    print(lang("debug.debug_footer"))
end)

pr_lib.addCommand('mochilasenha', {
    help = lang("command.mochilasenha_help")
}, function()
    local items = pr_lib.inventory.GetPlayerItems and pr_lib.inventory.GetPlayerItems() or {}
    local options = {}

    for slot, item in pairs(items) do
        if type(item) == "table" then
            local bagConfig = forgeBackpack.ResolveFromItem(item, BackpackProfiles, ItemModels)
            if bagConfig and bagConfig.fixedCode then
                local slotNum = tonumber(slot) or item.slot or slot
                options[#options + 1] = {
                    title = lang("backpack.slot_label", { label = bagConfig.label, slot = slotNum }),
                    onSelect = function()
                        TriggerEvent('forge-backpack:client:changePasswordFromMenu', slotNum)
                    end
                }
            end
        end
    end

    if #options == 0 then
        pr_lib.notifications.Notify({
            description = lang("backpack.no_secured_backpacks"),
            type = 'error'
        })
        return
    end

    pr_lib.menus.RegisterContext({
        id = "change_backpack_password_menu",
        title = lang("backpack.menu_change_password_title"),
        options = options
    })

    pr_lib.menus.ShowContext("change_backpack_password_menu")
end)
