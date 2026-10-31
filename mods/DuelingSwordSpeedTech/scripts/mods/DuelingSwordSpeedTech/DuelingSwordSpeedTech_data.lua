local mod = get_mod("DuelingSwordSpeedTech")

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
						setting_id = "technique",
						type = "dropdown",
						default_value = "light",
						options = {
							{ text = "technique_heavy", value = "heavy" },
							{ text = "technique_light", value = "light" },
						},
					},
				},
			},

			--- Heavy technique ---
			{
				setting_id = "options_heavy",
				type = "group",
				sub_widgets = {
					{
						setting_id = "require_walking_state",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "release_margin",
						type = "numeric",
						default_value = 0.02,
						range = { 0, 0.3 },
						decimals_number = 2,
						step_size_value = 0.01,
					},
					{
						setting_id = "use_fixed_charge_time",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "fixed_charge_time",
						type = "numeric",
						default_value = 0.3,
						range = { 0.05, 1.0 },
						decimals_number = 2,
						step_size_value = 0.01,
					},
				},
			},

			--- Light technique ---
			{
				setting_id = "options_light",
				type = "group",
				sub_widgets = {
					{
						setting_id = "chain_during_glide",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "use_fixed_slide_delay",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "fixed_slide_delay",
						type = "numeric",
						default_value = 0.1,
						range = { 0, 0.6 },
						decimals_number = 2,
						step_size_value = 0.01,
					},
				},
			},

			--- Shared: slide/glide tuning (both techniques go through the same tracking, sliding
			--- and gliding phases once their attack is thrown) ---
			{
				setting_id = "options_slide_and_glide",
				type = "group",
				sub_widgets = {
					{
						setting_id = "slide_speed_threshold",
						type = "numeric",
						default_value = 4.3,
						range = { 3.5, 8 },
						decimals_number = 1,
						step_size_value = 0.1,
					},
					{
						setting_id = "slide_max_wait",
						type = "numeric",
						default_value = 0.35,
						range = { 0.05, 0.6 },
						decimals_number = 2,
						step_size_value = 0.01,
					},
					{
						setting_id = "peak_tolerance",
						type = "numeric",
						default_value = 0.02,
						range = { 0, 0.5 },
						decimals_number = 2,
						step_size_value = 0.01,
					},
					{
						setting_id = "glide_release_speed",
						type = "numeric",
						default_value = 4.4,
						range = { 2, 8 },
						decimals_number = 1,
						step_size_value = 0.1,
					},
					{
						setting_id = "min_glide_time",
						type = "numeric",
						default_value = 0.2,
						range = { 0, 1.0 },
						decimals_number = 2,
						step_size_value = 0.05,
					},
					{
						setting_id = "glide_max_time",
						type = "numeric",
						default_value = 2.0,
						range = { 0.2, 2.0 },
						decimals_number = 2,
						step_size_value = 0.05,
					},
					{
						setting_id = "cycle_cooldown",
						type = "numeric",
						default_value = 0.1,
						range = { 0, 1.5 },
						decimals_number = 2,
						step_size_value = 0.05,
					},
				},
			},

			--- Shared: safety + debug ---
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
