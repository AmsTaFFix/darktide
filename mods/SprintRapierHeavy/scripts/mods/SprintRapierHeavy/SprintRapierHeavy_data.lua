local mod = get_mod("SprintRapierHeavy")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
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
		},
	},
}
