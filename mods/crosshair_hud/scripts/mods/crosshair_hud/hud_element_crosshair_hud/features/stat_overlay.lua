local mod = get_mod("crosshair_hud")
local mod_utils = mod.utils
local _shadows_enabled = mod_utils.shadows_enabled

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

local BuffSettings = require("scripts/settings/buff/buff_settings")

local global_scale = mod:get("global_scale")
local stat_overlay_scale = mod:get("stat_overlay_scale") * global_scale

local global_offset = {
    mod:get("global_x_offset"),
    mod:get("global_y_offset")
}
local stat_overlay_offset = {
    mod:get("stat_overlay_x_offset"),
    mod:get("stat_overlay_y_offset")
}

local feature_name = "stat_overlay_indicator"
local feature = {
    name = feature_name
}

feature.scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
    --[feature_name] = {
    --    parent = "screen",
    --    vertical_alignment = "center",
    --    horizontal_alignment = "center",
    --    size = { 150 * stat_overlay_scale, 25 * stat_overlay_scale },
    --    position = {
    --        global_offset[1] + stat_overlay_offset[1],
    --        global_offset[2] + stat_overlay_offset[2],
    --        55
    --    }
    --}
}

local buff_choices = {
    "critical_strike_chance",
    "warp_damage",
    "critical_strike_damage"
}
function feature.create_widget_definitions()
    local widget_definitions = {}

    for i = 1, 3 do
        local setting_id = string.format("display_stat_overlay_%s", i)
        local buff_choice = mod:get(setting_id)

        if buff_choice ~= "none" then
            feature.scenegraph_definition[buff_choice] = {
                parent = "screen",
                vertical_alignment = "center",
                horizontal_alignment = "center",
                size = { 150 * stat_overlay_scale, 25 * stat_overlay_scale },
                position = {
                    global_offset[1] + stat_overlay_offset[1],
                    (global_offset[2] + stat_overlay_offset[2]) + ((i - 1) * (25 * stat_overlay_scale)),
                    55
                }
            }

            widget_definitions[buff_choice] = UIWidget.create_definition({
                {
                    pass_type = "text",
                    value = "[Test]",
                    value_id = "text",
                    style_id = "text",
                    style = {
                        font_type = "proxima_nova_bold",
                        font_size = 18 * stat_overlay_scale,
                        text_color = UIHudSettings.color_tint_main_2,
                        text_vertical_alignment = "center",
                        text_horizontal_alignment = "center",
                        offset = { 0, 0, 0 }
                    }
                }
            }, buff_choice)
        end
    end

    return widget_definitions
end

function feature.update(parent)
    for i, buff_choice in ipairs(buff_choices) do
        repeat
            local widget = parent._widgets_by_name[buff_choice]
            if not widget then
                break
            end

            local display_indicator = mod:get("display_stat_overlay_indicator")
            local content = widget.content
            local style = widget.style

            content.visible = display_indicator

            if not display_indicator then
                return
            end

            local player_extensions = parent._parent:player_extensions()
            local buff_extension = player_extensions.buff
            local stat_buffs = buff_extension:stat_buffs()
            local stat_buff = buff_choice
            local stat_buff_type = BuffSettings.stat_buff_types[stat_buff]
            local stat_buff_value = stat_buffs[stat_buff] or 0

            if stat_buff_type == "value" or stat_buff_type == "additive_multiplier" then
                content.text = string.format("%.1f%%", stat_buff_value * 100)
            elseif stat_buff_type == "multiplicative_multiplier" then
                content.text = string.format("x%.1f%%", stat_buff_value * 100)
            else
                content.text = string.format("+%.1f%%", stat_buff_value * 100)
            end
        until true
    end
end

return feature