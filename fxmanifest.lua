fx_version "adamant"
game "gta5"
lua54 'yes'
shared_scripts {
    "@ox_lib/init.lua",  -- Ensure ox_lib is initialized
    "config.lua"
}

client_scripts {
    "client/framework.lua",
    "client/main.lua",
    "client/metro.lua",
    "client/eventTrain.lua"
}

server_scripts {
    "server/main.lua",
    "server/eventTrain.lua"
}
