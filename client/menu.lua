local lang = pr_lib.locale()

BackpackProfiles = BackpackProfiles or {}
ItemModels = ItemModels or {}
Backpacks = BackpackProfiles

local MENU_MAIN = "forge-backpack:admin:main"
local MENU_LIST = "forge-backpack:admin:list"
local MENU_EDIT = "forge-backpack:admin:edit"
local MENU_MODELS = "forge-backpack:admin:models"
local MENU_MODEL_EDIT = "forge-backpack:admin:model_edit"
local MENU_MODEL_PICK = "forge-backpack:admin:model_pick"

local editingProfileId = nil
local editingProfile = nil
local editingModelName = nil
local editingModel = nil
local openEditProfileMenu
local openEditModelMenu
local saveCurrentProfile

local function notify(description, notifyType)
    pr_lib.notifications.Notify({
        description = description,
        type = notifyType or "info"
    })
end

local function showContext(id, title, menu, options)
    pr_lib.menus.RegisterContext({
        id = id,
        title = title,
        menu = menu,
        options = options
    })
    pr_lib.menus.ShowContext(id)
end

local function parseNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
end

local function formatYesNo(value)
    return value and lang("general.yes") or lang("general.no")
end

local function formatJobLock(jobLock)
    if not jobLock or jobLock == false then return "" end
    if type(jobLock) == "table" then
        return table.concat(jobLock, ", ")
    end
    return tostring(jobLock)
end

local function translateError(err)
    if not err then return lang("error.unknown") end
    return lang("error." .. err)
end

local function getSortedModelNames()
    return forgeBackpack.GetItemModelsList(ItemModels)
end

local function getItemModelImage(modelName, modelData)
    modelData = modelData or ItemModels[modelName] or {}

    if modelData.image then
        local image = modelData.image
        if image:find("://") then
            return image
        end

        if pr_lib.inventory.getInventoryImg then
            local file = image
            if not (file:match("%.png$") or file:match("%.webp$") or file:match("%.jpg$") or file:match("%.jpeg$")) then
                file = file .. ".png"
            end
            return pr_lib.inventory.getInventoryImg(file)
        end

        if pr_lib.inventory.GetImagePath then
            return pr_lib.inventory.GetImagePath(image)
        end

        return image
    end

    if pr_lib.inventory.getInventoryImg then
        return pr_lib.inventory.getInventoryImg(modelName .. ".png")
    end

    if pr_lib.inventory.GetImagePath then
        return pr_lib.inventory.GetImagePath(modelName)
    end

    return nil
end

local function buildModelPickerOption(modelName, modelData, onSelect)
    local option = {
        title = modelData.label or modelName,
        description = lang("admin.model_pick_desc", { model = modelName }),
        onSelect = function()
            onSelect(modelName, modelData)
        end
    }

    local image = getItemModelImage(modelName, modelData)
    if image then
        option.image = image
    else
        option.icon = "box"
    end

    return option
end

local function openItemModelPicker(title, parentMenu, onSelect)
    local options = {}
    local sorted = getSortedModelNames()

    for i = 1, #sorted do
        local modelName = sorted[i]
        options[#options + 1] = buildModelPickerOption(
            modelName,
            ItemModels[modelName] or {},
            onSelect
        )
    end

    if #options == 0 then
        options[1] = {
            title = lang("admin.empty_models"),
            icon = "circle-info",
            disabled = true
        }
    end

    showContext(MENU_MODEL_PICK, title, parentMenu, options)
end

local function openCreateProfileDialog(modelName, template)
    local input = pr_lib.menus.InputDialog(lang("admin.new_backpack_title"), {
        { type = "input", label = lang("input.profile_id"), required = true },
        { type = "input", label = lang("input.label"), default = template.label, required = true },
        { type = "number", label = lang("input.price"), default = template.price },
        { type = "number", label = lang("input.slots"), default = template.slots },
        { type = "number", label = lang("input.weight"), default = template.weight / 1000 },
        { type = "number", label = lang("input.open_time"), default = template.openTime },
        { type = "checkbox", label = lang("input.shop_enabled"), checked = template.shopEnabled == true },
        { type = "checkbox", label = lang("input.allow_civilians"), checked = template.allowCivilians ~= false }
    })

    if not input then
        openProfileListMenu()
        return
    end

    local profileId = input[1]:gsub("%s+", "")
    if profileId == "" or BackpackProfiles[profileId] then
        notify(lang("notify.duplicate_profile_id"), "error")
        openProfileListMenu()
        return
    end

    template.label = input[2]
    template.itemModel = modelName
    template.price = parseNumber(input[3], template.price)
    template.slots = parseNumber(input[4], template.slots)
    template.weight = parseNumber(input[5], template.weight / 1000) * 1000
    template.openTime = parseNumber(input[6], template.openTime)
    template.shopEnabled = input[7] == true
    template.allowCivilians = input[8] == true

    editingProfileId = profileId
    editingProfile = template

    if saveCurrentProfile() then
        openEditProfileMenu()
    else
        openProfileListMenu()
    end
end

local function startCreateProfile()
    openItemModelPicker(lang("admin.pick_model_title"), MENU_LIST, function(modelName)
        local template = pr_lib.callback.await(
            "forge-backpack:server:createProfileTemplate",
            5000,
            modelName
        )

        if not template then
            notify(lang("notify.no_permission_create"), "error")
            openProfileListMenu()
            return
        end

        openCreateProfileDialog(modelName, template)
    end)
end

saveCurrentProfile = function(previousId)
    local isNew = BackpackProfiles[editingProfileId] == nil
    if previousId and previousId ~= editingProfileId then
        isNew = false
    end

    if isNew then
        notify(lang("notify.creating"), "info")
    else
        notify(lang("notify.saving"), "info")
    end

    local ok, err = pr_lib.callback.await(
        "forge-backpack:server:saveProfile",
        5000,
        editingProfileId,
        editingProfile,
        previousId
    )

    if not ok then
        notify(lang("notify.save_failed", { error = translateError(err) }), "error")
        return false
    end

    BackpackProfiles[editingProfileId] = editingProfile
    if previousId and previousId ~= editingProfileId then
        BackpackProfiles[previousId] = nil
    end

    if isNew then
        notify(lang("notify.profile_created"), "success")
    else
        notify(lang("notify.save_success"), "success")
    end
    return true
end

local function saveCurrentItemModel()
    notify(lang("notify.saving"), "info")

    local ok, err = pr_lib.callback.await(
        "forge-backpack:server:saveItemModel",
        5000,
        editingModelName,
        editingModel
    )

    if not ok then
        notify(lang("notify.save_failed", { error = translateError(err) }), "error")
        return false
    end

    ItemModels[editingModelName] = editingModel
    notify(lang("notify.save_success"), "success")
    return true
end

local function editProfileGeneral()
    local input = pr_lib.menus.InputDialog(lang("input.general_title"), {
        { type = "input", label = lang("input.profile_id"), default = editingProfileId, required = true },
        { type = "input", label = lang("input.label"), default = editingProfile.label, required = true },
        { type = "number", label = lang("input.price"), default = editingProfile.price },
        { type = "number", label = lang("input.slots"), default = editingProfile.slots },
        { type = "number", label = lang("input.weight"), default = editingProfile.weight / 1000 },
        { type = "number", label = lang("input.open_time"), default = editingProfile.openTime },
        { type = "checkbox", label = lang("input.shop_enabled"), checked = editingProfile.shopEnabled == true },
        { type = "checkbox", label = lang("input.allow_civilians"), checked = editingProfile.allowCivilians ~= false }
    })

    if not input then
        openEditProfileMenu()
        return
    end

    local previousId = editingProfileId
    local newId = input[1]:gsub("%s+", "")
    if newId == "" then
        notify(lang("notify.invalid_profile_id"), "error")
        openEditProfileMenu()
        return
    end

    editingProfileId = newId
    editingProfile.label = input[2]
    editingProfile.price = parseNumber(input[3], editingProfile.price)
    editingProfile.slots = parseNumber(input[4], editingProfile.slots)
    editingProfile.weight = parseNumber(input[5], editingProfile.weight / 1000) * 1000
    editingProfile.openTime = parseNumber(input[6], editingProfile.openTime)
    editingProfile.shopEnabled = input[7] == true
    editingProfile.allowCivilians = input[8] == true

    if saveCurrentProfile(previousId) then
        openEditProfileMenu()
    end
end

local function changeProfileItemModel()
    openItemModelPicker(lang("admin.pick_model_title"), MENU_EDIT, function(modelName)
        editingProfile.itemModel = modelName
        if saveCurrentProfile() then
            openEditProfileMenu()
        end
    end)
end

local function editProfileSecurity()
    local input = pr_lib.menus.InputDialog(lang("input.security_title"), {
        {
            type = "input",
            label = lang("input.fixed_code"),
            default = editingProfile.fixedCode and tostring(editingProfile.fixedCode) or ""
        },
        {
            type = "input",
            label = lang("input.allowed_jobs"),
            default = formatJobLock(editingProfile.jobLock)
        }
    })

    if not input then
        openEditProfileMenu()
        return
    end

    editingProfile.fixedCode = input[1] ~= "" and input[1] or false

    local jobsInput = input[2]
    if jobsInput == "" then
        editingProfile.jobLock = false
    else
        local jobs = {}
        for job in jobsInput:gmatch("[^,%s]+") do
            jobs[#jobs + 1] = job
        end
        editingProfile.jobLock = #jobs > 0 and jobs or false
    end

    if saveCurrentProfile() then
        openEditProfileMenu()
    end
end

local function deleteCurrentProfile()
    local confirm = pr_lib.menus.AlertDialog({
        header = lang("admin.delete_confirm_header"),
        content = lang("admin.delete_confirm_content", { item = editingProfileId }),
        centered = true,
        cancel = true
    })

    if confirm ~= "confirm" then
        openEditProfileMenu()
        return
    end

    notify(lang("notify.deleting"), "info")

    local ok, err = pr_lib.callback.await("forge-backpack:server:deleteProfile", 5000, editingProfileId)
    if not ok then
        notify(lang("notify.delete_failed", { error = translateError(err) }), "error")
        openEditProfileMenu()
        return
    end

    BackpackProfiles[editingProfileId] = nil
    editingProfileId = nil
    editingProfile = nil
    notify(lang("notify.delete_success"), "success")
    openProfileListMenu()
end

openEditProfileMenu = function()
    if not editingProfileId or not editingProfile then
        openProfileListMenu()
        return
    end

    local resolved = forgeBackpack.Resolve(editingProfileId, BackpackProfiles, ItemModels)

    local modelData = ItemModels[editingProfile.itemModel] or {}
    local modelImage = getItemModelImage(editingProfile.itemModel, modelData)

    local modelOption = {
        title = lang("admin.change_model_title"),
        description = lang("admin.model_label", { model = editingProfile.itemModel }),
        onSelect = changeProfileItemModel
    }

    if modelImage then
        modelOption.image = modelImage
    else
        modelOption.icon = "cube"
    end

    showContext(MENU_EDIT, lang("admin.edit_title", { label = editingProfile.label }), MENU_LIST, {
        {
            title = editingProfileId,
            description = lang("admin.list_summary", {
                price = editingProfile.price or 0,
                slots = editingProfile.slots or 0,
                shop = formatYesNo(editingProfile.shopEnabled)
            }) .. " | " .. lang("admin.model_label", { model = editingProfile.itemModel }),
            icon = "bag-shopping",
            disabled = true
        },
        modelOption,
        {
            title = lang("admin.general_title"),
            description = lang("admin.general_desc"),
            icon = "pen",
            onSelect = editProfileGeneral
        },
        {
            title = lang("admin.security_title"),
            description = lang("admin.security_desc"),
            icon = "lock",
            onSelect = editProfileSecurity
        },
        {
            title = lang("admin.preview_title"),
            description = lang("admin.preview_desc"),
            icon = "eye",
            onSelect = function()
                forgeBackpackClient.Preview(resolved)
                notify(lang("notify.preview_applied"), "success")
                openEditProfileMenu()
            end
        },
        {
            title = lang("admin.reset_preview_title"),
            description = lang("admin.reset_preview_desc"),
            icon = "rotate-left",
            onSelect = function()
                forgeBackpackClient.ResetPreview()
                notify(lang("notify.preview_removed"), "info")
                openEditProfileMenu()
            end
        },
        {
            title = lang("admin.delete_title"),
            description = lang("admin.delete_desc"),
            icon = "trash",
            iconColor = "red",
            onSelect = deleteCurrentProfile
        }
    })
end

function openProfileListMenu()
    local options = {}

    for profileId, profileData in pairs(BackpackProfiles) do
        local modelName = profileData.itemModel or "?"
        local modelData = ItemModels[modelName] or {}
        local option = {
            title = profileData.label or profileId,
            description = lang("admin.list_item", {
                item = profileId,
                price = profileData.price or 0,
                shop = formatYesNo(profileData.shopEnabled)
            }) .. " | " .. lang("admin.model_label", { model = modelName }),
            onSelect = function()
                editingProfileId = profileId
                editingProfile = json.decode(json.encode(profileData))
                openEditProfileMenu()
            end
        }

        local image = getItemModelImage(modelName, modelData)
        if image then
            option.image = image
        else
            option.icon = "bag-shopping"
        end

        options[#options + 1] = option
    end

    if #options == 0 then
        options[1] = {
            title = lang("admin.empty_list"),
            icon = "circle-info",
            disabled = true
        }
    end

    options[#options + 1] = {
        title = lang("admin.create_title"),
        description = lang("admin.create_desc"),
        icon = "plus",
        onSelect = startCreateProfile
    }

    showContext(MENU_LIST, lang("admin.list_title"), MENU_MAIN, options)
end

local function editModelGeneral()
    local input = pr_lib.menus.InputDialog(lang("input.model_general_title"), {
        { type = "input", label = lang("input.label"), default = editingModel.label or editingModelName, required = true },
        {
            type = "input",
            label = lang("input.model_image"),
            description = lang("input.model_image_desc"),
            default = editingModel.image or ""
        }
    })

    if not input then
        openEditModelMenu()
        return
    end

    editingModel.label = input[1]
    editingModel.image = input[2] ~= "" and input[2] or nil

    if saveCurrentItemModel() then
        openEditModelMenu()
    end
end

local function deleteCurrentItemModel()
    local confirm = pr_lib.menus.AlertDialog({
        header = lang("admin.delete_model_confirm_header"),
        content = lang("admin.delete_model_confirm_content", { model = editingModelName }),
        centered = true,
        cancel = true
    })

    if confirm ~= "confirm" then
        openEditModelMenu()
        return
    end

    notify(lang("notify.deleting"), "info")

    local ok, err = pr_lib.callback.await(
        "forge-backpack:server:deleteItemModel",
        5000,
        editingModelName
    )

    if not ok then
        notify(lang("notify.delete_failed", { error = translateError(err) }), "error")
        openEditModelMenu()
        return
    end

    ItemModels[editingModelName] = nil
    editingModelName = nil
    editingModel = nil
    notify(lang("notify.delete_success"), "success")
    openItemModelsMenu()
end

local function createNewItemModel()
    local template = pr_lib.callback.await("forge-backpack:server:createItemModelTemplate", 5000)
    if not template then
        notify(lang("notify.no_permission_create"), "error")
        return
    end

    local input = pr_lib.menus.InputDialog(lang("admin.new_model_title"), {
        { type = "input", label = lang("input.new_item_name"), required = true },
        { type = "input", label = lang("input.label"), default = template.label or lang("admin.default_label"), required = true },
        {
            type = "input",
            label = lang("input.model_image"),
            description = lang("input.model_image_desc"),
            default = ""
        }
    })

    if not input then
        openItemModelsMenu()
        return
    end

    local modelName = input[1]:gsub("%s+", "")
    if modelName == "" or ItemModels[modelName] then
        notify(lang("notify.duplicate_item_name"), "error")
        openItemModelsMenu()
        return
    end

    notify(lang("notify.creating"), "info")

    local ok, errOrData = pr_lib.callback.await(
        "forge-backpack:server:createItemModel",
        5000,
        modelName,
        {
            label = input[2],
            image = input[3] ~= "" and input[3] or nil,
            props = template.props,
            propSettings = template.propSettings,
            clothing = template.clothing,
            anim = template.anim,
        }
    )

    if not ok then
        notify(lang("notify.save_failed", { error = translateError(errOrData) }), "error")
        openItemModelsMenu()
        return
    end

    ItemModels[modelName] = errOrData
    notify(lang("notify.model_created", { model = modelName }), "success")
    editingModelName = modelName
    editingModel = json.decode(json.encode(ItemModels[modelName]))
    openEditModelMenu()
end

local function editModelProps()
    local input = pr_lib.menus.InputDialog(lang("input.props_title"), {
        { type = "input", label = lang("input.prop_male"), default = editingModel.props.male, required = true },
        { type = "input", label = lang("input.prop_female"), default = editingModel.props.female, required = true }
    })

    if not input then
        openEditModelMenu()
        return
    end

    editingModel.props.male = input[1]
    editingModel.props.female = input[2]

    if saveCurrentItemModel() then
        openEditModelMenu()
    end
end

local function editModelPropSettings(gender)
    local settings = editingModel.propSettings[gender]
    local genderLabel = gender == "male" and lang("general.male") or lang("general.female")
    local input = pr_lib.menus.InputDialog(lang("admin.prop_settings_title", { gender = genderLabel }), {
        { type = "number", label = lang("input.bone"), default = settings.bone },
        { type = "number", label = lang("input.axis_x"), default = settings.x },
        { type = "number", label = lang("input.axis_y"), default = settings.y },
        { type = "number", label = lang("input.axis_z"), default = settings.z },
        { type = "number", label = lang("input.axis_rx"), default = settings.rx },
        { type = "number", label = lang("input.axis_ry"), default = settings.ry },
        { type = "number", label = lang("input.axis_rz"), default = settings.rz }
    })

    if not input then
        openEditModelMenu()
        return
    end

    editingModel.propSettings[gender] = {
        bone = parseNumber(input[1], settings.bone),
        x = parseNumber(input[2], settings.x),
        y = parseNumber(input[3], settings.y),
        z = parseNumber(input[4], settings.z),
        rx = parseNumber(input[5], settings.rx),
        ry = parseNumber(input[6], settings.ry),
        rz = parseNumber(input[7], settings.rz)
    }

    if saveCurrentItemModel() then
        openEditModelMenu()
    end
end

local function editModelClothing(gender)
    local clothing = editingModel.clothing[gender]
    local genderLabel = gender == "male" and lang("general.male") or lang("general.female")
    local input = pr_lib.menus.InputDialog(lang("admin.clothing_title", { gender = genderLabel }), {
        { type = "number", label = lang("input.component"), default = clothing.component },
        { type = "number", label = lang("input.drawable"), default = clothing.drawable },
        { type = "number", label = lang("input.texture"), default = clothing.texture }
    })

    if not input then
        openEditModelMenu()
        return
    end

    editingModel.clothing[gender] = {
        component = parseNumber(input[1], clothing.component),
        drawable = parseNumber(input[2], clothing.drawable),
        texture = parseNumber(input[3], clothing.texture)
    }

    if saveCurrentItemModel() then
        openEditModelMenu()
    end
end

local function editModelAnimation()
    local input = pr_lib.menus.InputDialog(lang("input.animation_title"), {
        { type = "input", label = lang("input.anim_dict"), default = editingModel.anim.dict, required = true },
        { type = "input", label = lang("input.anim_clip"), default = editingModel.anim.clip, required = true },
        { type = "number", label = lang("input.anim_flag"), default = editingModel.anim.flag }
    })

    if not input then
        openEditModelMenu()
        return
    end

    editingModel.anim.dict = input[1]
    editingModel.anim.clip = input[2]
    editingModel.anim.flag = parseNumber(input[3], editingModel.anim.flag)

    if saveCurrentItemModel() then
        openEditModelMenu()
    end
end

openEditModelMenu = function()
    if not editingModelName or not editingModel then
        openItemModelsMenu()
        return
    end

    local modelImage = getItemModelImage(editingModelName, editingModel)

    local headerOption = {
        title = editingModelName,
        description = editingModel.label or editingModelName,
        disabled = true
    }

    if modelImage then
        headerOption.image = modelImage
    else
        headerOption.icon = "cube"
    end

    showContext(MENU_MODEL_EDIT, lang("admin.model_edit_title", { model = editingModelName }), MENU_MODELS, {
        headerOption,
        {
            title = lang("admin.model_general_title"),
            description = lang("admin.model_general_desc"),
            icon = "pen",
            onSelect = editModelGeneral
        },
        {
            title = lang("admin.props_title"),
            description = lang("admin.props_desc"),
            icon = "cube",
            onSelect = editModelProps
        },
        {
            title = lang("admin.prop_settings_title", { gender = lang("general.male") }),
            icon = "male",
            onSelect = function() editModelPropSettings("male") end
        },
        {
            title = lang("admin.prop_settings_title", { gender = lang("general.female") }),
            icon = "female",
            onSelect = function() editModelPropSettings("female") end
        },
        {
            title = lang("admin.clothing_title", { gender = lang("general.male") }),
            icon = "shirt",
            onSelect = function() editModelClothing("male") end
        },
        {
            title = lang("admin.clothing_title", { gender = lang("general.female") }),
            icon = "shirt",
            onSelect = function() editModelClothing("female") end
        },
        {
            title = lang("admin.animation_title"),
            description = lang("admin.animation_desc"),
            icon = "person-walking",
            onSelect = editModelAnimation
        },
        {
            title = lang("admin.preview_title"),
            icon = "eye",
            onSelect = function()
                forgeBackpackClient.Preview({
                    props = editingModel.props,
                    propSettings = editingModel.propSettings,
                    clothing = editingModel.clothing,
                    anim = editingModel.anim,
                })
                notify(lang("notify.preview_applied"), "success")
                openEditModelMenu()
            end
        },
        {
            title = lang("admin.delete_model_title"),
            description = lang("admin.delete_model_desc"),
            icon = "trash",
            iconColor = "red",
            onSelect = deleteCurrentItemModel
        }
    })
end

function openItemModelsMenu()
    local options = {}
    local sorted = getSortedModelNames()

    for i = 1, #sorted do
        local modelName = sorted[i]
        local modelData = ItemModels[modelName] or {}
        options[#options + 1] = buildModelPickerOption(modelName, modelData, function()
            editingModelName = modelName
            editingModel = json.decode(json.encode(modelData))
            openEditModelMenu()
        end)
    end

    if #options == 0 then
        options[1] = {
            title = lang("admin.empty_models"),
            icon = "circle-info",
            disabled = true
        }
    end

    options[#options + 1] = {
        title = lang("admin.create_model_title"),
        description = lang("admin.create_model_desc"),
        icon = "plus",
        onSelect = createNewItemModel
    }

    showContext(MENU_MODELS, lang("admin.models_title"), MENU_MAIN, options)
end

function openBackpackAdminMenu()
    local isAdmin = pr_lib.callback.await("forge-backpack:server:isAdmin", 5000)
    if not isAdmin then
        notify(lang("notify.no_admin_permission"), "error")
        return
    end

    local data = pr_lib.callback.await("forge-backpack:server:getData", 5000)
    if type(data) == "table" then
        BackpackProfiles = data.profiles or {}
        ItemModels = data.itemModels or ItemModels
        Backpacks = BackpackProfiles
    end

    showContext(MENU_MAIN, lang("admin.main_title"), nil, {
        {
            title = lang("admin.manage_title"),
            description = lang("admin.manage_desc"),
            icon = "list",
            onSelect = openProfileListMenu
        },
        {
            title = lang("admin.models_title"),
            description = lang("admin.models_desc"),
            icon = "cube",
            onSelect = openItemModelsMenu
        },
        {
            title = lang("admin.reload_title"),
            description = lang("admin.reload_desc"),
            icon = "rotate",
            onSelect = function()
                notify(lang("notify.reloading"), "info")
                local synced = pr_lib.callback.await("forge-backpack:server:reloadBackpacks", 5000)
                if type(synced) ~= "table" then
                    notify(lang("notify.reload_failed"), "error")
                    return
                end

                BackpackProfiles = synced.profiles or {}
                ItemModels = synced.itemModels or ItemModels
                Backpacks = BackpackProfiles
                notify(lang("notify.reload_success"), "success")
                openBackpackAdminMenu()
            end
        }
    })
end

pr_lib.addCommand(Config.AdminCommand, {
    help = lang("command.backpackadmin_help")
}, function()
    openBackpackAdminMenu()
end)

pr_lib.callback.register("forge-backpack:client:openAdminMenu", function(src)
    openBackpackAdminMenu()
end)
