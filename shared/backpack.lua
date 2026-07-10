forgeBackpack = forgeBackpack or {}

local function deepCopy(value)
    return json.decode(json.encode(value))
end

function forgeBackpack.IsItemModel(itemName, itemModels)
    if type(itemName) ~= "string" or itemName == "" then
        return false
    end

    itemModels = itemModels or ItemModels or {}
    if type(itemModels) == "table" and itemModels[itemName] then
        return true
    end

    for i = 1, #Config.BackpackItems do
        if Config.BackpackItems[i] == itemName then
            return true
        end
    end

    return false
end

function forgeBackpack.GetMetadata(item)
    if type(item) ~= "table" then return {} end
    return item.metadata or item.info or {}
end

function forgeBackpack.GetProfileId(item, profiles)
    if type(item) ~= "table" then return nil end

    local metadata = forgeBackpack.GetMetadata(item)
    local profileKey = Config.MetadataKeys.profile
    local profileId = metadata[profileKey]

    if profileId and profiles and profiles[profileId] then
        return profileId
    end

    if forgeBackpack.IsItemModel(item.name) and Config.DefaultProfileByModel[item.name] then
        local fallback = Config.DefaultProfileByModel[item.name]
        if not profiles or profiles[fallback] then
            return fallback
        end
    end

    return nil
end

function forgeBackpack.Resolve(profileId, profiles, itemModels)
    profiles = profiles or BackpackProfiles or {}
    itemModels = itemModels or ItemModels or {}

    local profile = profiles[profileId]
    if not profile then return nil end

    local model = itemModels[profile.itemModel]
    if not model then return nil end

    return {
        profileId = profileId,
        itemModel = profile.itemModel,
        label = profile.label,
        price = profile.price,
        shopEnabled = profile.shopEnabled,
        slots = profile.slots,
        weight = profile.weight,
        openTime = profile.openTime,
        fixedCode = profile.fixedCode,
        jobLock = profile.jobLock,
        allowCivilians = profile.allowCivilians,
        props = model.props,
        propSettings = model.propSettings,
        clothing = model.clothing,
        anim = model.anim,
    }
end

local cipherKey = { 47, 12, 99, 54, 88, 231, 14, 75 }

function forgeBackpack.EncryptCode(plainText)
    if type(plainText) ~= "string" then return nil end
    local result = {}
    for i = 1, #plainText do
        local byteVal = string.byte(plainText, i)
        local keyVal = cipherKey[((i - 1) % #cipherKey) + 1]
        local cipherVal = (byteVal + keyVal) % 256
        table.insert(result, string.format("%02x", cipherVal))
    end
    return table.concat(result)
end

function forgeBackpack.DecryptCode(cipherText)
    if type(cipherText) ~= "string" then return nil end
    local result = {}
    for i = 1, #cipherText, 2 do
        local hex = cipherText:sub(i, i + 1)
        local byteVal = tonumber(hex, 16)
        if not byteVal then return nil end
        local idx = math.floor(i / 2) + 1
        local keyVal = cipherKey[((idx - 1) % #cipherKey) + 1]
        local plainVal = (byteVal - keyVal) % 256
        table.insert(result, string.char(plainVal))
    end
    return table.concat(result)
end

function forgeBackpack.ResolveFromItem(item, profiles, itemModels)
    local profileId = forgeBackpack.GetProfileId(item, profiles)
    if not profileId then return nil end
    local resolved = forgeBackpack.Resolve(profileId, profiles, itemModels)
    if not resolved then return nil end

    local metadata = forgeBackpack.GetMetadata(item)
    if metadata.backpack_code then
        resolved.fixedCode = forgeBackpack.DecryptCode(metadata.backpack_code)
    end

    return resolved
end

function forgeBackpack.BuildItemMetadata(profileId, profile, existingMetadata)
    local metadata = deepCopy(existingMetadata or {})
    metadata[Config.MetadataKeys.profile] = profileId
    if profile and profile.label then
        metadata.label = profile.label
        metadata.description = profile.label
    end
    return metadata
end

function forgeBackpack.GetItemModelsList(itemModels)
    itemModels = itemModels or ItemModels or {}
    local list = {}
    local seen = {}

    for modelName in pairs(itemModels) do
        if not seen[modelName] then
            list[#list + 1] = modelName
            seen[modelName] = true
        end
    end

    for i = 1, #Config.BackpackItems do
        local modelName = Config.BackpackItems[i]
        if not seen[modelName] then
            list[#list + 1] = modelName
            seen[modelName] = true
        end
    end

    table.sort(list)
    return list
end
