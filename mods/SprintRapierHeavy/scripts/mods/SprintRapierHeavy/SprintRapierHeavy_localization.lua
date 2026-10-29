return {
	mod_name = {
		en = "SprintRapierHeavy",
	},
	mod_description = {
		en = "Sprint, throw a Rapier attack, slide right as it peaks, and chain into the next one -- automated and timed from live game state. Light is the recommended technique; Heavy is experimental and could use testing/tuning help -- see its options section.",
	},
	options_main = {
		en = "Main",
	},
	enable_mod = {
		en = "Enable Mod",
	},
	enable_mod_description = {
		en = "Master switch for SprintRapierHeavy.",
	},
	toggle_mod_keybind = {
		en = "Toggle Mod Keybind",
	},
	toggle_mod_keybind_description = {
		en = "Turns Enable Mod on or off while in mission.",
	},
	technique = {
		en = "Technique",
	},
	technique_description = {
		en = "Which attack is thrown each cycle: an instant light (recommended -- faster cycle, higher average speed), or a charged heavy that force-drops sprint to open the slide door by hand (experimental, measured slower than plain sprinting so far -- see the Heavy Technique section).",
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
		en = "Only slide through the brief walking-state window after a heavy (preserves the heavy's speed boost). Turn off to test sliding straight out of sprint instead.",
	},
	use_fixed_charge_time = {
		en = "Use Fixed Charge Time",
	},
	use_fixed_charge_time_description = {
		en = "Override the weapon's own windup-to-heavy chain time with a fixed value instead. Releasing below the weapon's real minimum (0.375-0.5s depending on the windup) still becomes a heavy -- the input buffers and fires automatically once the windup's own chain time naturally elapses -- so values below the floor cost and gain nothing; this is mainly for trimming the Heavy Release Margin's slack at or just above the real floor.",
	},
	fixed_charge_time = {
		en = "Fixed Charge Time (s)",
	},
	fixed_charge_time_description = {
		en = "Only used when Use Fixed Charge Time is on: how long to hold the windup before releasing.",
	},
	options_light = {
		en = "Light Technique",
	},
	chain_during_glide = {
		en = "Chain Next Attack During Glide",
	},
	chain_during_glide_description = {
		en = "Start charging the next attack right at the end of the current slide instead of waiting to return to a real sprint first -- for testing whether re-attacking right as the slide ends keeps the speed chained.",
	},
	use_fixed_slide_delay = {
		en = "Use Fixed Slide Delay",
	},
	use_fixed_slide_delay_description = {
		en = "Skip speed-peak detection entirely and slide after a fixed delay instead -- for experimenting with entering the slide earlier/later by hand.",
	},
	fixed_slide_delay = {
		en = "Fixed Slide Delay (s)",
	},
	fixed_slide_delay_description = {
		en = "Only used when Use Fixed Slide Delay is on: seconds after the attack starts before forcing the slide.",
	},
	release_margin = {
		en = "Heavy Release Margin (s)",
	},
	release_margin_description = {
		en = "Extra hold time added on top of the weapon's own windup-to-heavy chain time before releasing.",
	},
	options_slide_and_glide = {
		en = "Slide & Glide Tuning",
	},
	slide_speed_threshold = {
		en = "Slide Speed Threshold (m/s)",
	},
	slide_speed_threshold_description = {
		en = "Minimum forward speed required before the mod will trigger the slide.",
	},
	slide_max_wait = {
		en = "Slide Max Wait After Heavy (s)",
	},
	slide_max_wait_description = {
		en = "Trigger the slide after this long into the heavy even if the speed peak hasn't been detected yet.",
	},
	peak_tolerance = {
		en = "Speed Peak Tolerance (m/s)",
	},
	peak_tolerance_description = {
		en = "How much the forward speed must drop from its running peak before it's considered to have peaked.",
	},
	glide_release_speed = {
		en = "Glide Release Speed (m/s)",
	},
	glide_release_speed_description = {
		en = "Stop holding the slide once forward speed decays below this (after Min Glide Time has elapsed).",
	},
	min_glide_time = {
		en = "Min Glide Time (s)",
	},
	min_glide_time_description = {
		en = "Keep holding the slide for at least this long regardless of speed, so a fast decay doesn't end it within a single frame.",
	},
	glide_max_time = {
		en = "Glide Max Time (s)",
	},
	glide_max_time_description = {
		en = "Stop holding the slide after this long regardless of speed.",
	},
	cycle_cooldown = {
		en = "Cycle Cooldown (s)",
	},
	cycle_cooldown_description = {
		en = "Minimum pause after one cycle ends before the next one can start.",
	},
	options_safety_and_debug = {
		en = "Safety & Debug",
	},
	min_stamina_fraction = {
		en = "Min Stamina Fraction",
	},
	min_stamina_fraction_description = {
		en = "Don't start or continue a cycle below this stamina fraction -- running out mid-windup can glitch the release into a light attack.",
	},
	debug_notify = {
		en = "Debug Notifications",
	},
	debug_notify_description = {
		en = "Show on-screen toasts for cycle results (aborted / completed) and record a trace for Dump Trace.",
	},
	dump_trace_keybind = {
		en = "Dump Trace Keybind",
	},
	dump_trace_keybind_description = {
		en = "Writes the last ~600 fixed-frame samples to binaries/dump/sprh_trace.json for tuning.",
	},
}
