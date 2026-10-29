-- Auto-presses the Rapier's (Duelling Sword, combatsword_p3 family) weapon special when a nearby
-- minion begins a melee attack, so the attack is parried (action_parry_special) and the free
-- riposte (action_attack_special_riposte) fires on its own via the weapon template's own
-- running_action_state_to_action_input = { has_blocked = { input_name = "parry" } } chain.
--
-- The parry itself needs no precise timing: action_parry_special has total_time = 1 and no
-- stop_input, so one press buys a full second of parry coverage that self-terminates. Enemy melee
-- damage lands roughly 0.6-1.3s after the windup animation starts (BreedActions
-- attack_anim_damage_timings), and the client cannot pin that down exactly (see below) -- but a
-- 1s window started shortly after the windup is seen covers nearly that whole spread, so the
-- imprecision doesn't matter in practice.
--
-- Threat detection has two feeds, used depending on who is the host:
--   - rpc_minion_anim_event (AnimationSystem) -- the only signal available on a non-host client,
--     i.e. every real mission. The server broadcasts it at windup frame 0. The payload is an
--     animation *index*, not a name, and carries no action/timing info -- any minion animation
--     event from a qualifying enemy counts as a possible windup here.
--   - BtMeleeAttackAction.enter -- fires only on a host (Psykhanium/Meat Grinder), where the
--     behavior tree itself runs locally. Used so this mod has a repeatable test environment; the
--     rpc feed above is silent on a host because AnimationSystem only registers the client RPCs
--     `if not self._is_server`.
--
-- Triggering uses PlayerUnitActionInputExtension:bot_queue_action_input, the same seam the game's
-- own bots use to block/push (bt_bot_melee_action.lua) -- it feeds the real action-input queue
-- (hierarchy-correct, network-predicted), unlike forcing InputService values (which is what
-- SprintRapierHeavy does for its own sprint/attack/slide sequence, and which would make the two
-- mods fight: SprintRapierHeavy treats a real weapon_extra_pressed as manual player intervention
-- and aborts its own cycle).
local mod = get_mod("auto_parry")

local Breed = require("scripts/utilities/breed")

local HEALTH_ALIVE = HEALTH_ALIVE
local POSITION_LOOKUP = POSITION_LOOKUP
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

local controller = {
	pending_press_t = nil,
	cooldown_until_t = 0,
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
	settings.press_delay = mod:get("press_delay") or 0
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
	local player_unit = local_player_unit()
	local action_input_extension = player_unit and ScriptUnit.has_extension(player_unit, "action_input_system")
	if not action_input_extension then
		return
	end

	action_input_extension:bot_queue_action_input("weapon_action", SPECIAL_ACTION_INPUT)
	controller.cooldown_until_t = t + (settings.cooldown or 0.5)
	controller.pending_press_t = nil

	if settings.debug_notify then
		record_sample(t, "pressed")
	end
end

-- Cheap gates shared by both detection feeds; evaluated on the (rare) event itself, not every
-- fixed frame.
local function evaluate_threat(attacker_unit)
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
	local player_pos = player_unit and POSITION_LOOKUP[player_unit]
	local attacker_pos = POSITION_LOOKUP[attacker_unit]
	if not player_pos or not attacker_pos then
		return
	end

	local distance = Vector3_distance(player_pos, attacker_pos)
	if distance > (settings.trigger_range or 3.0) then
		return
	end

	local t = gameplay_time()
	if t < controller.cooldown_until_t then
		if settings.debug_notify then
			record_sample(t, "skip_cooldown", { breed = breed.name, distance = distance })
		end

		return
	end

	local player_uds = unit_data_extension(player_unit)
	local stamina = player_uds and player_uds:read_component("stamina")
	local stamina_fraction = stamina and stamina.current_fraction or 1
	if stamina_fraction <= (settings.min_stamina_fraction or 0.15) then
		if settings.debug_notify then
			record_sample(t, "skip_low_stamina", { breed = breed.name, distance = distance })
		end

		return
	end

	if not player_weapon_extension or not player_weapon_extension:action_input_is_currently_valid("weapon_action", SPECIAL_ACTION_INPUT, nil, t) then
		if settings.debug_notify then
			record_sample(t, "skip_invalid_action_input", { breed = breed.name, distance = distance })
		end

		return
	end

	if settings.debug_notify then
		record_sample(t, "detected", { breed = breed.name, distance = distance })
	end

	local press_delay = settings.press_delay or 0
	if press_delay > 0 then
		controller.pending_press_t = t + press_delay
	else
		queue_parry_press(t)
	end
end

mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "on_slot_wielded", function(self)
	local player = local_player()
	if player and self._player == player then
		player_weapon_extension = self
	end
end)

-- Drives the delayed-press timer (press_delay > 0). Piggybacks on
-- PlayerUnitWeaponExtension.fixed_update, which already fires every fixed step for the local
-- player regardless of which action is running.
mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "fixed_update", function(self, unit)
	local player_unit = local_player_unit()
	if not (player_unit and unit == player_unit) then
		return
	end

	player_weapon_extension = self

	if controller.pending_press_t and gameplay_time() >= controller.pending_press_t then
		queue_parry_press(gameplay_time())
	end
end)

-- Non-host feed: the server broadcasts this the instant an enemy's attack animation starts
-- (bt_melee_attack_action.lua -> minion_animation_extension.lua:anim_event -> here). Silent on a
-- host -- AnimationSystem only registers the client RPCs `if not self._is_server`.
mod:hook_safe(CLASS.AnimationSystem, "rpc_minion_anim_event", function(self, channel_id, unit_id, event_index)
	local unit = Managers.state and Managers.state.unit_spawner and Managers.state.unit_spawner:unit(unit_id)
	if unit then
		evaluate_threat(unit)
	end
end)

-- Host feed: the behavior tree runs locally in Psykhanium/Meat Grinder, where the rpc above is
-- never sent. This is the mod's only repeatable test path.
mod:hook_safe(CLASS.BtMeleeAttackAction, "enter", function(self, unit)
	evaluate_threat(unit)
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
	refresh_enabled_setting()
end

refresh_enabled_setting()
refresh_settings()
