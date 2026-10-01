local drop_zone = require("drop_zone")
local base = {}

local COLORS = {
    {r = .90, g = .45, b = .10, a = 1}, {r = .95, g = .20, b = .20, a = 1},
    {r = .70, g = .20, b = .90, a = 1}, {r = .20, g = .85, b = .20, a = 1},
    {r = .20, g = .60, b = .95, a = 1},
}

local function notify(force_name, message)
    local force = game.forces[force_name]
    if force then for _, player in pairs(force.players) do if player.valid then player.print(message) end end end
end

local function count(force_name)
    local total = 0
    for _ in pairs(storage.force_bases[force_name] or {}) do total = total + 1 end
    return total
end

local function color_for(force_name)
    return storage.force_colors[force_name] or {r = 1, g = 1, b = 1, a = 1}
end

function base.assign_force_color(force_name)
    if storage.force_colors[force_name] then return end
    local used = 0
    for _ in pairs(storage.force_colors) do used = used + 1 end
    storage.force_colors[force_name] = COLORS[(used % #COLORS) + 1]
end

function base.register(entity)
    if not (entity and entity.valid) then return end
    local force_name = entity.force.name
    storage.force_bases[force_name] = storage.force_bases[force_name] or {}
    storage.force_bases[force_name][entity.unit_number] = true
    local color = color_for(force_name)
    entity.color = color
    storage.base_label_ids[entity.unit_number] = rendering.draw_text{
        text = force_name, surface = entity.surface, target = entity, target_offset = {0, -3.5},
        color = color, scale = 2, font = "default-bold", alignment = "center", visible = true,
    }
    notify(force_name, "[color=green][BASE] A base has been established at (" .. math.floor(entity.position.x)
        .. ", " .. math.floor(entity.position.y) .. ") on " .. entity.surface.name .. ".[/color]")
end

function base.spawn_initial(force_name, planet_name)
    local planet = game.planets[planet_name]
    if not planet then return end
    local surface = planet.create_surface()
    local position = surface.find_non_colliding_position("market", {8, 0}, 200, 1) or {x = 8, y = 0}
    local entity = surface.create_entity{name = "pvp-base", position = position, force = game.forces[force_name], raise_built = true}
    if entity and entity.valid then base.register(entity) end
end

local function destroyed(entity)
    local force_name = entity.force.name
    if storage.force_bases[force_name] then storage.force_bases[force_name][entity.unit_number] = nil end
    local label = storage.base_label_ids[entity.unit_number]
    if label and label.valid then label.destroy() end
    storage.base_label_ids[entity.unit_number] = nil
    local remaining = count(force_name)
    if remaining > 0 then
        notify(force_name, "[color=orange][BASE] A base was destroyed! You have " .. remaining .. " base(s) remaining. Respawn is still active.[/color]")
    else
        notify(force_name, "[color=red][BASE] ALL BASES DESTROYED! Any player who dies now is PERMANENTLY ELIMINATED. Rebuild a base core to restore respawning.[/color]")
    end
end

local function spectator(player)
    player.set_controller{type = defines.controllers.spectator}
    player.print("[color=red]You have been permanently eliminated.[/color]")
end

function base.on_built_entity(event)
    if event.entity and event.entity.valid and event.entity.name == "pvp-base" then base.register(event.entity) end
end

function base.on_entity_died(event)
    if event.entity and event.entity.valid and event.entity.name == "pvp-base" then destroyed(event.entity) end
end

function base.on_player_died(event)
    local player = game.players[event.player_index]
    if not (player and player.valid) then return end
    if not (storage.player_team_joined and storage.player_team_joined[player.index]) then return end
    local force_name = player.force.name
    if storage.permadead[force_name] and storage.permadead[force_name][player.index] then return end
    if count(force_name) > 0 then
        player.print("[color=yellow]You died. Respawning... (Base is alive)[/color]")
    else
        storage.permadead[force_name] = storage.permadead[force_name] or {}
        storage.permadead[force_name][player.index] = true
        storage.pending_spectator[player.index] = force_name
        player.print("[color=red]You died while your team had no base. You are PERMANENTLY ELIMINATED.[/color]")
    end
end

function base.on_player_respawned(event)
    local player = game.players[event.player_index]
    if not (player and player.valid) then return end
    if not (storage.player_team_joined and storage.player_team_joined[player.index]) then return end
    local force_name = player.force.name
    if storage.permadead[force_name] and storage.permadead[force_name][player.index] then spectator(player); return end
    if count(force_name) == 0 then
        storage.permadead[force_name] = storage.permadead[force_name] or {}
        storage.permadead[force_name][player.index] = true
        spectator(player)
        return
    end
    for planet_name, assigned_force in pairs(storage.planet_teams or {}) do
        if assigned_force == force_name then
            local planet = game.planets[planet_name]
            if planet and planet.surface then drop_zone.teleport_to_planet(player, planet.surface) end
            return
        end
    end
end

function base.on_pre_player_mined_item(event)
    local entity, player = event.entity, game.players[event.player_index]
    if entity and entity.valid and entity.name == "pvp-base" and player and player.valid then
        player.mining_state = {mining = false}
        player.print("[color=red]The base cannot be moved once placed. Destroy it to retrieve the core.[/color]")
    end
end

function base.on_robot_pre_mined(event)
    local entity = event.entity
    if entity and entity.valid and entity.name == "pvp-base" then entity.cancel_deconstruction("all") end
end

function base.on_tick(event)
    if not storage.crash_site_cleanup_done then
        local nauvis = game.planets["nauvis"] and game.planets["nauvis"].surface
        if nauvis then
            local crash_names = {
                "crash-site-spaceship", "crash-site-spaceship-wreck-big-1", "crash-site-spaceship-wreck-big-2",
                "crash-site-spaceship-wreck-medium-1", "crash-site-spaceship-wreck-medium-2", "crash-site-spaceship-wreck-medium-3",
                "crash-site-spaceship-wreck-small-1", "crash-site-spaceship-wreck-small-2", "crash-site-spaceship-wreck-small-3",
                "crash-site-spaceship-wreck-small-4", "crash-site-spaceship-wreck-small-5", "crash-site-spaceship-wreck-small-6",
                "crash-site-chest-1", "crash-site-chest-2",
            }
            for _, name in pairs(crash_names) do
                for _, entity in pairs(nauvis.find_entities_filtered{name = name}) do if entity.valid then entity.destroy() end end
            end
            for _, type in pairs({"fire", "smoke", "explosion", "particle"}) do
                for _, entity in pairs(nauvis.find_entities_filtered{type = type, area = {{-200, -200}, {200, 200}}}) do if entity.valid then entity.destroy() end end
            end
            if event.tick >= 300 then storage.crash_site_cleanup_done = true end
        end
    end
    if event.tick % 10 ~= 0 or not next(storage.pending_spectator) then return end
    for index in pairs(storage.pending_spectator) do
        local player = game.players[index]
        if player and player.valid and not player.character then spectator(player); storage.pending_spectator[index] = nil end
    end
end

function base.status_command(event)
    local player = game.players[event.player_index]
    if player then for force_name in pairs(storage.force_bases) do player.print(force_name .. ": " .. count(force_name) .. " base(s)") end end
end

return base
