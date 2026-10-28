local mod = get_mod("claude_bridge")

local HealthUtils = require("scripts/utilities/health")
local ToughnessUtils = require("scripts/utilities/toughness/toughness")

local M = {}

local function _safe(fn)
  local ok, result = pcall(fn)
  if ok then
    return result
  end

  return nil
end

-- Collects a small snapshot of game/player state as a plain table, for the "state" command.
-- Every field is wrapped individually so one missing manager (e.g. outside a mission) doesn't
-- blank out the rest of the snapshot.
function M.collect()
  local snapshot = {}

  snapshot.ui_state_name = _safe(function()
    return Managers.ui:get_current_state_name()
  end)

  snapshot.game_mode_name = _safe(function()
    return Managers.state.game_mode:game_mode_name()
  end)

  snapshot.mechanism_name = _safe(function()
    return Managers.mechanism:mechanism_name()
  end)

  snapshot.is_social_hub = _safe(function()
    return Managers.state.game_mode:is_social_hub()
  end)

  snapshot.is_prologue_hub = _safe(function()
    return Managers.state.game_mode:is_prologue_hub()
  end)

  local player = _safe(function()
    return Managers.player:local_player_safe(1)
  end)

  snapshot.has_local_player = player ~= nil

  if player then
    local alive = _safe(function()
      return player:unit_is_alive()
    end)

    snapshot.player_unit_alive = alive or false

    if alive then
      local player_unit = player.player_unit

      snapshot.health_percent = _safe(function()
        return HealthUtils.current_health_percent(player_unit)
      end)

      snapshot.toughness_percent = _safe(function()
        return ToughnessUtils.current_toughness_percent(player_unit)
      end)
    end
  end

  return snapshot
end

return M
