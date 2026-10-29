-- Derived from SprintKnifeHeavy by ImperialSkoom (Nexus mod 799, v1.0.5), retargeted at the
-- Rapier (Duelling Sword, combatsword_p3 family) instead of the Combat Knife.
local mod = get_mod("SprintRapierHeavy")

local HEALTH_ALIVE = HEALTH_ALIVE
local Managers = Managers
local ScriptUnit = ScriptUnit
local Unit = Unit

local RAPIER_WEAPONS = {
	combatsword_p3_m1 = true,
	combatsword_p3_m2 = true,
	combatsword_p3_m3 = true,
}

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
	move_forward = true,
}

local cached_input = {
	sprint = false,
	sprinting = false,
	hold_to_sprint = false,
	move_forward = nil,
}

local controller = {
	override_until_t = 0,
	external_hold_override = false,
}

local player_weapon_extension = nil
local setting_enabled = true

local function refresh_enabled_setting()
	local stored_value = mod:get("enable_mod")
	setting_enabled = stored_value == nil and true or stored_value
	return setting_enabled
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

local function reset_controller()
	controller.override_until_t = 0
	controller.external_hold_override = false
	cached_input.sprint = false
	cached_input.sprinting = false
	cached_input.hold_to_sprint = false
	cached_input.move_forward = nil
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
		local unit_data_extension = player_unit and ScriptUnit.has_extension(player_unit, "unit_data_system")
		local sprint_component = unit_data_extension and unit_data_extension:read_component("sprint_character_state")
		return sprint_component and sprint_component.is_sprinting or false
	end)

	return ok and result or false
end

local function sprint_requested()
	return cached_input.sprint or cached_input.hold_to_sprint or cached_input.sprinting or is_sprinting()
end

local function should_run()
	if not mod:is_enabled() then
		return false
	end

	if not setting_enabled then
		return false
	end

	if ui_using_input() or in_hub() then
		return false
	end

	if not is_rapier() then
		return false
	end

	if not sprint_requested() then
		return false
	end

	if manual_override_active() then
		return false
	end

	if controller.external_hold_override then
		return false
	end

	if cached_input.move_forward ~= nil and cached_input.move_forward <= 0 then
		return false
	end

	return true
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

	if action_name == "action_one_hold" and value then
		trigger_manual_override()
		return value
	end

	if action_name == "action_one_hold" and not value then
		set_external_hold_override(false)
	end

	if action_name == "action_one_pressed" and value then
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
		return value
	end

	if action_name == "action_one_hold" and should_run() then
		return true
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

mod.on_setting_changed = function(setting_id)
	if setting_id == "enable_mod" then
		refresh_enabled_setting()

		if not setting_enabled then
			reset_controller()
		end
	end
end

mod.on_disabled = function()
	player_weapon_extension = nil
	refresh_enabled_setting()
	reset_controller()
end

refresh_enabled_setting()
