-- Auto-presses the Dueling Sword's (combatsword_p3 family) weapon special when a nearby
-- minion begins a melee attack, so the attack is parried (action_parry_special) and the free
-- riposte (action_attack_special_riposte) fires on its own via the weapon template's own
-- running_action_state_to_action_input = { has_blocked = { input_name = "parry" } } chain.
--
-- The parry itself doesn't need frame-perfect timing, but it isn't free either:
-- action_parry_special has total_time = 1 and no stop_input, so one press buys exactly one second
-- of coverage that self-terminates. Enemy melee damage can land anywhere from ~0.6s to well over
-- 1s after the windup animation starts (BreedActions attack_anim_damage_timings, e.g.
-- attack_down_01 = 1.333s for renegades) -- pressing the instant a windup is seen (the first
-- version of this mod) sometimes let the 1s window close before a slow attack's real hit,
-- confirmed live as "raises the sword, lowers it, then the real swing lands anyway".
--
-- Threat detection has two feeds, used depending on who is the host:
--   - BtMeleeAttackAction._start_attack_anim -- fires only on a host (Psykhanium/Meat Grinder),
--     where the behavior tree runs locally. This is the precise feed: _start_attack_anim is
--     called synchronously from .enter() and, before it returns, has already picked the attack
--     variant and computed scratchpad.attack_timing (or .start_sweep_t for a sweep kind) -- the
--     absolute gameplay-time timestamp of the real hit. We schedule our press at
--     damage_t - pre_hit_margin instead of pressing immediately, so the 1s window actually covers
--     the hit regardless of how long the windup is. The function also hands us the real
--     target_unit as a parameter, so we can filter out attacks aimed at someone else entirely
--     (another thing .enter()-only detection couldn't do: it fires for ANY nearby minion's
--     attack, not just ones aimed at the local player).
--   - rpc_minion_anim_event (AnimationSystem) -- the only signal available on a non-host client,
--     i.e. every real mission. The server broadcasts it at windup frame 0, but the payload is an
--     animation *index* with no name or timing attached, and there is no name->index reverse
--     lookup exposed to Lua (Unit.animation_event(unit, name) itself *plays* the named event, so
--     it can't be used as a probe) -- so this feed can't tell us damage_t or the real target.
--     Best effort: press after a flat press_delay, like before, and keep filtering by distance
--     only.
--
-- Triggering forces InputService's weapon_extra_pressed for one read, the same mechanism
-- SprintRapierHeavy uses for its own sequence. bot_queue_action_input (what the game's own bots
-- use to block/push) was tried first and does NOT work here: ActionInputParser only drains its
-- bot queue when `self._player:is_human_controlled()` is false (action_input_parser.lua, the
-- `else` branch that calls _update_bot_action_input_requests) -- for a real human-controlled
-- player, queued bot requests are never consumed and the 5-slot ring buffer overflows (confirmed
-- live). Forcing the real input is the only seam that works for the local player.
--
-- This can collide with SprintRapierHeavy, which also hooks InputService and treats a real
-- weapon_extra_pressed as manual player intervention, aborting its own sprint-attack-slide cycle
-- when it sees one. That is accepted, not fought: a parry interrupting the speed-tech cycle is the
-- right priority (defending beats speed-running), and SprintRapierHeavy doesn't itself drive
-- weapon_extra_pressed, so there's nothing to race -- only auto_parry writes it.
local mod = get_mod("auto_parry")

local Breed = require("scripts/utilities/breed")

-- HEALTH_ALIVE is created once in global_tables.lua and lives for the game's whole process, so
-- caching it as an upvalue at mod-load time is safe (same pattern SprintRapierHeavy uses).
-- POSITION_LOOKUP is NOT that kind of global: PositionLookupManager (re)creates it per mission via
-- rawset(_G, "POSITION_LOOKUP", ...) and nils it out on destroy, so it must be read fresh from _G
-- every time instead of cached -- caching it here previously meant a permanent nil, captured
-- before any mission had ever loaded a PositionLookupManager.
local HEALTH_ALIVE = HEALTH_ALIVE
local Managers = Managers
local ScriptUnit = ScriptUnit
local Unit = Unit
local Vector3_distance = Vector3.distance

local RAPIER_WEAPONS = {
	combatsword_p3_m1 = true,
	combatsword_p3_m2 = true,
	combatsword_p3_m3 = true,
}

local SPECIAL_ACTION_INPUT = "special_action"
local SPECIAL_RAW_INPUT = "weapon_extra_pressed"

local controller = {
	-- Gameplay-time timestamp of the next scheduled press, or nil if none is pending. Set by
	-- evaluate_threat (one at a time -- a second detection while one is already pending is
	-- dropped, see skip_already_scheduled), consumed and cleared by try_fire_scheduled_press.
	pending_press_t = nil,
	cooldown_until_t = 0,
	-- One-shot: the InputService hook reads this, returns true for weapon_extra_pressed exactly
	-- once, and clears it. No queue, nothing to overflow.
	force_special_press = false,
}

local player_weapon_extension = nil
local setting_enabled = true
local settings = {}

-- Set on every reject/press, recorded into the next trace sample so a dump shows exactly why
-- without needing to catch a toast.
local last_event = ""

-- Ring buffer of recent detection/press/outcome samples, dumped on demand via dump_trace_keybind.
local TRACE_CAPACITY = 300
local trace = { samples = {}, next_index = 1 }

local function refresh_enabled_setting()
	local stored_value = mod:get("enable_mod")
	setting_enabled = stored_value == nil and true or stored_value
	return setting_enabled
end

local function refresh_settings()
	settings.trigger_range = mod:get("trigger_range") or 3.0
	settings.pre_hit_margin = mod:get("pre_hit_margin") or 0.2
	settings.press_delay = mod:get("press_delay") or 0.3
	settings.min_stamina_fraction = mod:get("min_stamina_fraction") or 0.15
	settings.cooldown = mod:get("cooldown") or 0.5
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

local function record_sample(t, event, extra)
	last_event = event or last_event

	local sample = {
		t = t,
		event = event,
		breed = extra and extra.breed,
		distance = extra and extra.distance,
		block_broken = extra and extra.block_broken,
		is_perfect_block = extra and extra.is_perfect_block,
	}

	trace.samples[trace.next_index] = sample
	trace.next_index = trace.next_index + 1
	if trace.next_index > TRACE_CAPACITY then
		trace.next_index = 1
	end
end

local function queue_parry_press(t)
	controller.force_special_press = true
	controller.cooldown_until_t = t + (settings.cooldown or 0.5)

	if settings.debug_notify then
		record_sample(t, "pressed")
	end
end

-- Runs the checks that only matter right before actually pressing (our own press cooldown,
-- stamina, weapon still out, whether special_action would even be accepted right now) --
-- deliberately NOT done at detection/scheduling time, since a host-feed detection can be
-- scheduled up to ~1s in the future and the player's state (and whether an earlier press's
-- cooldown has cleared yet) is far more likely to have changed by then than to still match what
-- it was at detection. Rejecting a scheduled press here does NOT un-schedule the threat it came
-- from -- a real attack that got this far already won the "which threat gets the one pending
-- slot" contest in evaluate_threat, so if it still can't be pressed (e.g. cooldown hasn't
-- cleared), that's a genuine miss, not something to retry.
local function try_fire_scheduled_press(t)
	local press_t = controller.pending_press_t
	if not press_t or t < press_t then
		return
	end

	controller.pending_press_t = nil

	if t < controller.cooldown_until_t then
		if settings.debug_notify then
			record_sample(t, "skip_cooldown_at_press")
		end

		return
	end

	if not is_rapier() then
		return
	end

	local player_unit = local_player_unit()
	local player_uds = unit_data_extension(player_unit)
	local stamina = player_uds and player_uds:read_component("stamina")
	local stamina_fraction = stamina and stamina.current_fraction or 1
	if stamina_fraction <= (settings.min_stamina_fraction or 0.15) then
		if settings.debug_notify then
			record_sample(t, "skip_low_stamina_at_press")
		end

		return
	end

	if not player_weapon_extension or not player_weapon_extension:action_input_is_currently_valid("weapon_action", SPECIAL_ACTION_INPUT, nil, t) then
		if settings.debug_notify then
			record_sample(t, "skip_invalid_action_input_at_press")
		end

		return
	end

	queue_parry_press(t)
end

-- Cheap gates shared by both detection feeds; evaluated on the (rare) event itself, not every
-- fixed frame.
--
-- known_target_unit: the attacker's real target, when we actually know it (host feed, passed in
-- straight from _start_attack_anim's own parameter) -- nil when we don't (non-host rpc feed).
-- damage_t: the real gameplay-time timestamp of the hit (host feed) or nil (non-host feed, where
-- we fall back to a flat settings.press_delay after detection instead).
local function evaluate_threat(attacker_unit, known_target_unit, damage_t)
	if not (mod:is_enabled() and setting_enabled) then
		return
	end

	if ui_using_input() or in_hub() then
		return
	end

	if not is_rapier() then
		return
	end

	if not attacker_unit or not Unit.alive(attacker_unit) then
		return
	end

	local attacker_uds = unit_data_extension(attacker_unit)
	if not attacker_uds then
		return
	end

	local breed = attacker_uds:breed()
	-- Only react to non-player minions -- this mod never auto-parries a PvP-adjacent human
	-- target (there isn't one in this game, but the check mirrors Block.is_blocking's own
	-- "breed must be a player" gate inverted: we want the opposite, an actual enemy).
	if not breed or Breed.is_player(breed) then
		return
	end

	local player_unit = local_player_unit()

	-- Host feed only (known_target_unit ~= nil): drop attacks aimed at someone/something else.
	-- Without this, BtMeleeAttackAction's feed fires for ANY nearby minion's attack, spending a
	-- press and its cooldown on a non-threat right as a real one might be starting.
	if known_target_unit ~= nil and known_target_unit ~= player_unit then
		if settings.debug_notify then
			record_sample(gameplay_time(), "skip_wrong_target", { breed = breed.name })
		end

		return
	end

	local position_lookup = _G.POSITION_LOOKUP
	if not position_lookup then
		return
	end

	local player_pos = player_unit and position_lookup[player_unit]
	local attacker_pos = position_lookup[attacker_unit]
	if not player_pos or not attacker_pos then
		return
	end

	local distance = Vector3_distance(player_pos, attacker_pos)
	if distance > (settings.trigger_range or 3.0) then
		return
	end

	local t = gameplay_time()

	if settings.debug_notify then
		record_sample(t, "detected", { breed = breed.name, distance = distance })
	end

	local press_t
	if damage_t then
		press_t = damage_t - (settings.pre_hit_margin or 0.2)
		if press_t < t then
			-- The hit is imminent or the margin overshoots what's left of the windup -- press
			-- now rather than schedule into the past (which try_fire_scheduled_press would fire
			-- immediately on the very next fixed frame anyway).
			press_t = t
		end
	else
		press_t = t + (settings.press_delay or 0)
	end

	-- Only one press can be pending at a time (force_special_press is a single flag, not a
	-- queue), so a second detection while one is already scheduled doesn't get its own slot --
	-- but it must not simply be dropped either: pressing late is as much a miss as not pressing
	-- at all, so whichever threat's real hit comes first wins the slot.
	if controller.pending_press_t and controller.pending_press_t <= press_t then
		if settings.debug_notify then
			record_sample(t, "skip_already_scheduled", { breed = breed.name, distance = distance })
		end

		return
	end

	controller.pending_press_t = press_t
end

mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "on_slot_wielded", function(self)
	local player = local_player()
	if player and self._player == player then
		player_weapon_extension = self
	end
end)

-- Drives the scheduled-press timer. Piggybacks on PlayerUnitWeaponExtension.fixed_update, which
-- already fires every fixed step for the local player regardless of which action is running.
mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "fixed_update", function(self, unit)
	local player_unit = local_player_unit()
	if not (player_unit and unit == player_unit) then
		return
	end

	player_weapon_extension = self

	try_fire_scheduled_press(gameplay_time())
end)

-- One-shot force of weapon_extra_pressed -- the only raw input special_action's input_sequence
-- actually looks for (default_melee_action_input_setup.lua). Mirrors SprintRapierHeavy's own
-- InputService._get/_get_simulate hook shape.
local function input_hook(func, self, action_name)
	local value = func(self, action_name)

	if self.type ~= "Ingame" or action_name ~= SPECIAL_RAW_INPUT then
		return value
	end

	if controller.force_special_press then
		controller.force_special_press = false
		return true
	end

	return value
end

mod:hook(CLASS.InputService, "_get", input_hook)
mod:hook(CLASS.InputService, "_get_simulate", input_hook)

-- Non-host feed: the server broadcasts this the instant an enemy's attack animation starts
-- (bt_melee_attack_action.lua -> minion_animation_extension.lua:anim_event -> here). Silent on a
-- host -- AnimationSystem only registers the client RPCs `if not self._is_server`. No real target
-- or timing data available here -- see the file header.
mod:hook_safe(CLASS.AnimationSystem, "rpc_minion_anim_event", function(self, channel_id, unit_id, event_index)
	local unit = Managers.state and Managers.state.unit_spawner and Managers.state.unit_spawner:unit(unit_id)
	if unit then
		evaluate_threat(unit, nil, nil)
	end
end)

-- Host feed: the behavior tree runs locally in Psykhanium/Meat Grinder, where the rpc above is
-- never sent. This is the mod's only repeatable test path, and the precise one -- see the file
-- header for why _start_attack_anim (not .enter) is hooked.
mod:hook_safe(CLASS.BtMeleeAttackAction, "_start_attack_anim", function(self, unit, breed, target_unit, t, spawn_component, scratchpad, action_data)
	local damage_t = scratchpad.attack_timing or scratchpad.start_sweep_t
	if not damage_t then
		return
	end

	evaluate_threat(unit, target_unit, damage_t)
end)

-- Telemetry only -- fires for anyone's block, including a manual one, but we only tag samples
-- while debug_notify is on, and the dump is for tuning, not gameplay logic.
mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "blocked_attack", function(self, attacking_unit, hit_world_position, block_broken, weapon_template, attack_type, block_cost, is_perfect_block)
	local player = local_player()
	if not (player and self._player == player) then
		return
	end

	if settings.debug_notify then
		record_sample(gameplay_time(), "blocked_attack", {
			block_broken = block_broken,
			is_perfect_block = is_perfect_block,
		})
	end
end)

function mod.toggle_mod_enabled()
	setting_enabled = not refresh_enabled_setting()
	mod:set("enable_mod", setting_enabled)
	mod:notify(string.format("auto_parry: %s", setting_enabled and "Enabled" or "Disabled"))
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

	mod:dtf(ordered, "auto_parry_trace", 3)
	mod:notify(string.format("auto_parry: dumped %d trace samples", #ordered))
end

mod.on_setting_changed = function(setting_id)
	if setting_id == "enable_mod" then
		refresh_enabled_setting()
	else
		refresh_settings()
	end
end

mod.on_disabled = function()
	player_weapon_extension = nil
	controller.pending_press_t = nil
	controller.force_special_press = false
	refresh_enabled_setting()
end

refresh_enabled_setting()
refresh_settings()
