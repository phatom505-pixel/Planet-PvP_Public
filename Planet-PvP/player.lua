local player_system = {}

local function hide_dot(player)
    if player and player.valid then player.show_on_map = false end
end

local function maintain_light(player)
    if not (player and player.valid) then return end
    storage.player_lights = storage.player_lights or {}
    local light = storage.player_lights[player.index]
    if not player.character or not player.character.valid then
        if light and light.valid then light.destroy() end
        storage.player_lights[player.index] = nil
        return
    end
    if not light or not light.valid then
        storage.player_lights[player.index] = rendering.draw_light{sprite = "utility/light_medium", target = player.character, surface = player.character.surface, players = {player}, scale = 1.2, intensity = .8, minimum_darkness = .2}
    end
end

function player_system.on_init()
    storage.player_lights = storage.player_lights or {}
end

function player_system.on_player_created(event)
    local player = game.get_player(event.player_index)
    hide_dot(player); maintain_light(player)
end

function player_system.on_player_joined_game(event) hide_dot(game.get_player(event.player_index)) end
function player_system.on_player_respawned(event) hide_dot(game.get_player(event.player_index)); maintain_light(game.get_player(event.player_index)) end

function player_system.on_player_changed_surface(event)
    local player = game.get_player(event.player_index)
    if player and storage.player_lights[player.index] then
        local light = storage.player_lights[player.index]
        if light and light.valid then light.destroy() end
        storage.player_lights[player.index] = nil
    end
    maintain_light(player)
end

function player_system.on_light_tick()
    for _, player in pairs(game.connected_players) do
        maintain_light(player)
        if player.character and player.character.valid then player.character.disable_flashlight() end
    end
end

return player_system
