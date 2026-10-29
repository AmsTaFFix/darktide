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
-- Multi-hit combos (host feed only, e.g. cultist_berzerker's attack_move_combo_01_fast: 7 hits
-- spanning 0.67s-2.95s, BreedActions attack_anim_damage_timings as a list instead of one number):
-- the game only calls _start_attack_anim ONCE for the whole combo, so we only ever detect the
-- first hit -- there's no separate event per later hit to catch. Confirmed live: a berzerker's
-- first hit got parried every time, later hits in the same combo sometimes didn't, because they
-- landed after the first press's 1s window (+0.3s margin) had already closed. Fix: read
-- scratchpad.attack_timings/.attack_sweep_timings (the full offset list, already available at
-- _start_attack_anim time) and hold the window open until the LAST hit instead of the first --
-- see last_combo_hit_t(). We don't press again for each later hit; holding weapon_extra_pressed
-- true for the whole span lets special_action's own chain_time = 0.9 re-arm (valid from inside a
-- still-running parry, same mechanism as the hold-the-window fix above) catch each one on its own.
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
--
-- We hold weapon_extra_pressed = true for the whole scheduled window, not just one frame, and
-- don't pre-check action_input_is_currently_valid before doing so. special_action already buffers
-- for buffer_time = 0.2s and is re-evaluated against the real chain/validity rules every fixed
-- frame until it validates or the buffer expires (default_melee_action_input_setup.lua:139-147;
-- action_input_parser.lua:228-236, :696-707; action_handler.lua:673-695) -- re-supplying the press
-- each tick refreshes that buffer, which is exactly how a real player's mashed key gets picked up
-- the instant a chain_time boundary opens (e.g. 0.24s into a heavy, 0.4s into a windup/light on
-- this weapon). The first version of this mod checked validity once and dropped the attempt
-- outright if the player's own weapon was mid-action -- that one-shot check was the actual
-- bottleneck, not the engine; letting the engine's own buffer do the retry fixed it with no new
-- risk, confirmed live (see issue tracker for the session that found this).
--
-- "Animation cancel" (force-interrupting the player's own running action so a parry can start
-- immediately, researched and rejected): there is no priority-based preemption in this engine --
-- action_priority only ranks fresh-start candidates, never running ones
-- (action_handler.lua:910-934, :625-671) -- and no interruptible/cancellable flag is grantable to
-- special_action. The only designed mid-swing cancel is chain_until, and on this weapon it's
-- granted only to the block input on specific heavy sweeps (combatsword_p3_m1.lua:334-338,
-- :578-581), never to special_action. The sole bypass,
-- PlayerUnitWeaponExtension:start_action(name, t) / TRANSITION_TYPES.forced
-- (player_unit_weapon_extension.lua:858-866), does hard-cut the running action with clean on_exit
-- cleanup, but skips action_condition_func (bypassing the Psyker-vs-not guard), desyncs the input
-- queue hierarchy, and is NOT server-authoritative: ActionHandler.server_correction_occurred
-- (action_handler.lua:514-545) can snap the client back into the interrupted swing, and since
-- blocking is adjudicated server-side off the replicated weapon_action/block components
-- (block.lua:32-48, :75-77), a forced client-local parry can visually appear to block while the
-- server still lets the real hit through -- a worse outcome than not reacting at all. Not
-- implemented for that reason.
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

local SPECIAL_RAW_INPUT = "weapon_extra_pressed"

-- At most this many concurrent enemies get their own tracked threat. Holding weapon_extra_pressed
-- true is cost-free to repeat (see the file header), so there's no reason to multiplex a single
-- slot when several real attackers are live at once -- confirmed live in a 3-enemy Psykhanium
-- fight: with a single slot, one attacker went ~8s and several attacks unanswered while the other
-- two kept winning the "sooner" contest for it (skip_already_scheduled with no blocked_attack
-- following before that attacker's next detection). A handful of slots is enough for how crowded
-- melee range around one player actually gets; this isn't a setting because there's no real
-- tradeoff to tune -- more slots than concurrent real attackers is free, fewer just reintroduces
-- the starvation this exists to fix.
local MAX_PENDING_THREATS = 3

local controller = {
	-- Up to MAX_PENDING_THREATS entries, one per attacker, each
	-- { press_t, deadline_t, attacker_id, checked }. press_t/deadline_t as before (see
	-- evaluate_threat); checked is false until the one-time per-slot cooldown/stamina/weapon gate
	-- has run (at or after press_t) -- see update_threats.
	threats = {},
	-- [attacker_id] = gameplay-time until which a *new* threat from that same attacker won't open
	-- a fresh window -- per-attacker, not global, so one enemy's pace never throttles a different
	-- concurrent one. Set once a slot's gate passes (see update_threats).
	attacker_cooldown_until = {},
	-- True whenever any threat in `threats` is within its own [press_t, deadline_t] window: the
	-- InputService hook returns true for weapon_extra_pressed on every read while this is set,
	-- letting the engine's own special_action buffer (see the file header) retry the chain
	-- validation each fixed frame instead of us deciding pass/fail ourselves in one shot.
	force_active = false,
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

local function attacker_id(unit)
	local unit_spawner = Managers.state and Managers.state.unit_spawner
	return unit and unit_spawner and unit_spawner:game_object_id(unit)
end

-- For a multi-hit combo (bt_melee_attack_action.lua sets scratchpad.attack_timings, a plain list
-- of offsets from scratchpad.start_time, or scratchpad.attack_sweep_timings, a list of {start,
-- stop} pairs for a sweep combo), returns the absolute gameplay-time of the LAST hit. nil for a
-- single-hit attack (neither table present) or if start_time is missing.
local function last_combo_hit_t(scratchpad)
	local start_time = scratchpad.start_time
	if not start_time then
		return nil
	end

	local timings = scratchpad.attack_timings or scratchpad.attack_sweep_timings
	if not timings then
		return nil
	end

	local last = timings[#timings]
	local offset = type(last) == "table" and last[2] or last
	if type(offset) ~= "number" then
		return nil
	end

	return start_time + offset
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
		-- Diagnostic only, for correlating samples to one specific attacker across a dump (e.g.
		-- "does this enemy's very first attack ever show up here at all") -- not used by any
		-- gameplay logic.
		unit_id = extra and extra.unit_id,
	}

	trace.samples[trace.next_index] = sample
	trace.next_index = trace.next_index + 1
	if trace.next_index > TRACE_CAPACITY then
		trace.next_index = 1
	end
end

-- Drives every tracked threat independently: for each one, once t reaches its own press_t, runs
-- the checks that only matter right before actually opening its window (per-attacker cooldown,
-- stamina, weapon still out) exactly once -- deliberately NOT done at detection/scheduling time,
-- since a host-feed detection can be scheduled up to ~1s in the future and the player's state is
-- far more likely to have changed by then than to still match what it was at detection. A threat
-- that fails its gate is simply dropped (a genuine miss, not retried) -- it already won its slot
-- in evaluate_threat, same as before.
--
-- Deliberately does NOT check action_input_is_currently_valid here -- see the file header for
-- why: holding weapon_extra_pressed true for the window lets the engine's own special_action
-- buffer retry that exact check every fixed frame on its own, which is strictly more capable than
-- a single check made here ever could be. force_active ends up true whenever ANY threat is
-- currently within its own window -- holding the raw input true is cost-free to repeat, so
-- multiple simultaneously-active windows need no special handling beyond "at least one wants it".
local function update_threats(t)
	local threats = controller.threats
	local any_active = false
	local i = 1

	while i <= #threats do
		local threat = threats[i]
		local drop = false

		if not threat.checked and t >= threat.press_t then
			threat.checked = true

			local cooldown_until = controller.attacker_cooldown_until[threat.attacker_id]
			if cooldown_until and t < cooldown_until then
				if settings.debug_notify then
					record_sample(t, "skip_cooldown_at_press", { unit_id = threat.attacker_id })
				end

				drop = true
			elseif not is_rapier() then
				drop = true
			else
				local player_unit = local_player_unit()
				local player_uds = unit_data_extension(player_unit)
				local stamina = player_uds and player_uds:read_component("stamina")
				local stamina_fraction = stamina and stamina.current_fraction or 1
				if stamina_fraction <= (settings.min_stamina_fraction or 0.15) then
					if settings.debug_notify then
						record_sample(t, "skip_low_stamina_at_press", { unit_id = threat.attacker_id })
					end

					drop = true
				else
					controller.attacker_cooldown_until[threat.attacker_id] = t + (settings.cooldown or 0.5)

					if settings.debug_notify then
						-- Marks this threat's window opening, not proof it landed -- the
						-- blocked_attack sample is the proof.
						record_sample(t, "pressed", { unit_id = threat.attacker_id })
					end
				end
			end
		end

		if not drop and threat.checked and t > threat.deadline_t then
			drop = true
		end

		if drop then
			table.remove(threats, i)
		else
			if threat.checked and t <= threat.deadline_t then
				any_active = true
			end

			i = i + 1
		end
	end

	controller.force_active = any_active
end

-- Cheap gates shared by both detection feeds; evaluated on the (rare) event itself, not every
-- fixed frame.
--
-- known_target_unit: the attacker's real target, when we actually know it (host feed, passed in
-- straight from _start_attack_anim's own parameter) -- nil when we don't (non-host rpc feed).
-- damage_t: the real gameplay-time timestamp of the (first) hit (host feed) or nil (non-host
-- feed, where we fall back to a flat settings.press_delay after detection instead).
-- last_hit_t: for a multi-hit combo, the real gameplay-time timestamp of its LAST hit (host feed
-- only, nil otherwise or when the attack isn't a combo) -- see the file header for why this
-- stretches the window instead of needing a detection per hit.
local function evaluate_threat(attacker_unit, known_target_unit, damage_t, last_hit_t)
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
	local unit_id = attacker_id(attacker_unit)

	-- Host feed only (known_target_unit ~= nil): drop attacks aimed at someone/something else.
	-- Without this, BtMeleeAttackAction's feed fires for ANY nearby minion's attack, spending a
	-- press and its cooldown on a non-threat right as a real one might be starting.
	if known_target_unit ~= nil and known_target_unit ~= player_unit then
		if settings.debug_notify then
			record_sample(gameplay_time(), "skip_wrong_target", { breed = breed.name, unit_id = unit_id })
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

	-- Host feed only (known_target_unit ~= nil): don't gate on current distance. A charging/
	-- moving attack's windup can start well outside trigger_range and still land, because the
	-- attacker closes the gap while it winds up -- we already know (from known_target_unit, just
	-- above) that it's actually coming for us, and we schedule the press against the real hit
	-- time regardless of where the attacker is right now, so distance-at-windup-start isn't a
	-- useful filter here. Confirmed live: this was silently dropping some charging first strikes
	-- (no "detected" sample at all) while a stationary attack from the same distance would pass.
	-- The non-host feed has no target confirmation, so distance stays its only filter there.
	if known_target_unit == nil and distance > (settings.trigger_range or 3.0) then
		return
	end

	local t = gameplay_time()

	if settings.debug_notify then
		record_sample(t, "detected", { breed = breed.name, distance = distance, unit_id = unit_id })
	end

	local press_t, deadline_t
	if damage_t then
		press_t = damage_t - (settings.pre_hit_margin or 0.2)
		if press_t < t then
			-- The hit is imminent or the margin overshoots what's left of the windup -- press
			-- now rather than schedule into the past (which update_threats would fire
			-- immediately on the very next fixed frame anyway).
			press_t = t
		end

		-- Hold the window open past the real hit (or, for a multi-hit combo, past its LAST hit --
		-- see last_hit_t/the file header) by a safety margin rather than closing it exactly at the
		-- hit itself -- the engine's own buffer/chain-time timing decides the real moment within
		-- the window, not us. For a multi-hit combo this is what covers hits after the first: we
		-- never re-detect each one (the game doesn't call _start_attack_anim again mid-combo), but
		-- holding weapon_extra_pressed true for the combo's whole span lets the weapon's own
		-- special_action -> action_parry_special chain (chain_time = 0.9, re-triggerable from
		-- inside a still-running parry) re-arm itself in time for each later hit on its own.
		deadline_t = (last_hit_t or damage_t) + 0.3
	else
		press_t = t + (settings.press_delay or 0)
		-- No real damage_t on the non-host feed -- bound the window with a flat cap instead.
		deadline_t = press_t + 0.3
	end

	-- A fresh detection for an attacker that already has a tracked threat replaces it outright --
	-- this is a new attack, the old scheduling is stale.
	local threats = controller.threats
	for index, threat in ipairs(threats) do
		if threat.attacker_id == unit_id then
			threats[index] = { press_t = press_t, deadline_t = deadline_t, attacker_id = unit_id, checked = false }
			return
		end
	end

	if #threats < MAX_PENDING_THREATS then
		threats[#threats + 1] = { press_t = press_t, deadline_t = deadline_t, attacker_id = unit_id, checked = false }
		return
	end

	-- All slots are full with other attackers -- bump whichever currently tracked threat is the
	-- LEAST urgent (latest press_t) if this new one is more urgent than it, so the slots always
	-- hold the soonest known threats rather than whichever happened to arrive first.
	local latest_index, latest_press_t = nil, -math.huge
	for index, threat in ipairs(threats) do
		if threat.press_t > latest_press_t then
			latest_index, latest_press_t = index, threat.press_t
		end
	end

	if latest_index and press_t < latest_press_t then
		threats[latest_index] = { press_t = press_t, deadline_t = deadline_t, attacker_id = unit_id, checked = false }
		return
	end

	if settings.debug_notify then
		record_sample(t, "skip_already_scheduled", { breed = breed.name, distance = distance, unit_id = unit_id })
	end
end

mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "on_slot_wielded", function(self)
	local player = local_player()
	if player and self._player == player then
		player_weapon_extension = self
	end
end)

-- Drives all tracked threats. Piggybacks on PlayerUnitWeaponExtension.fixed_update, which already
-- fires every fixed step for the local player regardless of which action is running.
mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "fixed_update", function(self, unit)
	local player_unit = local_player_unit()
	if not (player_unit and unit == player_unit) then
		return
	end

	player_weapon_extension = self

	update_threats(gameplay_time())
end)

-- Forces weapon_extra_pressed true for every read while a window is open (controller.force_active
-- -- see the file header for why this is a sustained window, not a one-shot). Mirrors
-- SprintRapierHeavy's own InputService._get/_get_simulate hook shape.
local function input_hook(func, self, action_name)
	local value = func(self, action_name)

	if self.type ~= "Ingame" or action_name ~= SPECIAL_RAW_INPUT then
		return value
	end

	if controller.force_active then
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

	evaluate_threat(unit, target_unit, damage_t, last_combo_hit_t(scratchpad))
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
			unit_id = attacker_id(attacking_unit),
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
	controller.threats = {}
	controller.attacker_cooldown_until = {}
	controller.force_active = false
	refresh_enabled_setting()
end

refresh_enabled_setting()
refresh_settings()
