Config = {}

Config.VersionCheck = true
Config.Debug = false

Config.BackpackStyle = "clothing"

-- Quando ativo, limita a quantidade total de mochilas no inventario do player.
-- Use 0 em MaxBackpack para desativar o limite numerico.
Config.LimitBackpacks = true
Config.MaxBackpack = 1

Config.BlacklistItems = {
    "backpack",
    "large_backpack",
    "evidence_backpack",
}

Config.BackpackShop = {
    ped = "a_m_m_business_01",
    coords = vector4(399.54, 98.46, 101.57, 347.4),
    blip = {
        enabled = true,
        sprite = 587,
        color = 5,
        scale = 0.8,
    }
}

Config.AdminCommand = "backpackadmin"
Config.AdminAce = "forge-backpack.admin"
Config.ParentAdminAce = "forge-core.admin"
Config.TestCommand = "testemochila"

-- Itens padrao na primeira instalacao (modelos extras sao criados no admin / JSON)
Config.BackpackItems = {
    "backpack",
    "large_backpack",
    "evidence_backpack",
}

-- Perfil padrao quando o item nao tem metadata.profile (ex: /giveitem sem metadata)
Config.DefaultProfileByModel = {
    backpack = "small_civilian",
    large_backpack = "large_secured",
    evidence_backpack = "evidence_police",
}

-- Metadata usada nos itens
Config.MetadataKeys = {
    profile = "profile",
    stash = "stash",
}

-- Visuais padrao dos 3 modelos (podem ser sobrescritos pelo JSON em runtime)
Config.DefaultItemModels = {
    backpack = {
        label = "Small Backpack Model",
        props = {
            male = "p_michael_backpack_s",
            female = "p_michael_backpack_s"
        },
        propSettings = {
            male = { bone = 24818, x = 0.07, y = -0.15, z = -0.05, rx = 0.0, ry = 90.0, rz = 175.0 },
            female = { bone = 24818, x = 0.05, y = -0.14, z = -0.06, rx = 0.0, ry = 90.0, rz = 175.0 }
        },
        clothing = {
            male = { component = 5, drawable = 66, texture = 0 },
            female = { component = 5, drawable = 45, texture = 0 }
        },
        anim = {
            dict = "clothingtie",
            clip = "try_tie_positive_a",
            flag = 49
        }
    },
    large_backpack = {
        label = "Large Backpack Model",
        props = {
            male = "p_ld_heist_bag_s_pro2_s",
            female = "p_ld_heist_bag_s_pro2_s"
        },
        propSettings = {
            male = { bone = 24818, x = -0.17, y = -0.18, z = -0.02, rx = 0.0, ry = 90.0, rz = 180.0 },
            female = { bone = 24818, x = -0.17, y = -0.18, z = -0.02, rx = 0.0, ry = 90.0, rz = 180.0 }
        },
        clothing = {
            male = { component = 5, drawable = 82, texture = 0 },
            female = { component = 5, drawable = 82, texture = 0 }
        },
        anim = {
            dict = "clothingtie",
            clip = "try_tie_positive_a",
            flag = 49
        }
    },
    evidence_backpack = {
        label = "Evidence Backpack Model",
        props = {
            male = "p_michael_backpack_s",
            female = "p_michael_backpack_s"
        },
        propSettings = {
            male = { bone = 24818, x = 0.07, y = -0.15, z = -0.05, rx = 0.0, ry = 90.0, rz = 175.0 },
            female = { bone = 24818, x = 0.05, y = -0.14, z = -0.06, rx = 0.0, ry = 90.0, rz = 175.0 }
        },
        clothing = {
            male = { component = 5, drawable = 41, texture = 0 },
            female = { component = 5, drawable = 41, texture = 0 }
        },
        anim = {
            dict = "clothingtie",
            clip = "try_tie_positive_a",
            flag = 49
        }
    }
}
