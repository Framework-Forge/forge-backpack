local lang = pr_lib.locale()


pr_lib.callback.register("forge-backpack:server:buyBackpack", function(src, profileId)
    if not pr_lib.framework.GetPlayer(src) then return false end

    local profile = forgeBackpackGetProfile(profileId)
    if not profile then return false end

    local canCarry, _, limit = forgeBackpackCanCarry(src, profile.itemModel, 1)
    if not canCarry then
        pr_lib.notifications.Notify(src, {
            description = lang("notify.backpack_limit", { max = limit or Config.MaxBackpack }),
            type = "error"
        })
        return false
    end

    local price = profile.price or 0

    if not pr_lib.framework.takeMoney(src, price, "forge-backpack") then
        pr_lib.notifications.Notify(src, {
            description = lang("notify.not_enough_money"),
            type = "error"
        })
        return false
    end

    local metadata = forgeBackpack.BuildItemMetadata(profileId, profile)
    if profile.fixedCode then
        metadata.backpack_code = forgeBackpack.EncryptCode(profile.fixedCode)
    end

    pr_lib.inventory.AddItem(src, profile.itemModel, 1, metadata)

    pr_lib.notifications.Notify(src, {
        description = lang("notify.purchased"),
        type = "success"
    })
    return true
end)

pr_lib.callback.register('forge-backpack:server:requestOpen', function(src, slot)
    if not pr_lib.framework.GetPlayer(src) then return false end

    local job = pr_lib.framework.getPlayerJob(src, "name")
    local item = pr_lib.inventory.GetSlot(src, slot)
    if not item then return false end

    local bagConfig = forgeBackpackGetResolvedFromItem(item)
    if not bagConfig then
        pr_lib.notifications.Notify(src, {
            description = lang("notify.invalid_profile"),
            type = "error"
        })
        return false
    end

    if not bagConfig.allowCivilians and not bagConfig.jobLock then
        pr_lib.notifications.Notify(src, {
            description = lang("notify.cannot_open"),
            type = "error"
        })
        return false
    end

    if bagConfig.jobLock then
        local allowed = false
        for _, j in pairs(bagConfig.jobLock) do
            if j == job then
                allowed = true
                break
            end
        end
        if not allowed then
            pr_lib.notifications.Notify(src, {
                description = lang("notify.job_cannot_open"),
                type = "error"
            })
            return false
        end
    end

    return true, bagConfig
end)

pr_lib.callback.register('forge-backpack:server:validateCode', function(src, slot, code)
    local item = pr_lib.inventory.GetSlot(src, slot)
    if not item then return false end

    local bagConfig = forgeBackpackGetResolvedFromItem(item)

    if bagConfig and bagConfig.fixedCode and code ~= bagConfig.fixedCode then
        return false
    end

    return true
end)

pr_lib.callback.register('forge-backpack:server:changePassword', function(src, slot, newPassword)
    if not pr_lib.framework.GetPlayer(src) then return false end

    local item = pr_lib.inventory.GetSlot(src, slot)
    if not item then return false end

    local bagConfig = forgeBackpackGetResolvedFromItem(item)
    if not bagConfig or not bagConfig.fixedCode then return false end

    local encrypted = forgeBackpack.EncryptCode(newPassword)
    local metadata = forgeBackpack.GetMetadata(item)
    metadata.backpack_code = encrypted

    if pr_lib.activeBridges.inventory == "ox" then
        pr_lib.inventory.SetMetadata(src, slot, metadata)
    else
        local Player = pr_lib.framework.GetPlayer(src)
        local playerItem = Player.PlayerData.items[slot]
        if playerItem then
            playerItem.info = metadata
            Player.Functions.SetInventory(Player.PlayerData.items)
        end
    end

    pr_lib.notifications.Notify(src, {
        description = lang("backpack.password_changed"),
        type = "success"
    })
    return true
end)

pr_lib.callback.register('forge-backpack:server:finishOpen', function(src, slot)
    local item = pr_lib.inventory.GetSlot(src, slot)
    if not item then return false end

    local bagConfig = forgeBackpackGetResolvedFromItem(item)
    if not bagConfig then return false end

    local metadata = forgeBackpack.GetMetadata(item)
    local stashKey = Config.MetadataKeys.stash

    if not metadata[stashKey] then
        metadata[stashKey] = 'backpack_' .. math.random(100000, 999999)
    end

    metadata = forgeBackpack.BuildItemMetadata(bagConfig.profileId, bagConfig, metadata)
    local stashId = metadata[stashKey]

    if pr_lib.activeBridges.inventory == "ox" then
        pr_lib.inventory.SetMetadata(src, slot, metadata)
    else
        local Player = pr_lib.framework.GetPlayer(src)
        local playerItem = Player.PlayerData.items[slot]
        if playerItem then
            playerItem.info = metadata
            Player.Functions.SetInventory(Player.PlayerData.items)
        end
    end

    local displayLabel = lang("stash.label", {
        label = bagConfig.label,
        id = stashId:gsub("backpack_", "")
    })

    pr_lib.inventory.RegisterStash(stashId, displayLabel, bagConfig.slots, bagConfig.weight)
    pr_lib.inventory.forceOpenInventory(src, 'stash', stashId)
    return true
end)

pr_lib.addCommand(Config.TestCommand, {
    help = lang("command.testemochila_help"),
    params = {
        {
            name = "item_model",
            type = "string",
            help = lang("command.testemochila_item"),
            optional = true,
        },
        {
            name = "profile",
            type = "string",
            help = lang("command.testemochila_profile"),
            optional = true,
        },
    },
}, function(source, params)
    if source == 0 then
        print(lang("command.player_only"))
        return
    end

    if not forgeBackpackIsAdmin(source) then
        pr_lib.notifications.Notify(source, {
            description = lang("notify.no_admin_permission"),
            type = "error"
        })
        return
    end

    local itemModel = params[1] and params[1].value
    local profileId = params[2] and params[2].value

    if not itemModel or not ItemModels[itemModel] then
        pr_lib.notifications.Notify(source, {
            description = lang("notify.invalid_item_name"),
            type = "error"
        })
        return
    end

    if not profileId then
        profileId = Config.DefaultProfileByModel[itemModel]
    end

    local profile = profileId and forgeBackpackGetProfile(profileId)
    if not profile then
        pr_lib.notifications.Notify(source, {
            description = lang("notify.invalid_profile"),
            type = "error"
        })
        return
    end

    if profile.itemModel ~= itemModel then
        pr_lib.notifications.Notify(source, {
            description = lang("notify.profile_model_mismatch"),
            type = "error"
        })
        return
    end

    local canCarry, _, limit = forgeBackpackCanCarry(source, itemModel, 1)
    if not canCarry then
        pr_lib.notifications.Notify(source, {
            description = lang("notify.backpack_limit", { max = limit or Config.MaxBackpack }),
            type = "error"
        })
        return
    end

    local metadata = forgeBackpack.BuildItemMetadata(profileId, profile)
    if profile.fixedCode then
        metadata.backpack_code = forgeBackpack.EncryptCode(profile.fixedCode)
    end

    pr_lib.inventory.AddItem(source, itemModel, 1, metadata)

    pr_lib.notifications.Notify(source, {
        description = lang("notify.test_backpack_given", {
            item = itemModel,
            profile = profileId
        }),
        type = "success"
    })
end)

exports('BuildBackpackMetadata', function(profileId)
    local profile = forgeBackpackGetProfile(profileId)
    if not profile then return nil end

    local metadata = forgeBackpack.BuildItemMetadata(profileId, profile)
    if profile.fixedCode then
        metadata.backpack_code = forgeBackpack.EncryptCode(profile.fixedCode)
    end
    return metadata
end)
