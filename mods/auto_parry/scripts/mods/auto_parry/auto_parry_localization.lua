return {
	mod_name = {
		en = "auto_parry",
	},
	mod_description = {
		en = "Auto-presses the Rapier's weapon special when a nearby enemy starts a melee attack, so it gets parried and the free riposte fires.",
	},
	options_main = {
		en = "Main",
	},
	enable_mod = {
		en = "Enable Mod",
	},
	enable_mod_description = {
		en = "Master switch.",
	},
	toggle_mod_keybind = {
		en = "Toggle Mod Keybind",
	},
	toggle_mod_keybind_description = {
		en = "Toggles Enable Mod in mission.",
	},
	trigger_range = {
		en = "Trigger Range (m)",
	},
	trigger_range_description = {
		en = "Only react to enemies within this distance.",
	},
	press_delay = {
		en = "Press Delay (s)",
	},
	press_delay_description = {
		en = "Wait this long after the windup is detected before pressing the special. 0 presses immediately.",
	},
	options_safety_and_debug = {
		en = "Safety & Debug",
	},
	min_stamina_fraction = {
		en = "Min Stamina Fraction",
	},
	min_stamina_fraction_description = {
		en = "Don't auto-parry below this stamina -- a parry on empty stamina breaks and staggers you.",
	},
	cooldown = {
		en = "Cooldown (s)",
	},
	cooldown_description = {
		en = "Minimum pause between presses, so a dense horde can't trigger one per enemy per frame.",
	},
	debug_notify = {
		en = "Debug Notifications",
	},
	debug_notify_description = {
		en = "On-screen toasts and trace recording for Dump Trace.",
	},
	dump_trace_keybind = {
		en = "Dump Trace Keybind",
	},
	dump_trace_keybind_description = {
		en = "Writes recent trace samples to binaries/dump/auto_parry_trace.json.",
	},
}
