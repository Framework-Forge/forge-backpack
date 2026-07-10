fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'forge Devs - Pierre Moraes'
description 'Backpack system for FiveM'
version '1.0.3'

dependency 'ox_lib'
dependency 'pr_bridge'

shared_scripts {
    '@ox_lib/init.lua',
    '@pr_bridge/init.lua',
    'shared/*.lua'
}

server_scripts {
    'server/version.lua',
    'server/backpacks.lua',
    'server/server.lua'
}

client_scripts {
    'client/client.lua',
    'client/menu.lua'
}

files {
    'data/backpacks.json',
    'locale/*.lua'
}

escrow_ignore {
    'shared/*.lua',
    'data/*.json',
    'locale/*.lua'
}
