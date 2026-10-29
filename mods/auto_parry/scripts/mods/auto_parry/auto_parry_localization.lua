return {
	mod_name = {
		en = "auto_parry",
	},
	mod_description = {
		en = "Auto-presses the Dueling Sword's weapon special when a nearby enemy starts a melee attack, so it gets parried and the free riposte fires.",
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
		en = "In a real mission (non-host), where the attacker's real target is unknown: only react to enemies within this distance. In Psykhanium/Meat Grinder (host), the real target is known, so this isn't used -- a charging attack's windup can start outside this range and still land.",
	},
	pre_hit_margin = {
		en = "Pre-Hit Margin (s)",
	},
	pre_hit_margin_description = {
		en = "In Psykhanium/Meat Grinder (host), where the real hit timing is known: press this long before the hit instead of the instant the windup is seen.",
	},
	press_delay = {
		en = "Press Delay (s)",
	},
	press_delay_description = {
		en = "In a real mission (non-host), where the real hit timing is NOT known: wait this long after the windup is detected before pressing. 0 presses immediately.",
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
		en = "Minimum pause between actual presses (checked right before pressing, not at detection -- a threat detected during the pause is still scheduled, just pressed late if the cooldown hasn't cleared by its real hit time).",
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
