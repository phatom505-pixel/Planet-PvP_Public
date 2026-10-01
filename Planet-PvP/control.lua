local observer = require("observer")
local radar = require("radar")
local drop_zone = require("drop_zone")
local base = require("base")
local setup = require("setup")
local player_system = require("player")

-- One registration per Factorio event lets the separate systems share events safely.
script.on_init(function() setup.on_init(observer); player_system.on_init() end)
script.on_configuration_changed(setup.on_configuration_changed)

script.on_event(defines.events.on_player_created, function(event)
    player_system.on_player_created(event)
    setup.on_player_created(event)
end)
script.on_event(defines.events.on_player_joined_game, function(event)
    player_system.on_player_joined_game(event)
    setup.on_player_joined_game(event)
end)
script.on_event(defines.events.on_player_respawned, function(event)
    player_system.on_player_respawned(event)
    base.on_player_respawned(event)
    setup.on_player_respawned(event)
end)
script.on_event(defines.events.on_player_changed_surface, function(event)
    player_system.on_player_changed_surface(event)
    drop_zone.on_player_changed_surface(event)
end)
script.on_event(defines.events.on_chunk_generated, setup.on_chunk_generated)
script.on_event(defines.events.on_built_entity, function(event)
    radar.on_built_entity(event)
    base.on_built_entity(event)
end)
script.on_event(defines.events.on_entity_died, base.on_entity_died)
script.on_event(defines.events.on_player_died, base.on_player_died)
script.on_event(defines.events.on_pre_player_mined_item, base.on_pre_player_mined_item)
script.on_event(defines.events.on_robot_pre_mined, base.on_robot_pre_mined)
script.on_nth_tick(1800, radar.on_orbital_scan_tick)
script.on_event(defines.events.on_cargo_pod_finished_ascending, drop_zone.on_cargo_pod_finished_ascending)
script.on_event(defines.events.on_entity_damaged, drop_zone.on_entity_damaged)
script.on_event(defines.events.on_lua_shortcut, drop_zone.on_lua_shortcut)
script.on_event(defines.events.on_player_selected_area, drop_zone.on_player_selected_area)
script.on_event(defines.events.on_gui_click, function(event)
    if not observer.on_gui_click(event) then setup.on_gui_click(event) end
end)
script.on_event("planet-pvp-toggle-observer", function(event)
    local player = game.get_player(event.player_index)
    if player then observer.toggle_window(player) end
end)
script.on_nth_tick(5, observer.on_tick)
script.on_nth_tick(120, player_system.on_light_tick)
script.on_event(defines.events.on_tick, base.on_tick)

commands.add_command("basestatus", "Show base count for every force", base.status_command)
commands.add_command("ping", nil, function(command)
    local player = game.players[command.player_index]
    if not (player and player.valid and player.character) then return end
    for _, mode in pairs({"game", "chart"}) do
        rendering.draw_circle{color = {r = 1, g = 1, b = 0, a = 1}, radius = 3, width = 10, filled = false, target = player.position, surface = player.surface, players = player.force.players, time_to_live = 300, render_mode = mode}
        rendering.draw_text{text = "PING", surface = player.surface, target = {position = player.position, offset = {0, -2.5}}, color = {r = 1, g = 1, b = 0, a = 1}, players = player.force.players, alignment = "center", scale = 3, time_to_live = 300, render_mode = mode}
    end
    for _, target in pairs(player.force.players) do if target.valid then target.print(player.name .. " pinged their location") end end
end)
commands.add_command("observer", "Become an observer", function(command)
    local player = game.get_player(command.player_index)
    if not player then return end
    if not player.admin then player.print("Only admins can become observers."); return end
    observer.enable(player)
end)
