forgeBackpack = forgeBackpack or {}

function forgeBackpack.GetItemImageFile(modelName, modelData)
    if type(modelData) == "table" and modelData.image then
        local image = modelData.image
        if image:find("://") then
            return modelName .. ".png"
        end
        if not image:match("%.") then
            return image .. ".png"
        end
        return image
    end

    return modelName .. ".png"
end

local function escapeLuaString(value)
    return tostring(value):gsub("\\", "\\\\"):gsub("'", "\\'")
end

function forgeBackpack.BuildOxInventorySnippet(modelName, modelData)
    modelData = type(modelData) == "table" and modelData or {}
    local label = escapeLuaString(modelData.label or modelName)

    return ([[['%s'] = {
    label = '%s',
    weight = 1000,
    stack = false,
    close = true,
    description = 'Mochila com stash privado (forge-backpack)',
    consume = 0,
},]]):format(modelName, label)
end

function forgeBackpack.BuildQbInventorySnippet(modelName, modelData)
    modelData = type(modelData) == "table" and modelData or {}
    local label = escapeLuaString(modelData.label or modelName)
    local image = escapeLuaString(forgeBackpack.GetItemImageFile(modelName, modelData))

    return ([[['%s'] = {
    name = '%s',
    label = '%s',
    weight = 1000,
    type = 'item',
    image = '%s',
    unique = true,
    useable = true,
    shouldClose = true,
    description = 'Mochila com stash privado (forge-backpack)'
},]]):format(modelName, modelName, label, image)
end
