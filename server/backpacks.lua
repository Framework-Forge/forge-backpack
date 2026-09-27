local lang = pr_lib.locale()

local resourceName = GetCurrentResourceName()
local DATA_FILE = 'data/backpacks.json'

BackpackProfiles = {}
ItemModels = {}
Backpacks = BackpackProfiles

local function deepCopy(value)
    return json.decode(json.encode(value))
end

local function defaultItemModelFallback(modelName)
    if Config.DefaultItemModels[modelName] then
        return Config.DefaultItemModels[modelName]
    end

    if Config.DefaultItemModels.backpack then
        return Config.DefaultItemModels.backpack
    end

    return Config.DefaultItemModels[Config.BackpackItems[1]]
end

local function isValidModelName(modelName)
    return type(modelName) == "string"
        and modelName ~= ""
        and modelName:match("^[%w_]+$") ~= nil
end

local function getFirstItemModel()
    for modelName in pairs(ItemModels) do
        return modelName
    end

    return Config.BackpackItems[1]
end

local function defaultProfileTemplate()
    return {
        label = lang("admin.default_label"),
        itemModel = getFirstItemModel(),
        price = 500,
        shopEnabled = false,
        slots = 30,
        weight = 100000,
        openTime = 5000,
        fixedCode = false,
        jobLock = false,
        allowCivilians = true,
    }
end

local function profileDefaultsForModel(itemModel)
    for _, profile in pairs(BackpackProfiles) do
        if profile.itemModel == itemModel then
            local copy = deepCopy(profile)
            local modelData = ItemModels[itemModel]
            if modelData and modelData.label then
                copy.label = modelData.label
            end
            return copy
        end
    end

    local template = defaultProfileTemplate()
    template.itemModel = itemModel

    local modelData = ItemModels[itemModel]
    if modelData and modelData.label then
        template.label = modelData.label
    end

    return template
end

local function normalizeProfile(data)
    data = type(data) == "table" and data or defaultProfileTemplate()
    data.label = data.label or lang("admin.default_label")
    data.itemModel = data.itemModel or Config.BackpackItems[1]
    data.slots = tonumber(data.slots) or 30
    data.weight = tonumber(data.weight) or 100000
    data.price = tonumber(data.price) or 0
    data.openTime = tonumber(data.openTime) or 5000
    data.shopEnabled = data.shopEnabled == true
    data.allowCivilians = data.allowCivilians ~= false

    if not ItemModels[data.itemModel] then
        data.itemModel = getFirstItemModel()
    end

    if data.fixedCode == "" or data.fixedCode == "false" then
        data.fixedCode = false
    end

    if data.jobLock == "" or data.jobLock == "false" or data.jobLock == false then
        data.jobLock = false
    elseif type(data.jobLock) == "string" then
        local jobs = {}
        for job in data.jobLock:gmatch("[^,%s]+") do
            jobs[#jobs + 1] = job
        end
        data.jobLock = #jobs > 0 and jobs or false
    end

    return data
end

local function normalizeItemModel(data, fallback)
    fallback = fallback or defaultItemModelFallback("backpack")
    data = type(data) == "table" and data or deepCopy(fallback)
    data.label = data.label or fallback.label or "Backpack Model"
    data.image = (data.image and data.image ~= "") and data.image or nil
    data.props = data.props or deepCopy(fallback.props)
    data.propSettings = data.propSettings or deepCopy(fallback.propSettings)
    data.clothing = data.clothing or deepCopy(fallback.clothing)
    data.anim = data.anim or deepCopy(fallback.anim)
    return data
end

local function migrateLegacyData(decoded)
    if decoded.profiles and decoded.itemModels then
        return decoded
    end

    local itemModels = deepCopy(Config.DefaultItemModels)
    local profiles = {}

    for key, data in pairs(decoded) do
        if key ~= "itemModels" and key ~= "profiles" and type(data) == "table" then
            profiles[key] = normalizeProfile({
                label = data.label,
                itemModel = forgeBackpack.IsItemModel(key) and key or Config.BackpackItems[1],
                price = data.price,
                shopEnabled = data.shopEnabled,
                slots = data.slots,
                weight = data.weight,
                openTime = data.openTime,
                fixedCode = data.fixedCode,
                jobLock = data.jobLock,
                allowCivilians = data.allowCivilians,
            })

            if forgeBackpack.IsItemModel(key) then
                itemModels[key] = normalizeItemModel({
                    label = data.label,
                    props = data.props,
                    propSettings = data.propSettings,
                    clothing = data.clothing,
                    anim = data.anim,
                }, Config.DefaultItemModels[key])
            end
        end
    end

    return {
        itemModels = itemModels,
        profiles = profiles,
    }
end

local function isAdmin(src)
    if src == 0 then return true end
    return IsPlayerAceAllowed(src, Config.AdminAce)
        or (Config.ParentAdminAce and IsPlayerAceAllowed(src, Config.ParentAdminAce))
        or IsPlayerAceAllowed(src, ("command.%s"):format(Config.AdminCommand))
end

function forgeBackpackIsAdmin(src)
    return isAdmin(src)
end

function forgeBackpackGetProfile(profileId)
    return BackpackProfiles[profileId]
end

function forgeBackpackGetResolved(profileId)
    return forgeBackpack.Resolve(profileId, BackpackProfiles, ItemModels)
end

function forgeBackpackGetResolvedFromItem(item)
    return forgeBackpack.ResolveFromItem(item, BackpackProfiles, ItemModels)
end

local function getCarryLimit()
    if Config.LimitBackpacks ~= true then return nil end

    local limit = math.floor(tonumber(Config.MaxBackpack) or 0)
    if limit < 1 then return nil end
    return limit
end

local function countInventoryBackpacks(inventory)
    local items = pr_lib.inventory.GetInventoryItems(inventory) or {}
    local count = 0

    for _, item in pairs(items) do
        if type(item) == "table" and forgeBackpack.IsItemModel(item.name, ItemModels) then
            count = count + math.max(0, math.floor(tonumber(item.count) or 1))
        end
    end

    return count
end

function forgeBackpackCanCarry(inventory, itemName, count, removingItem)
    local limit = getCarryLimit()
    if not limit or not forgeBackpack.IsItemModel(itemName, ItemModels) then
        return true, nil, limit
    end

    local current = countInventoryBackpacks(inventory)
    if type(removingItem) == "table" and forgeBackpack.IsItemModel(removingItem.name, ItemModels) then
        current = math.max(0, current - math.max(0, math.floor(tonumber(removingItem.count) or 1)))
    end

    local incoming = math.max(1, math.floor(tonumber(count) or 1))
    return current + incoming <= limit, current, limit
end

local function notifyCarryLimit(source, limit)
    source = tonumber(source)
    if not source or source <= 0 then return end

    pr_lib.notifications.Notify(source, {
        description = lang("notify.backpack_limit", { max = limit or Config.MaxBackpack }),
        type = "error"
    })
end

exports("CanCarryBackpack", function(inventory, itemName, count, removingItem)
    return forgeBackpackCanCarry(inventory, itemName, count, removingItem)
end)

local function registerCarryLimitHooks()
    if Config.LimitBackpacks ~= true or not pr_lib.inventory.RegisterHook then return end

    pr_lib.inventory.RegisterHook("swapItems", function(payload)
        if payload.toType ~= "player" or payload.fromInventory == payload.toInventory then return end

        local incoming = payload.fromSlot
        if type(incoming) ~= "table" or not forgeBackpack.IsItemModel(incoming.name, ItemModels) then return end

        local removing = payload.action == "swap" and type(payload.toSlot) == "table" and payload.toSlot or nil
        local allowed, _, limit = forgeBackpackCanCarry(payload.toInventory, incoming.name, payload.count, removing)
        if allowed then return end

        notifyCarryLimit(payload.source, limit)
        return false
    end)

    pr_lib.inventory.RegisterHook("buyItem", function(payload)
        if not forgeBackpack.IsItemModel(payload.itemName, ItemModels) then return end

        local allowed, _, limit = forgeBackpackCanCarry(payload.toInventory or payload.source, payload.itemName, payload.count)
        if allowed then return end

        notifyCarryLimit(payload.source, limit)
        return false
    end)
end
local function saveData()
    SaveResourceFile(resourceName, DATA_FILE, json.encode({
        itemModels = ItemModels,
        profiles = BackpackProfiles,
    }, { indent = true }), -1)
end

local function syncData(target)
    local data = {
        profiles = BackpackProfiles,
        itemModels = ItemModels,
    }
    if target and target > 0 then
        pr_lib.callback.trigger(target, 'forge-backpack:client:syncData', nil, data)
    else
        local players = GetPlayers()
        for i = 1, #players do
            local playerSrc = tonumber(players[i])
            if playerSrc then
                pr_lib.callback.trigger(playerSrc, 'forge-backpack:client:syncData', nil, data)
            end
        end
    end
end

local function sendInventorySnippet(src, modelName)
    if not src or src <= 0 then return end
    local modelData = ItemModels[modelName]
    if not modelData then return end

    pr_lib.callback.trigger(src, "forge-backpack:client:printInventorySnippet", nil, modelName, modelData)
end

local function registerUsableItem(itemName)
    local function onUse(source, itemData)
        pr_lib.callback.trigger(source, "forge-backpack:client:use", nil, {
            slot = itemData and itemData.slot
        })
    end

    if pr_lib.inventory.RegisterUsableItem then
        pr_lib.inventory.RegisterUsableItem(itemName, onUse)
    elseif pr_lib.framework.RegisterUsableItem then
        pr_lib.framework.RegisterUsableItem(itemName, onUse)
    end
end

local function registerAllUsableItems()
    local registered = {}

    for modelName in pairs(ItemModels) do
        if not registered[modelName] then
            registerUsableItem(modelName)
            registered[modelName] = true
        end
    end

    for i = 1, #Config.BackpackItems do
        local modelName = Config.BackpackItems[i]
        if not registered[modelName] then
            registerUsableItem(modelName)
            registered[modelName] = true
        end
    end
end

function forgeBackpackLoad()
    BackpackProfiles = {}
    ItemModels = deepCopy(Config.DefaultItemModels)

    local content = LoadResourceFile(resourceName, DATA_FILE)
    local decoded = content and content ~= "" and json.decode(content) or nil

    if type(decoded) == "table" then
        decoded = migrateLegacyData(decoded)

        for modelName, modelData in pairs(decoded.itemModels or {}) do
            ItemModels[modelName] = normalizeItemModel(
                modelData,
                defaultItemModelFallback(modelName)
            )
        end

        for profileId, profileData in pairs(decoded.profiles or {}) do
            BackpackProfiles[profileId] = normalizeProfile(profileData)
        end

        return
    end

    BackpackProfiles.small_civilian = normalizeProfile({
        label = "Small Backpack",
        itemModel = "backpack",
        price = 500,
        shopEnabled = true,
    })
    saveData()
end

function forgeBackpackSaveProfile(profileId, data, previousId)
    if type(profileId) ~= "string" or profileId == "" then
        return false, "invalid_name"
    end

    if previousId and previousId ~= profileId then
        BackpackProfiles[previousId] = nil
    end

    BackpackProfiles[profileId] = normalizeProfile(data)
    saveData()
    syncData()
    return true
end

function forgeBackpackDeleteProfile(profileId)
    if not BackpackProfiles[profileId] then
        return false, "not_found"
    end

    BackpackProfiles[profileId] = nil
    saveData()
    syncData()
    return true
end

function forgeBackpackSaveItemModel(modelName, data)
    if not isValidModelName(modelName) then
        return false, "invalid_name"
    end

    ItemModels[modelName] = normalizeItemModel(data, defaultItemModelFallback(modelName))
    registerUsableItem(modelName)
    saveData()
    syncData()
    return true
end

function forgeBackpackCreateItemModel(modelName, data)
    if not isValidModelName(modelName) then
        return false, "invalid_name"
    end

    if ItemModels[modelName] then
        return false, "duplicate_item_name"
    end

    local modelData = normalizeItemModel(data or {}, defaultItemModelFallback(modelName))
    ItemModels[modelName] = modelData
    registerUsableItem(modelName)
    saveData()
    syncData()
    return true, modelData
end

function forgeBackpackDeleteItemModel(modelName)
    if not ItemModels[modelName] then
        return false, "not_found"
    end

    for _, profile in pairs(BackpackProfiles) do
        if profile.itemModel == modelName then
            return false, "model_in_use"
        end
    end

    ItemModels[modelName] = nil
    saveData()
    syncData()
    return true
end

function forgeBackpackReload()
    forgeBackpackLoad()
    registerAllUsableItems()
    syncData()
    return {
        profiles = BackpackProfiles,
        itemModels = ItemModels,
    }
end

CreateThread(function()
    forgeBackpackLoad()
    registerAllUsableItems()
    registerCarryLimitHooks()
    syncData()
end)

pr_lib.callback.register('forge-backpack:server:requestSync', function(src)
    return {
        profiles = BackpackProfiles,
        itemModels = ItemModels,
    }
end)

pr_lib.callback.register('forge-backpack:server:isAdmin', function(src)
    return isAdmin(src)
end)

pr_lib.callback.register('forge-backpack:server:getData', function(src)
    if not isAdmin(src) then return false end
    return {
        profiles = BackpackProfiles,
        itemModels = ItemModels,
    }
end)

pr_lib.callback.register('forge-backpack:server:saveProfile', function(src, profileId, data, previousId)
    if not isAdmin(src) then return false, "no_permission" end
    return forgeBackpackSaveProfile(profileId, data, previousId)
end)

pr_lib.callback.register('forge-backpack:server:deleteProfile', function(src, profileId)
    if not isAdmin(src) then return false, "no_permission" end
    return forgeBackpackDeleteProfile(profileId)
end)

pr_lib.callback.register('forge-backpack:server:saveItemModel', function(src, modelName, data)
    if not isAdmin(src) then return false, "no_permission" end
    local ok, err = forgeBackpackSaveItemModel(modelName, data)
    if ok then
        sendInventorySnippet(src, modelName)
    end
    return ok, err
end)

pr_lib.callback.register('forge-backpack:server:reloadBackpacks', function(src)
    if not isAdmin(src) then return false, "no_permission" end
    return forgeBackpackReload()
end)

pr_lib.callback.register('forge-backpack:server:createProfileTemplate', function(src, itemModel)
    if not isAdmin(src) then return false end
    if itemModel and ItemModels[itemModel] then
        return profileDefaultsForModel(itemModel)
    end
    return defaultProfileTemplate()
end)

pr_lib.callback.register('forge-backpack:server:createItemModel', function(src, modelName, data)
    if not isAdmin(src) then return false, "no_permission" end
    local ok, errOrData = forgeBackpackCreateItemModel(modelName, data)
    if ok then
        sendInventorySnippet(src, modelName)
    end
    return ok, errOrData
end)

pr_lib.callback.register('forge-backpack:server:deleteItemModel', function(src, modelName)
    if not isAdmin(src) then return false, "no_permission" end
    return forgeBackpackDeleteItemModel(modelName)
end)

pr_lib.callback.register('forge-backpack:server:createItemModelTemplate', function(src)
    if not isAdmin(src) then return false end
    return normalizeItemModel({}, defaultItemModelFallback("backpack"))
end)

-- Compatibilidade com callbacks antigos do menu
pr_lib.callback.register('forge-backpack:server:getBackpacks', function(src)
    if not isAdmin(src) then return false end
    return BackpackProfiles
end)

pr_lib.callback.register('forge-backpack:server:saveBackpack', function(src, profileId, data, previousId)
    if not isAdmin(src) then return false, "no_permission" end
    return forgeBackpackSaveProfile(profileId, data, previousId)
end)

pr_lib.callback.register('forge-backpack:server:deleteBackpack', function(src, profileId)
    if not isAdmin(src) then return false, "no_permission" end
    return forgeBackpackDeleteProfile(profileId)
end)

pr_lib.callback.register('forge-backpack:server:createTemplate', function(src)
    if not isAdmin(src) then return false end
    return defaultProfileTemplate()
end)
