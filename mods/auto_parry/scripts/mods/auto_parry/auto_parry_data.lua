local mod = get_mod("auto_parry")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			--- Main ---
			{
				setting_id = "options_main",
				type = "group",
				sub_widgets = {
					{
						setting_id = "enable_mod",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "toggle_mod_keybind",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "toggle_mod_enabled",
					},
					{
						setting_id = "trigger_range",
						type = "numeric",
						default_value = 3.0,
						range = { 1.0, 6.0 },
						decimals_number = 1,
						step_size_value = 0.5,
					},
					{
						setting_id = "pre_hit_margin",
						type = "numeric",
						default_value = 0.2,
						range = { 0, 0.5 },
						decimals_number = 2,
						step_size_value = 0.05,
					},
					{
						setting_id = "press_delay",
						type = "numeric",
						default_value = 0.3,
						range = { 0, 0.5 },
						decimals_number = 2,
						step_size_value = 0.05,
					},
				},
			},

			--- Safety + debug ---
			{
				setting_id = "options_safety_and_debug",
				type = "group",
				sub_widgets = {
					{
						setting_id = "min_stamina_fraction",
						type = "numeric",
						default_value = 0.15,
						range = { 0, 0.5 },
						decimals_number = 2,
						step_size_value = 0.05,
					},
					{
						setting_id = "cooldown",
						type = "numeric",
						default_value = 0.5,
						range = { 0.1, 2.0 },
						decimals_number = 1,
						step_size_value = 0.1,
					},
					{
						setting_id = "debug_notify",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "dump_trace_keybind",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "dump_trace",
					},
				},
			},
		},
	},
}
