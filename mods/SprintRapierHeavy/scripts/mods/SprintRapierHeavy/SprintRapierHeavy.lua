-- Derived from SprintKnifeHeavy by ImperialSkoom (Nexus mod 799, v1.0.5). The Rapier (Duelling
-- Sword, combatsword_p3 family) needs more than "hold heavy while sprinting": the actual speed
-- tech is sprint -> throw an attack -> slide right as its move-speed curve peaks, so the slide
-- locks in the boosted velocity instead of sprint's own (unboosted) slide-entry speed -- then,
-- with chain_during_glide on, start the next attack right at the tail of that slide instead of
-- waiting to rebuild a full sprint, so the boosted cycle repeats back to back.
--
-- Two techniques (see the "technique" setting) share that shape but differ in how the windup is
-- released and how the door out of "sprinting" (required to keep the boost through the slide --
-- see PHASE_EXIT_SPRINT below) gets opened:
--   - "heavy": charge+release a heavy (the chain's own minimum hold time), then force-drop the
--     sprint input to open the walking-state slide door by hand.
--   - "light" (the one that actually worked out live -- see issue #14): release the windup
--     almost immediately for an instant light, then slide straight out of "sprinting" without
--     any sprint-drop maneuver at all. An earlier attempt chained the light into a block to open
--     the walking door (block is in the engine's own prevent_sprint list) but that turned out
--     unnecessary and, worse, the block's own negative movement curve ate into the glide -- going
--     straight into the slide from "sprinting" preserves more speed through the friction grace
--     period and is simpler.
local mod = get_mod("SprintRapierHeavy")

local HEALTH_ALIVE = HEALTH_ALIVE
local Managers = Managers
local ScriptUnit = ScriptUnit
local Unit = Unit
local Vector3_dot = Vector3.dot
local Vector3_flat = Vector3.flat
local Vector3_length = Vector3.length
local Vector3_normalize = Vector3.normalize
local Quaternion_forward = Quaternion.forward

local RAPIER_WEAPONS = {
	combatsword_p3_m1 = true,
	combatsword_p3_m2 = true,
	combatsword_p3_m3 = true,
}

local HEAVY_ACTIONS = {
	action_left_heavy = true,
	action_right_heavy = true,
}

local TECHNIQUE_HEAVY = "heavy"
local TECHNIQUE_LIGHT = "light"

-- Fallback chain_time if we can't read it off the live weapon_template (should not normally
-- happen -- see confirm_release_time()). Matches the slowest known windup -> heavy chain.
local DEFAULT_RELEASE_TIME = 0.5

-- light: the windup's own light_attack chain_time is always 0 (any release counts), so we just
-- need to hold action_one_hold long enough for start_attack to register before letting go.
local LIGHT_RELEASE_TIME = 0.05

local MANUAL_OVERRIDE_DURATION = 0.20

local INTERCEPTED_INPUTS = {
	action_one_hold = true,
	action_one_pressed = true,
	action_two_hold = true,
	weapon_extra_pressed = true,
	weapon_extra_hold = true,
	weapon_reload_hold = true,
	quick_wield = true,
	sprint = true,
	sprinting = true,
	hold_to_sprint = true,
	hold_to_crouch = true,
	move_forward = true,
	crouch = true,
	crouching = true,
}

local cached_input = {
	sprint = false,
	sprinting = false,
	hold_to_sprint = false,
	hold_to_crouch = false,
	move_forward = nil,
}

-- Phases of one sprint -> heavy -> slide cycle. "idle" means not currently mid-cycle; the mod
-- only forces inputs outside of "idle".
local PHASE_IDLE = "idle"
local PHASE_CHARGING = "charging" -- forcing action_one_hold = true (windup)
local PHASE_RELEASING = "releasing" -- forcing action_one_hold = false for a couple of frames
local PHASE_TRACKING = "tracking" -- heavy attack running, watching for the speed peak
local PHASE_EXIT_SPRINT = "exit_sprint" -- forcing sprint = false to force sprinting -> walking
local PHASE_SLIDING = "sliding" -- forcing the crouch input that starts the slide
local PHASE_GLIDING = "gliding" -- forcing crouching = true to extend the slide

local controller = {
	override_until_t = 0,
	external_hold_override = false,
	phase = PHASE_IDLE,
	phase_entered_t = 0,
	heavy_start_t = nil,
	prev_speed = 0,
	crouch_pulse_sent = false,
	cooldown_until_t = 0,
}

local player_weapon_extension = nil
local setting_enabled = true
local settings = {}

-- Set by abort_cycle()/the glide-done success path, recorded into every trace sample from then
-- on so a dump shows exactly why the most recent cycle ended without needing to catch a toast.
local last_event = ""

-- Ring buffer of recent fixed-frame samples, dumped on demand via dump_trace_keybind.
local TRACE_CAPACITY = 600
local trace = { samples = {}, next_index = 1 }

local function refresh_enabled_setting()
	local stored_value = mod:get("enable_mod")
	setting_enabled = stored_value == nil and true or stored_value
	return setting_enabled
end

local function refresh_settings()
	settings.release_margin = mod:get("release_margin") or 0.02
	settings.slide_speed_threshold = mod:get("slide_speed_threshold") or 4.3
	settings.slide_max_wait = mod:get("slide_max_wait") or 0.35
	settings.peak_tolerance = mod:get("peak_tolerance") or 0.02
	settings.glide_release_speed = mod:get("glide_release_speed") or 4.4
	settings.min_glide_time = mod:get("min_glide_time") or 0.2
	settings.glide_max_time = mod:get("glide_max_time") or 2.0
	settings.cycle_cooldown = mod:get("cycle_cooldown") or 0.1
	settings.min_stamina_fraction = mod:get("min_stamina_fraction") or 0.15
	settings.technique = mod:get("technique") or TECHNIQUE_LIGHT
	if settings.technique ~= TECHNIQUE_HEAVY and settings.technique ~= TECHNIQUE_LIGHT then
		-- Migrate a stale value from before the dropdown's options were renamed (was
		-- "light_block" when that technique still chained into a block).
		settings.technique = TECHNIQUE_LIGHT
		mod:set("technique", TECHNIQUE_LIGHT)
	end
	settings.use_fixed_charge_time = mod:get("use_fixed_charge_time")
	if settings.use_fixed_charge_time == nil then
		settings.use_fixed_charge_time = false
	end
	settings.fixed_charge_time = mod:get("fixed_charge_time") or 0.3
	settings.use_fixed_slide_delay = mod:get("use_fixed_slide_delay")
	if settings.use_fixed_slide_delay == nil then
		settings.use_fixed_slide_delay = false
	end
	settings.fixed_slide_delay = mod:get("fixed_slide_delay") or 0.1
	settings.chain_during_glide = mod:get("chain_during_glide")
	if settings.chain_during_glide == nil then
		settings.chain_during_glide = true
	end
	settings.require_walking_state = mod:get("require_walking_state")
	if settings.require_walking_state == nil then
		settings.require_walking_state = true
	end
	settings.debug_notify = mod:get("debug_notify")
	if settings.debug_notify == nil then
		settings.debug_notify = true
	end
end

local function gameplay_time()
	if not (Managers and Managers.time) then
		return 0
	end

	local ok, t = pcall(Managers.time.time, Managers.time, "gameplay")
	return ok and type(t) == "number" and t or 0
end

local function local_player()
	local player_manager = Managers and Managers.player
	return player_manager and player_manager:local_player_safe(1)
end

local function local_player_unit()
	local player = local_player()
	return player and player.player_unit
end

local function ui_using_input()
	return Managers and Managers.ui and Managers.ui:using_input() or false
end

local function in_hub()
	local state_manager = Managers and Managers.state
	local game_mode_manager = state_manager and state_manager.game_mode
	local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()
	return game_mode_name == "hub"
end

local function unit_data_extension(unit)
	return unit and ScriptUnit.has_extension(unit, "unit_data_system")
end

local function set_phase(phase, t)
	controller.phase = phase
	controller.phase_entered_t = t
end

local function abort_cycle(t, reason)
	last_event = reason or "?"

	if controller.phase ~= PHASE_IDLE and settings.debug_notify then
		mod:notify(string.format("SprintRapierHeavy: cycle aborted (%s)", reason or "?"))
	end

	controller.heavy_start_t = nil
	controller.prev_speed = 0
	controller.crouch_pulse_sent = false
	controller.cooldown_until_t = t + settings.cycle_cooldown
	set_phase(PHASE_IDLE, t)
end

local function reset_controller()
	controller.override_until_t = 0
	controller.external_hold_override = false
	controller.cooldown_until_t = 0
	cached_input.sprint = false
	cached_input.sprinting = false
	cached_input.hold_to_sprint = false
	cached_input.hold_to_crouch = false
	cached_input.move_forward = nil
	set_phase(PHASE_IDLE, gameplay_time())
end

local function cache_input(action_name, value)
	if INTERCEPTED_INPUTS[action_name] then
		cached_input[action_name] = value
	end
end

local function raw_input_value(input_service, action_name)
	local action_rule = input_service and input_service._actions and input_service._actions[action_name]
	if not action_rule then
		return nil
	end

	if action_rule.filter then
		return action_rule.eval_func(action_rule.eval_obj, action_rule.eval_param)
	end

	local out = action_rule.default_func()
	local action_type = action_rule.type
	local action_type_data = action_type and InputService.ACTION_TYPES[action_type]
	local combiner = action_type_data and action_type_data.combine_func

	if not combiner then
		return out
	end

	for _, cb in ipairs(action_rule.callbacks) do
		out = combiner(out, cb())
	end

	return out
end

local function manual_override_active()
	return gameplay_time() < (controller.override_until_t or 0)
end

local function trigger_manual_override()
	controller.override_until_t = gameplay_time() + MANUAL_OVERRIDE_DURATION
end

local function set_external_hold_override(active)
	controller.external_hold_override = active and true or false
end

local function current_weapon_template()
	if not player_weapon_extension then
		return nil
	end

	local inventory = player_weapon_extension._inventory_component
	local wielded_slot = inventory and inventory.wielded_slot
	local wielded_weapon = wielded_slot and player_weapon_extension._weapons and player_weapon_extension._weapons[wielded_slot]
	return wielded_weapon and wielded_weapon.weapon_template
end

local function is_rapier()
	local player_unit = local_player_unit()
	if not player_unit or not HEALTH_ALIVE[player_unit] or not Unit.alive(player_unit) then
		return false
	end

	local weapon_template = current_weapon_template()
	local keywords = weapon_template and weapon_template.keywords
	if not weapon_template or not keywords or not table.array_contains(keywords, "melee") then
		return false
	end

	return RAPIER_WEAPONS[weapon_template.name] == true
end

local function is_sprinting()
	local ok, result = pcall(function()
		local player_unit = local_player_unit()
		local uds = unit_data_extension(player_unit)
		local sprint_component = uds and uds:read_component("sprint_character_state")
		return sprint_component and sprint_component.is_sprinting or false
	end)

	return ok and result or false
end

local function sprint_requested()
	return cached_input.sprint or cached_input.hold_to_sprint or cached_input.sprinting or is_sprinting()
end

-- Forward speed along the camera's flat look direction, matching the engine's own
-- accelerated_local_space_movement.lua wants_slide check. Falls back to raw velocity magnitude
-- if the first-person component isn't readable for some reason.
local function forward_speed(uds)
	local locomotion = uds:read_component("locomotion")
	local velocity = locomotion and locomotion.velocity_current
	if not velocity then
		return 0
	end

	local first_person = uds:read_component("first_person")
	local rotation = first_person and first_person.rotation
	if not rotation then
		return Vector3_length(velocity)
	end

	local ok, flat_forward = pcall(function()
		return Vector3_normalize(Vector3_flat(Quaternion_forward(rotation)))
	end)

	if not ok or not flat_forward then
		return Vector3_length(velocity)
	end

	return Vector3_dot(velocity, flat_forward)
end

local function record_sample(t, speed, character_state_name, is_crouching, current_action_name, used_input, stamina_fraction)
	local sample = {
		t = t,
		phase = controller.phase,
		speed = speed,
		state = character_state_name,
		crouching = is_crouching,
		action = current_action_name,
		input = used_input,
		stamina = stamina_fraction,
		event = last_event,
	}

	trace.samples[trace.next_index] = sample
	trace.next_index = trace.next_index + 1
	if trace.next_index > TRACE_CAPACITY then
		trace.next_index = 1
	end
end

-- Earliest release point for the windup currently running, read straight off the live weapon
-- template instead of hardcoding per-action numbers (handles m1/m2/m3 and left/right/second
-- windups uniformly). Falls back to DEFAULT_RELEASE_TIME if the action isn't a recognised windup.
local function confirm_release_time(weapon_template, action_name)
	local actions = weapon_template and weapon_template.actions
	local action_settings = actions and actions[action_name]
	local chain = action_settings and action_settings.allowed_chain_actions and action_settings.allowed_chain_actions.heavy_attack
	local chain_time = chain and chain.chain_time

	if type(chain_time) ~= "number" then
		return DEFAULT_RELEASE_TIME
	end

	return math.max(0.3, chain_time) + (settings.release_margin or 0)
end

-- Drives the sprint -> heavy -> slide phase machine. Called once per fixed frame for the local
-- player (piggybacking on PlayerUnitWeaponExtension.fixed_update, which already fires every
-- fixed step regardless of which input actions get queried that frame).
local function update_phase_machine(unit, t)
	local can_run = mod:is_enabled()
		and setting_enabled
		and not ui_using_input()
		and not in_hub()
		and not manual_override_active()
		and not controller.external_hold_override
		and is_rapier()

	local uds = unit_data_extension(unit)
	if not uds then
		if controller.phase ~= PHASE_IDLE then
			abort_cycle(t, "no_unit_data")
		end

		return
	end

	local character_state = uds:read_component("character_state")
	local movement_state = uds:read_component("movement_state")
	local walking_state = uds:read_component("walking_character_state")
	local weapon_action = uds:read_component("weapon_action")
	local stamina = uds:read_component("stamina")
	local state_name = character_state and character_state.state_name
	local is_crouching = movement_state and movement_state.is_crouching
	local speed = forward_speed(uds)
	local current_action_name = weapon_action and weapon_action.current_action_name
	local action_start_t = weapon_action and weapon_action.start_t
	local used_input = weapon_action and weapon_action.used_input
	local stamina_fraction = stamina and stamina.current_fraction or 1

	if settings.debug_notify then
		record_sample(t, speed, state_name, is_crouching, current_action_name, used_input, stamina_fraction)
	end

	if not can_run and controller.phase ~= PHASE_IDLE then
		abort_cycle(t, "guard_failed")
		return
	end

	if not can_run then
		return
	end

	-- Running out of stamina mid-cycle produces a glitchy outcome (observed live: the windup
	-- gets cut off and the release resolves as a light instead of a heavy). Bail out early
	-- rather than attempt the maneuver on empty/near-empty stamina.
	if stamina_fraction <= (settings.min_stamina_fraction or 0.15) then
		if controller.phase ~= PHASE_IDLE then
			abort_cycle(t, "low_stamina")
		end

		return
	end

	local phase = controller.phase

	if phase == PHASE_IDLE then
		if t < controller.cooldown_until_t then
			return
		end

		-- Requiring the *actual* character state (not just the sprint input) matters here: the
		-- input stays held the whole time, so without this a fast cycle (light especially,
		-- ~0.4s end to end) restarts the windup while still sliding/walking off the previous
		-- cycle, at that state's low settling speed (~4.2) -- the player never gets back to a
		-- real sprint to rebuild speed before the next attack fires. Confirmed live: average
		-- speed stuck around 4.2 instead of cycling sprint-up -> peak -> slide -> repeat.
		if state_name ~= "sprinting" then
			return
		end

		if not sprint_requested() then
			return
		end

		if cached_input.move_forward ~= nil and cached_input.move_forward <= 0 then
			return
		end

		set_phase(PHASE_CHARGING, t)
		return
	end

	if phase == PHASE_CHARGING then
		-- The windup may be refused by the weapon's own action_condition_func (m2's 0.5s sweep
		-- cooldown) -- if nothing starts within a generous window, bail instead of holding
		-- action_one_hold forever.
		if t - controller.phase_entered_t > 0.8 then
			abort_cycle(t, "windup_never_started")
			return
		end

		if current_action_name and current_action_name ~= "action_wield" and action_start_t then
			local release_time

			if settings.technique == TECHNIQUE_LIGHT then
				-- The windup's own light_attack chain is chain_time = 0 -- any release counts,
				-- so just wait long enough for start_attack/the windup itself to register.
				release_time = LIGHT_RELEASE_TIME
			elseif settings.use_fixed_charge_time then
				-- Manual override for experimenting with a shorter charge. Releasing before the
				-- weapon's own windup->heavy chain_time (0.375-0.5s, an engine-level floor this
				-- mod doesn't control) still registers as a valid heavy_attack *input* (its own
				-- duration=0.3 floor only) and gets buffered (buffer_time=0.5): the windup just
				-- keeps running and the buffered input fires automatically once real elapsed time
				-- crosses the real chain_time. So a value below the floor costs nothing and gains
				-- nothing -- same eventual heavy, just deferred -- PHASE_RELEASING below has to
				-- wait long enough to see that happen instead of giving up early.
				release_time = settings.fixed_charge_time or 0.3
			else
				local weapon_template = current_weapon_template()
				release_time = confirm_release_time(weapon_template, current_action_name)
			end

			if t - action_start_t >= release_time then
				set_phase(PHASE_RELEASING, t)
			end
		end

		return
	end

	if phase == PHASE_RELEASING then
		local reached_target
		if settings.technique == TECHNIQUE_LIGHT then
			reached_target = current_action_name and string.find(current_action_name, "_light", 1, true) ~= nil
		else
			reached_target = HEAVY_ACTIONS[current_action_name] == true
		end

		if reached_target then
			controller.heavy_start_t = action_start_t or t
			controller.prev_speed = speed
			set_phase(PHASE_TRACKING, t)
		elseif t - controller.phase_entered_t > 0.65 then
			-- An early release (use_fixed_charge_time below the weapon's real chain_time) still
			-- resolves eventually -- the input gets buffered and fires once real elapsed time in
			-- the still-running windup crosses its chain_time (0.375-0.5s depending on which
			-- windup is active). 0.65s covers the slowest of those plus margin; past that, give up
			-- rather than sit here (e.g. chained into the wrong attack type, or the windup's own
			-- action_condition_func refused the buffered input outright).
			abort_cycle(t, "no_target_action")
		end

		return
	end

	if phase == PHASE_TRACKING then
		local elapsed = t - (controller.heavy_start_t or t)

		-- Manual override for experimenting with the slide timing directly: skip peak/threshold
		-- detection entirely and just slide once `fixed_slide_delay` seconds have elapsed since
		-- the attack (heavy/light) started.
		if settings.use_fixed_slide_delay and elapsed < (settings.fixed_slide_delay or 0.1) then
			controller.prev_speed = speed
			return
		end

		local peaked = settings.use_fixed_slide_delay or speed <= controller.prev_speed - (settings.peak_tolerance or 0)
		local waited_enough = settings.use_fixed_slide_delay or elapsed >= (settings.slide_max_wait or 0.35)

		if speed > (settings.slide_speed_threshold or 4.3) and (peaked or waited_enough) then
			-- The windup/heavy/light actions are allowed_during_sprint = true, so the engine does
			-- not kick the player out of "sprinting" on its own. heavy forces the sprint input
			-- false to open the walking-state slide door by hand (see PHASE_EXIT_SPRINT); light
			-- slides straight out of "sprinting" instead -- confirmed live to preserve the boost
			-- about as well, with less input juggling (see the file header for why).
			if settings.technique == TECHNIQUE_HEAVY and settings.require_walking_state and state_name == "sprinting" then
				set_phase(PHASE_EXIT_SPRINT, t)
			else
				controller.crouch_pulse_sent = false
				set_phase(PHASE_SLIDING, t)
			end
		elseif elapsed > 0.6 then
			abort_cycle(t, "below_threshold")
		end

		controller.prev_speed = speed
		return
	end

	if phase == PHASE_EXIT_SPRINT then
		-- heavy technique only (see PHASE_TRACKING above) -- light goes straight from tracking
		-- to sliding and never reaches this phase.
		local walking_window_open = state_name == "walking"
			and walking_state
			and walking_state.previous_state_allowed_slide
			and character_state
			and (t - (character_state.entered_t or 0)) < 0.5

		if walking_window_open then
			controller.crouch_pulse_sent = false
			set_phase(PHASE_SLIDING, t)
		elseif t - controller.phase_entered_t > 0.2 then
			abort_cycle(t, "no_walking_window")
		end

		return
	end

	if phase == PHASE_SLIDING then
		if state_name == "sliding" then
			set_phase(PHASE_GLIDING, t)
		elseif t - controller.phase_entered_t > 0.3 then
			abort_cycle(t, "slide_not_entered")
		end

		return
	end

	if phase == PHASE_GLIDING then
		if state_name ~= "sliding" then
			abort_cycle(t, "slide_ended")
			return
		end

		local glide_elapsed = t - controller.phase_entered_t

		-- Hold the slide for at least min_glide_time regardless of the speed reading -- without
		-- this the very first gliding sample can already read below glide_release_speed and the
		-- whole slide ends within one fixed frame (confirmed live: ~70ms, imperceptible).
		if glide_elapsed < (settings.min_glide_time or 0.2) then
			return
		end

		if speed < (settings.glide_release_speed or 4.4) or glide_elapsed > (settings.glide_max_time or 2.0) then
			if settings.debug_notify then
				mod:notify(string.format("SprintRapierHeavy: cycle ok, peak carried into slide (speed %.2f)", speed))
			end

			if settings.chain_during_glide then
				-- Experimental: start charging the next attack right at the tail of this slide
				-- instead of going back through idle (which now requires a real "sprinting"
				-- state first -- see the idle gate above). Unlike that earlier bug, this is
				-- deliberately timed at the END of the glide, not its start.
				last_event = "chained"
				controller.crouch_pulse_sent = false
				set_phase(PHASE_CHARGING, t)
				return
			end

			abort_cycle(t, "glide_done")
		end

		return
	end
end

-- During exit_sprint (heavy technique only) we force the sprint inputs false so the sprinting
-- state's own _check_transition sees wants_sprint == false and falls through to its "return
-- walking" branch (which does not reset velocity_wanted, unlike the direct sprinting -> sliding
-- path).
local function should_force_sprint(action_name)
	if controller.phase ~= PHASE_EXIT_SPRINT or settings.technique ~= TECHNIQUE_HEAVY then
		return nil
	end

	if action_name == "sprint" or action_name == "sprinting" then
		return false
	end

	return nil
end

local function should_force_action_one_hold()
	if controller.phase == PHASE_CHARGING then
		return true
	elseif controller.phase == PHASE_RELEASING then
		return false
	end

	return nil
end

-- crouch = one-frame "pressed" (toggle mode); crouching = held. During the slide entry we pulse
-- crouch once (for toggle-crouch players) and hold crouching true throughout (for hold-crouch
-- players, and because the engine itself switches to reading "crouching" once the slide's
-- commit period is over -- see the plan). Both are harmless to send to a player who is already
-- holding/toggled crouch themselves.
local function should_force_crouch(action_name)
	if controller.phase == PHASE_SLIDING then
		if action_name == "crouching" then
			return true
		elseif action_name == "crouch" and not controller.crouch_pulse_sent then
			controller.crouch_pulse_sent = true
			return true
		end
	elseif controller.phase == PHASE_GLIDING and action_name == "crouching" then
		return true
	end

	return nil
end

local function input_hook(func, self, action_name)
	local raw_value = INTERCEPTED_INPUTS[action_name] and raw_input_value(self, action_name) or nil
	local value = func(self, action_name)

	if self.type ~= "Ingame" or not INTERCEPTED_INPUTS[action_name] then
		return value
	end

	cache_input(action_name, value)

	if action_name == "action_one_hold" then
		local external_primary_hold = value and not raw_value

		if external_primary_hold then
			-- Another input mod is effectively holding primary for us, so keep
			-- yielding until that injected hold actually ends.
			set_external_hold_override(true)
			trigger_manual_override()
			return value
		elseif not value and not raw_value then
			set_external_hold_override(false)
		end
	end

	-- The player's own manual input always wins over the cycle: abort and fall back to 799's
	-- original 0.20s "stay out of the way" window.
	if raw_value and (action_name == "action_one_hold" or action_name == "action_one_pressed") and controller.phase == PHASE_IDLE then
		trigger_manual_override()
		return value
	end

	if (action_name == "action_two_hold"
		or action_name == "weapon_extra_pressed"
		or action_name == "weapon_extra_hold"
		or action_name == "weapon_reload_hold"
		or action_name == "quick_wield")
		and value then
		trigger_manual_override()
		if controller.phase ~= PHASE_IDLE then
			abort_cycle(gameplay_time(), "manual_input")
		end

		return value
	end

	if action_name == "action_one_hold" then
		local forced = should_force_action_one_hold()
		if forced ~= nil then
			return forced
		end
	end

	if action_name == "sprint" or action_name == "sprinting" then
		local forced = should_force_sprint(action_name)
		if forced ~= nil then
			return forced
		end
	end

	if action_name == "crouch" or action_name == "crouching" then
		local forced = should_force_crouch(action_name)
		if forced ~= nil then
			return forced
		end
	end

	return value
end

mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "on_slot_wielded", function(self)
	local player = local_player()
	if player and self._player == player then
		player_weapon_extension = self
		reset_controller()
	end
end)

mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "fixed_update", function(self, unit)
	local player_unit = local_player_unit()
	if player_unit and unit == player_unit then
		player_weapon_extension = self
		update_phase_machine(unit, gameplay_time())
	end
end)

mod:hook(CLASS.InputService, "_get", input_hook)
mod:hook(CLASS.InputService, "_get_simulate", input_hook)
mod:hook("SkitariusOmnissiah", "omnissiah", function(func, self, queried_input, user_value)
	local outcome = func(self, queried_input, user_value)
	local bind_manager = self.bind_manager
	local engram = self.engram
	local skitarius_melee_override = bind_manager
	and bind_manager.override_primary
	and bind_manager:override_primary()
	and engram
	and engram.TYPE == "MELEE"
	and engram:current_command() ~= nil

	if queried_input == "action_one_hold" or queried_input == "action_one_pressed" then
		if skitarius_melee_override and outcome then
			-- Yield for the full duration of a Skitarius-driven melee hold so this
			-- mod does not wake back up mid-sequence and steal the combo.
			set_external_hold_override(true)
			trigger_manual_override()
		elseif queried_input == "action_one_hold" and not outcome then
			set_external_hold_override(false)
		end
	end

	return outcome
end)

function mod.toggle_mod_enabled()
	setting_enabled = not refresh_enabled_setting()
	mod:set("enable_mod", setting_enabled)

	if not setting_enabled then
		reset_controller()
	end

	mod:notify(string.format("SprintRapierHeavy: %s", setting_enabled and "Enabled" or "Disabled"))
end

function mod.dump_trace()
	local ordered = {}
	for i = trace.next_index, TRACE_CAPACITY do
		if trace.samples[i] then
			ordered[#ordered + 1] = trace.samples[i]
		end
	end
	for i = 1, trace.next_index - 1 do
		if trace.samples[i] then
			ordered[#ordered + 1] = trace.samples[i]
		end
	end

	mod:dtf(ordered, "sprh_trace", 3)
	mod:notify(string.format("SprintRapierHeavy: dumped %d trace samples", #ordered))
end

mod.on_setting_changed = function(setting_id)
	if setting_id == "enable_mod" then
		refresh_enabled_setting()

		if not setting_enabled then
			reset_controller()
		end
	else
		refresh_settings()
	end
end

mod.on_disabled = function()
	player_weapon_extension = nil
	refresh_enabled_setting()
	reset_controller()
end

refresh_enabled_setting()
refresh_settings()
