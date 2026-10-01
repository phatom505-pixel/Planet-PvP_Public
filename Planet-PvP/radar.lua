local radar = {}

local GRID_SIZE = 16
local MAX_RADIUS = 3200

local function scan_orbit(entity, planet_name)
    local surface = game.planets[planet_name] and game.planets[planet_name].surface
    if not surface then return end

    storage.grid_pos = storage.grid_pos or {}
    local scan_key = entity.force.name .. "_" .. planet_name
    if not storage.grid_pos[scan_key] then
        storage.grid_pos[scan_key] = {x = 0, y = 0, d = 0, step_limit = 1, steps_taken = 0, iteration = 0}
    end

    local state = storage.grid_pos[scan_key]
    local position = {x = state.x, y = state.y}
    local blocked = false
    for _, jammer in pairs(surface.find_entities_filtered{
        area = {{position.x - 120, position.y - 120}, {position.x + 120, position.y + 120}},
        type = "radar"
    }) do
        if jammer.force ~= entity.force and jammer.force.name ~= "neutral" then
            blocked = true
            break
        end
    end

    local scan_range = 1
    if not blocked then
        surface.request_to_generate_chunks(position, scan_range)
        entity.force.chart(surface, {
            {position.x - (GRID_SIZE * scan_range), position.y - (GRID_SIZE * scan_range)},
            {position.x + (GRID_SIZE * scan_range), position.y + (GRID_SIZE * scan_range)}
        })
    end

    if state.d == 0 then state.x = state.x + GRID_SIZE * scan_range * 2
    elseif state.d == 1 then state.y = state.y + GRID_SIZE * scan_range * 2
    elseif state.d == 2 then state.x = state.x - GRID_SIZE * scan_range * 2
    else state.y = state.y - GRID_SIZE * scan_range * 2 end

    state.steps_taken = state.steps_taken + 1
    if state.steps_taken >= state.step_limit then
        state.steps_taken = 0
        state.d = (state.d + 1) % 4
        state.iteration = state.iteration + 1
        if state.iteration % 2 == 0 then state.step_limit = state.step_limit + 1 end
    end
    if math.abs(state.x) > MAX_RADIUS or math.abs(state.y) > MAX_RADIUS then
        storage.grid_pos[scan_key] = {x = 0, y = 0, d = 0, step_limit = 1, steps_taken = 0, iteration = 0}
    end
end

function radar.on_orbital_scan_tick()
    for _, surface in pairs(game.surfaces) do
        local platform = surface.platform
        local location = platform and platform.space_location
        if location and game.planets[location.name] then
            for _, entity in pairs(surface.find_entities_filtered{type = "radar"}) do
                if entity.valid and entity.active then
                    scan_orbit(entity, location.name)
                end
            end
        end
    end
end

function radar.on_built_entity(event)
    local entity = event.entity
    if not (entity and entity.valid) or entity.type ~= "radar" or entity.surface.platform then return end

    local jammer_force, jammer_pos, jammer_radius = entity.force, entity.position, 120
    for _, enemy_force in pairs(game.forces) do
        if enemy_force.name ~= jammer_force.name and enemy_force.name ~= "neutral" then
            local min_x = math.floor((jammer_pos.x - jammer_radius) / 32)
            local min_y = math.floor((jammer_pos.y - jammer_radius) / 32)
            local max_x = math.ceil((jammer_pos.x + jammer_radius) / 32)
            local max_y = math.ceil((jammer_pos.y + jammer_radius) / 32)
            for x = min_x, max_x do
                for y = min_y, max_y do enemy_force.unchart_chunk({x = x, y = y}, entity.surface) end
            end

            storage.player_targets = storage.player_targets or {}
            local key = enemy_force.name .. "_" .. entity.surface.name
            local target = storage.player_targets[key]
            if target then
                local dx, dy = math.abs(target.position.x - jammer_pos.x), math.abs(target.position.y - jammer_pos.y)
                -- Jam the same reach on each axis, rather than a circular radius.
                if dx <= jammer_radius and dy <= jammer_radius then
                    storage.player_targets[key] = nil
                    local message = "[color=red][JAMMER] Your drop zone at [" .. math.floor(target.position.x)
                        .. ", " .. math.floor(target.position.y) .. "] on " .. entity.surface.name
                        .. " has been JAMMED by " .. jammer_force.name .. "![/color]"
                    for _, player in pairs(enemy_force.players) do if player.valid then player.print(message) end end
                end
            end
        end
    end
end

return radar
