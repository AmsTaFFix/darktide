local mod = get_mod("psych_ward")

-- psych_ward opens Hub-only views (Inventory, Crafting, Talents, ...) from Character
-- Select, where Managers.connection never has a session (no _connection_host/_connection_client).
-- Every backend write the game makes for an equip/craft/talent change propagates into the
-- local player's cached profile() only through that connection (items.lua's
-- equip_slot_items/equip_slot_master_items/unequip_slots/refresh_equipped_items, and
-- talents_service.lua's set_talents_v2 all gate their resync on
-- Managers.connection:is_host()/:is_client()). Outside a session that gate is always false,
-- so the write silently never reaches player:profile().loadout/talents until the player
-- happens to toggle gear again from inside an actual session (Hub/mission), which is what
-- the reported "have to swap loadouts back and forth to make it stick" workaround is.
-- Patch the gap directly: when there is no live connection, pull the fresh profile from the
-- backend ourselves and push it onto the local player.

local Items = require("scripts/utilities/items")
local TalentsService = require("scripts/managers/data_service/services/talents_service")

local function _has_live_connection()
  local connection = Managers.connection

  return connection ~= nil and (connection:is_host() or connection:is_client())
end

local function _resync_local_player_profile()
  local player = Managers.player:local_player(1)
  local character_id = player and not player.__deleted and player:character_id()

  if not character_id then
    return
  end

  Managers.data_service.gear:invalidate_gear_cache()

  Managers.data_service.profiles:fetch_profile(character_id):next(function(profile)
    if player and not player.__deleted then
      player:set_profile(profile)
    end
  end):catch(function(error)
    mod:error("Failed to resync local profile after a Character Select equip/craft change: %s", tostring(error))
  end)
end

local function _resync_after(promise)
  if promise then
    promise:next(_resync_local_player_profile)
  end
end

mod:hook(Items, "refresh_equipped_items", function(func, ...)
  func(...)

  if not _has_live_connection() then
    _resync_local_player_profile()
  end
end)

mod:hook(Items, "equip_slot_items", function(func, items)
  local promise = func(items)

  if not _has_live_connection() then
    _resync_after(promise)
  end

  return promise
end)

mod:hook(Items, "equip_slot_master_items", function(func, items)
  local promise = func(items)

  if not _has_live_connection() then
    _resync_after(promise)
  end

  return promise
end)

mod:hook(Items, "unequip_slots", function(func, unequip_slots)
  local promise = func(unequip_slots)

  if not _has_live_connection() then
    _resync_after(promise)
  end

  return promise
end)

mod:hook(TalentsService, "set_talents_v2", function(func, self, player, talent_info, specialization_talent_info)
  local promise = func(self, player, talent_info, specialization_talent_info)

  if not _has_live_connection() then
    _resync_after(promise)
  end

  return promise
end)
