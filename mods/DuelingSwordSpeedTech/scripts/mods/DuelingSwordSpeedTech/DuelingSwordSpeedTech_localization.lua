return {
	mod_name = {
		en = "Dueling Sword Speed Tech",
	},
	mod_description = {
		en = "Sprint, attack, and slide right as speed peaks -- then chains into the next attack. Light is recommended; Heavy is experimental.",
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
	technique = {
		en = "Technique",
	},
	technique_description = {
		en = "Light: instant, faster, recommended. Heavy: charged, higher peaks but slower on average -- experimental.",
	},
	technique_heavy = {
		en = "Heavy (charge + release) [experimental]",
	},
	technique_light = {
		en = "Light (instant release)",
	},
	options_heavy = {
		en = "Heavy Technique (experimental, needs testing/tuning)",
	},
	require_walking_state = {
		en = "Require Walking-State Slide Window",
	},
	require_walking_state_description = {
		en = "Only slide in the brief post-heavy walking window, which keeps the speed boost. Off = slide straight from sprint instead.",
	},
	use_fixed_charge_time = {
		en = "Use Fixed Charge Time",
	},
	use_fixed_charge_time_description = {
		en = "Release the windup after a fixed time instead of the weapon's own chain timing. Below the weapon's real minimum (0.375-0.5s) it still becomes a heavy, just delayed -- no real downside, no real gain.",
	},
	fixed_charge_time = {
		en = "Fixed Charge Time (s)",
	},
	fixed_charge_time_description = {
		en = "Used only when Use Fixed Charge Time is on.",
	},
	options_light = {
		en = "Light Technique",
	},
	chain_during_glide = {
		en = "Chain Next Attack During Glide",
	},
	chain_during_glide_description = {
		en = "Start the next attack at the tail of the current slide instead of waiting for a full sprint first.",
	},
	use_fixed_slide_delay = {
		en = "Use Fixed Slide Delay",
	},
	use_fixed_slide_delay_description = {
		en = "Slide after a fixed delay instead of detecting the speed peak.",
	},
	fixed_slide_delay = {
		en = "Fixed Slide Delay (s)",
	},
	fixed_slide_delay_description = {
		en = "Used only when Use Fixed Slide Delay is on.",
	},
	release_margin = {
		en = "Heavy Release Margin (s)",
	},
	release_margin_description = {
		en = "Extra hold time on top of the weapon's windup-to-heavy chain time.",
	},
	options_slide_and_glide = {
		en = "Slide & Glide Tuning",
	},
	slide_speed_threshold = {
		en = "Slide Speed Threshold (m/s)",
	},
	slide_speed_threshold_description = {
		en = "Minimum forward speed to trigger the slide.",
	},
	slide_max_wait = {
		en = "Slide Max Wait After Heavy (s)",
	},
	slide_max_wait_description = {
		en = "Force the slide after this long even without a detected peak.",
	},
	peak_tolerance = {
		en = "Speed Peak Tolerance (m/s)",
	},
	peak_tolerance_description = {
		en = "How far speed must drop from its peak before it counts as peaked.",
	},
	glide_release_speed = {
		en = "Glide Release Speed (m/s)",
	},
	glide_release_speed_description = {
		en = "Stop the slide once speed decays below this (after Min Glide Time).",
	},
	min_glide_time = {
		en = "Min Glide Time (s)",
	},
	min_glide_time_description = {
		en = "Keep the slide this long regardless of speed, so it can't end in one frame.",
	},
	glide_max_time = {
		en = "Glide Max Time (s)",
	},
	glide_max_time_description = {
		en = "Stop the slide after this long regardless of speed.",
	},
	cycle_cooldown = {
		en = "Cycle Cooldown (s)",
	},
	cycle_cooldown_description = {
		en = "Minimum pause between cycles.",
	},
	options_safety_and_debug = {
		en = "Safety & Debug",
	},
	min_stamina_fraction = {
		en = "Min Stamina Fraction",
	},
	min_stamina_fraction_description = {
		en = "Don't run a cycle below this stamina -- empty stamina can glitch the release.",
	},
	debug_notify = {
		en = "Debug Notifications",
	},
	debug_notify_description = {
		en = "On-screen toasts per cycle and trace recording for Dump Trace.",
	},
	dump_trace_keybind = {
		en = "Dump Trace Keybind",
	},
	dump_trace_keybind_description = {
		en = "Writes the last ~600 samples to binaries/dump/sprh_trace.json.",
	},
}
