data:extend({
    {
        type = "selection-tool",
        name = "drop-zone-selector",
        icon = "__base__/graphics/icons/artillery-targeting-remote.png",
        icon_size = 64,
        flags = {"not-stackable", "only-in-cursor"},
        stack_size = 1,
        select = {
            border_color = {r = 0, g = 1, b = 0},
            cursor_box_type = "copy",
            mode = {"nothing"}
        },
        alt_select = {
            border_color = {r = 1, g = 0.5, b = 0},
            cursor_box_type = "not-allowed",
            mode = {"nothing"}
        }
    },
    {
        type = "shortcut",
        name = "lock_drop_zone_shortcut",
        action = "lua",
        order = "z[spidertron-remote-b]",
        localised_name = "Drop Zone Selector",
        icon = "__base__/graphics/icons/artillery-targeting-remote.png",
        small_icon = "__base__/graphics/icons/artillery-targeting-remote.png"
    }
})

data:extend({
    {
        type           = "simple-entity-with-owner",
        name           = "pvp-base",
        icon           = "__base__/graphics/icons/market.png",
        icon_size      = 64,
        flags          = { "placeable-neutral", "player-creation", "not-rotatable" },
        weight     = 1000001,
        max_health     = 2000,
        resistances    = {
            { type = "fire",      decrease = 15, percent = 30 },
            { type = "physical",  decrease = 10, percent = 20 },
            { type = "explosion", decrease = 20, percent = 40 },
            { type = "laser",     decrease = 5,  percent = 20 },
        },
        loot = {
            { type = "item", name = "pvp-base-core", amount_min = 1, amount_max = 1, independent_probability = 1 }
        },
        collision_box      = { {-1.2, -1.2}, {1.2, 1.2} },
        selection_box      = { {-1.5, -1.5}, {1.5, 1.5} },
        collision_mask     = { layers = { object = true, player = true } },
        picture = {
            filename = "__base__/graphics/entity/market/market.png",
            priority = "extra-high",
            width    = 156,
            height   = 127,
            shift    = { 1, 0.0001 },
            scale    = 1.0,
        },
        minable            = nil,
        map_color          = { r = 0.9, g = 0.2, b = 0.2 },
        friendly_map_color = { r = 0.2, g = 0.8, b = 0.2 },
        alert_when_damaged = true,
        is_military_target = true,
    }
})

data:extend({
    {
        type         = "item",
        name         = "pvp-base-building",
        icon         = "__base__/graphics/icons/market.png",
        icon_size    = 64,
        subgroup     = "other",
        order        = "z[pvp-base-building]",
        stack_size   = 1,
        weight     = 1000001,
        place_result = "pvp-base",
    }
})

data:extend({
    {
        type       = "item",
        name       = "pvp-base-core",
        icon       = "__Planet-PvP__/Graphics/Base/base_core.png",
        icon_size  = 128,
        subgroup   = "other",
        order      = "z[pvp-base-core]",
        stack_size = 1,
        weight     = 1000001,
    }
})

data:extend({
    {
        type            = "recipe",
        name            = "pvp-base-repair",
        enabled         = true,
        categories       = {"crafting"},
        energy_required = 60,
        ingredients = {
            { type = "item", name = "pvp-base-core", amount = 1 },
            { type = "item", name = "repair-pack",   amount = 1 },
        },
        results = {
            { type = "item", name = "pvp-base-building", amount = 1 },
        },
    }
})

if data.raw["character"] and data.raw["character"]["character"] then
    data.raw["character"]["character"].light = {
        {
            type = "basic",
            intensity = 0,
            size = 0,
            color = {r=0, g=0, b=0}
        }
    }
    data.raw["character"]["character"].flashlight = nil
end

data:extend({
    {
        type = "custom-input",
        name = "planet-pvp-toggle-observer",
        key_sequence = "O",
        consuming = "game-only",
        enabled_while_spectating = true
    }
})