local mod_gui = require("__core__.lualib.mod-gui")

local observer = {}

local PLANETS = {
    "nauvis",
    "vulcanus",
    "fulgora",
    "gleba",
    "aquilo"
}

local function get_data(player)

    storage.observers = storage.observers or {}

    if not storage.observers[player.index] then
        storage.observers[player.index] = {
            following = nil,
            perspective = "observer",
            gui_open = false
        }
    end

    return storage.observers[player.index]

end

local function is_observer(player)
    return player.controller_type == defines.controllers.spectator
end

local function create_observer_force()

    local force = game.forces["observer"]

    if not force then
        force = game.create_force("observer")
    end

    return force

end

observer.create_force = create_observer_force

function observer.create_button(player)

    if not is_observer(player) then
        return
    end

    local flow = mod_gui.get_button_flow(player)

    if flow.observer_button then
        return
    end

    flow.add{
        type = "sprite-button",
        name = "observer_button",
        sprite = "utility/search_icon",
        tooltip = "Observer"
    }

end

function observer.destroy_button(player)

    local flow = mod_gui.get_button_flow(player)

    if flow.observer_button then
        flow.observer_button.destroy()
    end

    if player.gui.screen.observer_window then
        player.gui.screen.observer_window.destroy()
    end

end

local function build_window(player)

    local data = get_data(player)
    local selected_force_name = nil

    if data.perspective
    and data.perspective ~= "observer"
    and storage.planet_teams then
        selected_force_name = storage.planet_teams[data.perspective]
    end

    if player.gui.screen.observer_window then
        player.gui.screen.observer_window.destroy()
    end

    local frame = player.gui.screen.add{
        type = "frame",
        name = "observer_window",
        direction = "vertical",
        caption = "Observer"
    }

    frame.auto_center = true
    player.opened = frame

    local perspective_header = frame.add{
        type = "flow",
        direction = "horizontal"
    }

    perspective_header.add{
        type = "sprite",
        sprite = "utility/search_icon"
    }

    perspective_header.add{
        type = "label",
        caption = "Perspective"
    }

    local perspective_flow = frame.add{
        type = "flow",
        direction = "horizontal"
    }

    for _, planet in ipairs(PLANETS) do
        perspective_flow.add{
            type = "sprite-button",
            name = "observer_perspective_" .. planet,
            sprite = "space-location/" .. planet,
            tooltip = planet:gsub("^%l", string.upper),
            style = "slot_button",
            toggled = data.perspective == planet
        }
    end

    frame.add{
        type = "line"
    }

    local perspective_caption = "None selected"

    if selected_force_name then
        perspective_caption = selected_force_name
    end

    frame.add{
        type = "label",
        caption = "Viewing: " .. perspective_caption
    }

    frame.add{
        type = "line"
    }

    local platform_header = frame.add{
        type = "flow",
        direction = "horizontal"
    }

    platform_header.add{
        type = "sprite",
        sprite = "item/space-platform-foundation"
    }

    platform_header.add{
        type = "label",
        caption = "Team Platforms"
    }

    local platform_scroll = frame.add{
        type = "scroll-pane",
        name = "observer_platforms"
    }

    platform_scroll.style.maximal_height = 220

    local platforms_found = 0

    if selected_force_name then
        for _, surface in pairs(game.surfaces) do
            local platform = surface.platform

            if platform
            and platform.valid
            and platform.force
            and platform.force.name == selected_force_name then

                local caption =
                    "[img=item/space-platform-foundation] "
                    .. platform.name

                if platform.space_location then
                    caption = caption
                        .. " (" .. platform.space_location.name .. ")"
                elseif platform.space_connection then
                    caption = caption .. " (traveling)"
                end

                platform_scroll.add{
                    type = "button",
                    name = "observer_platform_" .. platform.index,
                    caption = caption
                }

                platforms_found = platforms_found + 1
            end
        end
    end

    if not selected_force_name then
        platform_scroll.add{
            type = "label",
            caption = "Select a team perspective."
        }
    elseif platforms_found == 0 then
        platform_scroll.add{
            type = "label",
            caption = "No platforms owned by this team."
        }
    end

    frame.add{
        type = "line"
    }

    local player_header = frame.add{
        type = "flow",
        direction = "horizontal"
    }

    player_header.add{
        type = "sprite",
        sprite = "entity/character"
    }

    player_header.add{
        type = "label",
        caption = "Team Players"
    }

    local scroll = frame.add{
        type = "scroll-pane",
        name = "observer_players"
    }

    scroll.style.maximal_height = 320

    local players_found = 0

    for _, target in pairs(game.connected_players) do

        local target_is_observer =
            storage.observers
            and storage.observers[target.index] ~= nil

        local belongs_to_selected_team =
            selected_force_name
            and target.force
            and target.force.name == selected_force_name

        if belongs_to_selected_team and not target_is_observer then

            local caption = "[img=entity/character] " .. target.name

            if not target.character then
                caption = caption .. " (dead)"
            elseif target.surface and target.surface.platform then
                caption = caption .. " (platform)"
            elseif target.surface then
                caption = caption .. " (" .. target.surface.name .. ")"
            end

            scroll.add{
                type = "button",
                name = "observer_follow_" .. target.index,
                caption = caption
            }

            players_found = players_found + 1
        end
    end

    if not selected_force_name then
        scroll.add{
            type = "label",
            caption = "Select a team perspective."
        }
    elseif players_found == 0 then
        scroll.add{
            type = "label",
            caption = "No connected non-observer players on this team."
        }
    end

    frame.add{
        type = "line"
    }

    frame.add{
        type = "button",
        name = "observer_stop_follow",
        caption = "[img=utility/close] Stop Following"
    }

    data.gui_open = true
end

function observer.toggle_window(player)

    if not player or not player.valid then
        return
    end

    if not is_observer(player) then
        return
    end

    local data = get_data(player)
    local window = player.gui.screen.observer_window

    if window and window.valid then

        if player.opened == window then
            player.opened = nil
        end

        window.destroy()
        data.gui_open = false
    else
        build_window(player)
    end
end

function observer.on_gui_click(event)

    local player = game.get_player(event.player_index)
    if not player then
        return false
    end

    if not is_observer(player) then
        return false
    end

    local element = event.element
    if not (element and element.valid) then
        return false
    end

    local data = get_data(player)

    if element.name == "observer_button" then

        if player.gui.screen.observer_window then
            player.gui.screen.observer_window.destroy()
            data.gui_open = false
        else
            build_window(player)
        end

        return true
    end

if element.name:find("^observer_perspective_") then

    local perspective =
        element.name:gsub("^observer_perspective_", "")

    local force_name =
        storage.planet_teams
        and storage.planet_teams[perspective]

    local force =
        force_name
        and game.forces[force_name]

    if force then
        player.force = force
        data.perspective = perspective
        data.following = nil

        local surface = game.surfaces[perspective]

        if surface then
            player.teleport({0, 0}, surface)
        end

        player.print("Perspective: " .. force.name)

        build_window(player)
    else
        player.print(
            "Force not found for perspective: "
            .. tostring(perspective)
        )
    end

    return true
end

    if element.name:find("^observer_follow_") then

        local id = tonumber(element.name:match("%d+"))

        if id then
            local target = game.get_player(id)

            if target and target.valid and target.character and target.character.valid then
                data.following = id
                player.centered_on = target.character
                player.print("Now following " .. target.name)
            else
                player.print("That player is not currently available to follow.")
            end
        end

        return true
    end

    if element.name:find("^observer_platform_") then

        local platform_index =
            tonumber(element.name:match("%d+"))

        local selected_platform = nil

        if platform_index then
            for _, surface in pairs(game.surfaces) do
                local platform = surface.platform

                if platform
                and platform.valid
                and platform.index == platform_index then
                    selected_platform = platform
                    break
                end
            end
        end

        if selected_platform
        and selected_platform.surface
        and selected_platform.surface.valid then

            data.following = nil

            player.teleport(
                {0, 0},
                selected_platform.surface
            )

            player.print(
                "Viewing platform: "
                .. selected_platform.name
            )
        else
            player.print("Platform is no longer available.")
            build_window(player)
        end

        return true
    end

    if element.name == "observer_stop_follow" then

        data.following = nil
        player.print("Stopped following.")

        return true
    end
end

function observer.on_tick(event)

    if not storage.observers then
        return
    end

    for player_index, data in pairs(storage.observers) do

        local observer_player = game.get_player(player_index)

        if observer_player
        and observer_player.valid
        and observer_player.controller_type == defines.controllers.spectator
        and data.following then

            local target = game.get_player(data.following)

            if target
            and target.valid
            and target.connected
            and target.character then

                if observer_player.surface ~= target.surface then

                    observer_player.teleport(
                        target.position,
                        target.surface
                    )

                else

                    local dx = observer_player.position.x - target.position.x
                    local dy = observer_player.position.y - target.position.y

                    if math.abs(dx) > 2
                    or math.abs(dy) > 2 then

                        observer_player.teleport(
                            target.position,
                            target.surface
                        )

                    end

                end

            else

                data.following = nil

                observer_player.print("Target unavailable.")

            end

        end

    end

end

function observer.enable(player)

    local force = create_observer_force()

    player.force = force

    player.set_controller{
    type = defines.controllers.spectator
}

    player.print("Perspective: " .. force.name)

    player.show_on_map = false

    player.set_controller{
        type = defines.controllers.spectator
    }

    get_data(player)

    observer.create_button(player)

end

function observer.disable(player)

    observer.destroy_button(player)

    if storage.observers then
        storage.observers[player.index] = nil
    end

end

--------------------------------------------------------------------------------

return  observer
