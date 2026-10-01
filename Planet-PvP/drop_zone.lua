local drop_zone = {}

function drop_zone.teleport_to_planet(player, surface)
    local planet_name = surface.name
    storage.player_targets = storage.player_targets or {}
    local target = storage.player_targets[player.force.name .. "_" .. planet_name]
    local position = target and target.position
        or surface.find_non_colliding_position("character", {0, 0}, 500, 2) or {x = 0, y = 0}
    local attempts = 0
    script.on_nth_tick(1, function()
        if player and player.valid and attempts < 30 then
            player.teleport(position, surface)
            if player.character then player.set_controller{type = defines.controllers.character, character = player.character} end
            attempts = attempts + 1
        else
            script.on_nth_tick(1, nil)
        end
    end)
end

function drop_zone.on_player_changed_surface(event)
    local player = game.players[event.player_index]
    if not (player and player.valid) then return end
    local surface = player.surface
    if event.surface_index == surface.index or surface.platform or player.render_mode == defines.render_mode.chart then return end
    storage.player_surfaces = storage.player_surfaces or {}
    if storage.player_surfaces[player.index] == surface.index then return end
    storage.player_surfaces[player.index] = surface.index
    if player.controller_type == defines.controllers.character or player.controller_type == defines.controllers.cutscene then
        drop_zone.teleport_to_planet(player, surface)
    end
end

function drop_zone.on_cargo_pod_finished_ascending(event)
    local pod = event.cargo_pod
    if not (pod and pod.valid) or not pod.cargo_pod_destination then return end
    local surface = pod.cargo_pod_destination.surface
    if not surface or surface.platform then return end
    local target = storage.player_targets and storage.player_targets[pod.force.name .. "_" .. surface.name]
    if target then pod.cargo_pod_destination = {type = defines.cargo_destination.surface, surface = surface, position = target.position} end
end

function drop_zone.on_entity_damaged(event)
    local entity, cause = event.entity, event.cause
    if entity and entity.valid and entity.type == "character" and cause and cause.valid and cause.name == "cargo-pod" and cause.force == entity.force then
        entity.health = entity.health + event.final_damage_amount
    end
end

function drop_zone.on_lua_shortcut(event)
    if event.prototype_name == "lock_drop_zone_shortcut" then
        local player = game.players[event.player_index]
        if player and player.cursor_stack then player.cursor_stack.set_stack{name = "drop-zone-selector", count = 1} end
    end
end

function drop_zone.on_player_selected_area(event)
    if event.item ~= "drop-zone-selector" then return end
    local player, surface = game.players[event.player_index], event.surface
    storage.player_targets = storage.player_targets or {}
    local pos = {x = (event.area.left_top.x + event.area.right_bottom.x) / 2, y = (event.area.left_top.y + event.area.right_bottom.y) / 2}
    if not player.force.is_chunk_charted(surface, {math.floor(pos.x / 32), math.floor(pos.y / 32)}) then
        player.print("Cannot lock drop zone: area is not scanned!")
    else
        for _, jammer in pairs(surface.find_entities_filtered{
            area = {{pos.x - 120, pos.y - 120}, {pos.x + 120, pos.y + 120}},
            type = "radar"
        }) do
            if jammer.force ~= player.force and jammer.force.name ~= "neutral" then
                player.print("Cannot lock drop zone: area is jammed by an enemy!")
                if player.cursor_stack then player.cursor_stack.clear() end
                return
            end
        end
        storage.player_targets[player.force.name .. "_" .. surface.name] = {position = pos}
        player.print("Drop Zone LOCKED for " .. surface.name .. " at [" .. math.floor(pos.x) .. ", " .. math.floor(pos.y) .. "]")
    end
    if player.cursor_stack then player.cursor_stack.clear() end
end

return drop_zone
