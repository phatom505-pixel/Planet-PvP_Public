local base = require("base")
local drop_zone = require("drop_zone")
local setup = {}

local PLANETS = {"nauvis", "vulcanus", "fulgora", "gleba"}
local HUB_SURFACE_NAME = "planet-pvp-hub"
local HUB_MIN = -50
local HUB_MAX = 49
local HUB_VOID_MIN = -80
local HUB_VOID_MAX = 79
local HUB_LAYOUT_VERSION = 2
local LOADOUTS = {
    nauvis = {{name = "burner-mining-drill", count = 1}, {name = "stone-furnace", count = 1}, {name = "iron-plate", count = 8}},
    vulcanus = {{name = "burner-mining-drill", count = 1}, {name = "stone-furnace", count = 1}, {name = "iron-plate", count = 8}},
    fulgora = {{name = "burner-mining-drill", count = 1}, {name = "stone-furnace", count = 1}, {name = "iron-plate", count = 8}},
    gleba = {{name = "burner-mining-drill", count = 1}, {name = "stone-furnace", count = 1}, {name = "iron-plate", count = 8}},
}
local UNIVERSAL = { ["automation-science-pack"] = true, ["logistic-science-pack"] = true, ["military-science-pack"] = true, ["chemical-science-pack"] = true, ["production-science-pack"] = true, ["utility-science-pack"] = true, ["space-science-pack"] = true }
local TRIGGERS = {
    ["planet-discovery-vulcanus"] = "vulcanus", ["planet-discovery-fulgora"] = "fulgora", ["planet-discovery-gleba"] = "gleba", ["planet-discovery-aquilo"] = "aquilo",
    ["uranium-mining"] = "nauvis", ["bitter-egg-handling"] = "nauvis", ["recycling"] = "fulgora", ["holmium-processing"] = "fulgora", ["electromagnetic-plant"] = "fulgora", ["electromagnetic-science-pack"] = "fulgora",
    ["jellynut"] = "gleba", ["yumako"] = "gleba", ["heating-tower"] = "gleba", ["agriculture"] = "gleba", ["biochamber"] = "gleba", ["artificial-soil"] = "gleba", ["bioflux"] = "gleba", ["bacteria-cultivation"] = "gleba", ["bioflux-processing"] = "gleba", ["agricultural-science-pack"] = "gleba",
    ["tungsten-carbide"] = "vulcanus", ["calcite-processing"] = "vulcanus", ["foundry"] = "vulcanus", ["big-mining-drill"] = "vulcanus", ["tungsten-steel"] = "vulcanus", ["metallurgic-science-pack"] = "vulcanus",
    ["lithium-processing"] = "aquilo", ["cryogenic-plant"] = "aquilo", ["cryogenic-science-pack"] = "aquilo",
}
local BASIC = {["steam-power"] = true, ["electronics"] = true, ["automation-science-pack"] = true, ["steel-axe"] = true, ["oil-processing"] = true}

local function protect_hub_walls(surface)
    for _, wall in pairs(surface.find_entities_filtered{name = "stone-wall", area = {{HUB_MIN - 1, HUB_MIN - 1}, {HUB_MAX + 1, HUB_MAX + 1}}}) do
        wall.destructible = false
        wall.minable_flag = false
    end
end

local function build_hub_layout(surface)
    surface.request_to_generate_chunks({0, 0}, 2)
    surface.force_generate_chunk_requests()

    local tiles = {}
    for x = HUB_VOID_MIN, HUB_VOID_MAX do
        for y = HUB_VOID_MIN, HUB_VOID_MAX do
            tiles[#tiles + 1] = {name = "out-of-map", position = {x, y}}
        end
    end
    for x = HUB_MIN, HUB_MAX do
        for y = HUB_MIN, HUB_MAX do
            tiles[#tiles + 1] = {name = "refined-concrete", position = {x, y}}
        end
    end
    surface.set_tiles(tiles, true)

    -- Replace any older lobby border before placing the updated perimeter.
    for _, wall in pairs(surface.find_entities_filtered{name = "stone-wall", area = {{HUB_VOID_MIN, HUB_VOID_MIN}, {HUB_VOID_MAX + 1, HUB_VOID_MAX + 1}}}) do
        wall.destroy()
    end
    local function create_wall(position)
        local wall = surface.create_entity{name = "stone-wall", position = position, force = game.forces.player}
        if wall then wall.destructible = false; wall.minable_flag = false end
    end
    for x = HUB_MIN, HUB_MAX do
        create_wall({x, HUB_MIN})
        create_wall({x, HUB_MAX})
    end
    for y = HUB_MIN + 1, HUB_MAX - 1 do
        create_wall({HUB_MIN, y})
        create_wall({HUB_MAX, y})
    end
    storage.hub_layout_version = HUB_LAYOUT_VERSION
end

local function get_hub_surface()
    local surface = game.surfaces[HUB_SURFACE_NAME]
    if not surface then
        surface = game.create_surface(HUB_SURFACE_NAME, {
            seed = 7082026,
            peaceful_mode = true,
            autoplace_controls = {},
            autoplace_settings = {
                entity = {treat_missing_as_default = false, settings = {}},
                tile = {treat_missing_as_default = false, settings = {}},
            },
        })
    end
    if storage.hub_layout_version ~= HUB_LAYOUT_VERSION then
        build_hub_layout(surface)
    else
        protect_hub_walls(surface)
    end
    return surface
end

local function teleport_to_hub(player)
    if not (player and player.valid) or player.controller_type == defines.controllers.spectator then return end
    local surface = get_hub_surface()
    if player.controller_type == defines.controllers.cutscene then player.exit_cutscene() end
    local position = surface.find_non_colliding_position("character", {0, 0}, 48, 1) or {0, 0}
    player.teleport(position, surface)
    storage.player_surfaces[player.index] = surface.index
end

local function has_selected_team(player)
    if storage.player_team_joined and storage.player_team_joined[player.index] then return true end
    for _, force_name in pairs(storage.planet_teams or {}) do
        if player.force and player.force.name == force_name then
            storage.player_team_joined = storage.player_team_joined or {}
            storage.player_team_joined[player.index] = true
            return true
        end
    end
    return false
end

local function assign_fulgora_attractors(surface, area)
    local force_name = storage.planet_teams and storage.planet_teams.fulgora
    local force = force_name and game.forces[force_name]
    if not (surface and surface.valid and force) then return end
    for _, attractor in pairs(surface.find_entities_filtered{
        name = "fulgoran-ruin-attractor",
        area = area,
    }) do
        attractor.force = force
    end
end

local function set_pvp_relations()
    for i, a_name in ipairs(PLANETS) do
        local a = game.forces[a_name]
        if a then for j, b_name in ipairs(PLANETS) do
            local b = game.forces[b_name]
            if i ~= j and b then a.set_friend(b, false); b.set_friend(a, false); a.set_cease_fire(b, false); b.set_cease_fire(a, false) end
        end end
    end
end

local function requirement(tech)
    local found
    for _, ingredient in pairs(tech.research_unit_ingredients) do
        if not UNIVERSAL[ingredient.name] then if found and found ~= ingredient.name then return "mixed" end; found = ingredient.name end
    end
    return found or "base"
end

local function unlock(force, planet_name)
    force.unlock_space_location(planet_name)
    for _, tech in pairs(force.technologies) do
        if tech.enabled then
            local assigned = TRIGGERS[tech.name]
            local unlock_tech = BASIC[tech.name] or (requirement(tech) == "base" and not tech.prototype.upgrade)
            if assigned then unlock_tech = assigned == planet_name and not tech.prototype.upgrade end
            if tech.name == "metallurgic-science-pack" or tech.name == "electromagnetic-science-pack" or tech.name == "agricultural-science-pack" or tech.name == "cryogenic-science-pack" then unlock_tech = false end
            if (tech.name:find("productivity%-module") or tech.name:find("speed%-module") or tech.name:find("efficiency%-module") or tech.name:find("quality%-module")) and tech.prototype.max_level < 3 then unlock_tech = true end
            tech.researched = unlock_tech
        end
    end
end

local function show_admin(player)
    if player.gui.screen.pvp_admin_frame then player.gui.screen.pvp_admin_frame.destroy() end
    local frame = player.gui.screen.add{type = "frame", name = "pvp_admin_frame", caption = "ADMIN: CONFIGURE PLANET TEAMS", direction = "vertical"}
    frame.auto_center = true
    local table_ui = frame.add{type = "table", column_count = 2, name = "setup_table"}
    for _, planet in pairs(PLANETS) do
        table_ui.add{type = "label", caption = planet:gsub("^%l", string.upper) .. " Force Name:"}
        table_ui.add{type = "textfield", name = "tf_" .. planet, text = "Team " .. planet:gsub("^%l", string.upper)}
    end
    frame.add{type = "button", name = "confirm_admin_setup", caption = "INITIALIZE WORLD", style = "confirm_button"}
end

local function show_join(player)
    if player.gui.screen.pvp_join_frame then player.gui.screen.pvp_join_frame.destroy() end
    if not storage.game_started or not storage.planet_teams then return end
    local frame = player.gui.screen.add{type = "frame", name = "pvp_join_frame", caption = "CHOOSE YOUR HOME PLANET", direction = "vertical"}
    frame.auto_center = true
    for planet, force_name in pairs(storage.planet_teams) do frame.add{type = "button", name = "join_btn_" .. planet, caption = "Join " .. force_name .. " (" .. planet .. ")", style = "confirm_button"} end
end

local function show_waiting(player)
    if player.gui.screen.pvp_waiting_frame then player.gui.screen.pvp_waiting_frame.destroy() end
    local frame = player.gui.screen.add{type = "frame", name = "pvp_waiting_frame", caption = "PLANET PvP LOBBY", direction = "vertical"}
    frame.auto_center = true
    frame.add{type = "label", caption = "The admin is setting up the game. You can choose a team when setup is complete."}
end

function setup.on_init(observer)
    storage.planet_teams, storage.player_targets, storage.grid_pos = {}, {}, {}
    storage.game_started, storage.team_kit_spawned, storage.player_surfaces = false, {}, {}
    storage.player_team_joined = {}
    storage.force_bases, storage.permadead, storage.pending_spectator, storage.force_colors, storage.base_label_ids = {}, {}, {}, {}, {}
    storage.player_lights, storage.crash_site_cleanup_done = {}, false
    observer.create_force()
    set_pvp_relations()
    get_hub_surface()
    for _, player in pairs(game.players) do player.set_shortcut_available("lock_drop_zone_shortcut", true) end
end

function setup.on_configuration_changed()
    for _, key in pairs({"team_kit_spawned", "player_surfaces", "force_bases", "permadead", "pending_spectator", "force_colors", "base_label_ids", "player_targets", "grid_pos", "player_lights", "player_team_joined"}) do storage[key] = storage[key] or {} end
    get_hub_surface()
    for planet_name, force_name in pairs(storage.planet_teams or {}) do
        local force = game.forces[force_name]
        if force then force.unlock_space_location(planet_name) end
    end
    local fulgora = game.planets.fulgora
    if fulgora and fulgora.surface then assign_fulgora_attractors(fulgora.surface) end
    for _, player in pairs(game.players) do player.set_shortcut_available("lock_drop_zone_shortcut", true) end
    for _, player in pairs(game.connected_players) do
        if not has_selected_team(player) then
            teleport_to_hub(player)
            if storage.game_started then show_join(player) elseif player.admin then show_admin(player) else show_waiting(player) end
        end
    end
end

function setup.on_chunk_generated(event)
    if event.surface and event.surface.name == "fulgora" then
        assign_fulgora_attractors(event.surface, event.area)
    end
end

function setup.on_player_created(event)
    local player = game.players[event.player_index]
    storage.player_team_joined = storage.player_team_joined or {}
    player.set_shortcut_available("lock_drop_zone_shortcut", true)
    if player.controller_type == defines.controllers.cutscene then player.exit_cutscene() end
    teleport_to_hub(player)
    if storage.game_started then show_join(player) elseif player.admin then show_admin(player) else show_waiting(player) end
end

function setup.on_player_joined_game(event)
    local player = game.players[event.player_index]
    if not (player and player.valid) then return end
    storage.player_team_joined = storage.player_team_joined or {}
    if has_selected_team(player) or (storage.observers and storage.observers[player.index]) then return end
    teleport_to_hub(player)
    if storage.game_started then show_join(player) elseif player.admin then show_admin(player) else show_waiting(player) end
end

function setup.on_player_respawned(event)
    local player = game.players[event.player_index]
    if player and player.valid and not has_selected_team(player) then
        teleport_to_hub(player)
    end
end

function setup.on_gui_click(event)
    local element, player = event.element, game.players[event.player_index]
    if not (element and element.valid and player and player.valid) then return end
    if element.name == "confirm_admin_setup" then
        storage.planet_teams = {}
        for _, planet in pairs(PLANETS) do
            local textfield = element.parent.setup_table["tf_" .. planet]
            local name = textfield and textfield.text ~= "" and textfield.text or "Team " .. planet
            if not game.forces[name] then game.create_force(name) end
            unlock(game.forces[name], planet); base.assign_force_color(name); storage.planet_teams[planet] = name
        end
        local fulgora = game.planets.fulgora
        if fulgora and fulgora.surface then assign_fulgora_attractors(fulgora.surface) end
        storage.game_started = true; element.parent.destroy()
        for _, target in pairs(game.players) do
            if target.valid and not (storage.player_team_joined and storage.player_team_joined[target.index]) then
                teleport_to_hub(target)
                if target.gui.screen.pvp_waiting_frame then target.gui.screen.pvp_waiting_frame.destroy() end
                show_join(target)
            end
        end
    elseif element.name:find("^join_btn_") then
        local planet_name = element.name:gsub("^join_btn_", "")
        local force_name = storage.planet_teams[planet_name]
        if force_name then
            player.force = game.forces[force_name]; player.clear_items_inside()
            storage.player_team_joined = storage.player_team_joined or {}
            storage.player_team_joined[player.index] = true
            local planet = game.planets[planet_name]
            if planet then
                local surface = planet.create_surface()
                if planet_name == "fulgora" then assign_fulgora_attractors(surface) end
                if not storage.team_kit_spawned[force_name] then
                    storage.team_kit_spawned[force_name] = true
                    local position = surface.find_non_colliding_position("steel-chest", {x = 5, y = 0}, 100, .5) or {x = 5, y = 0}
                    local chest = surface.create_entity{name = "steel-chest", position = position, force = player.force, raise_built = true}
                    if chest and chest.valid then
                        local inventory = chest.get_inventory(defines.inventory.chest)
                        if inventory then for _, item in pairs(LOADOUTS[planet_name]) do if prototypes.item[item.name] then inventory.insert(item) end end end
                    end
                    base.spawn_initial(force_name, planet_name)
                end
                drop_zone.teleport_to_planet(player, surface)
            end
        end
        if element.parent and element.parent.valid then element.parent.destroy() end
    end
end

return setup
