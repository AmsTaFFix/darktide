local mod = get_mod("claude_bridge")
local DMF = get_mod("DMF")

local io_backend = mod:io_dofile("claude_bridge/scripts/mods/claude_bridge/bridge/io_backend")
local state_probe = mod:io_dofile("claude_bridge/scripts/mods/claude_bridge/bridge/state_probe")

local M = { registry = {} }

local function _dump_name(request)
  return "claude_" .. tostring(request.id or "manual")
end

-- Writes 'value' (any table) to <game>/binaries/dump/<name>.json via DMF's own table dumper,
-- instead of shipping a second JSON serializer. Returns the response fragment to merge in.
local function _dump(request, value, depth)
  local name = _dump_name(request)
  mod:dtf(value, name, depth or request.depth or 2)
  return { ok = true, dump = string.format("dump/%s.json", name) }
end

-- Compiles and runs 'code' (from 'eval'/'dump' requests), returning (ok, result_or_error).
local function _run_code(request, chunk_name)
  if type(request.code) ~= "string" then
    return false, "requires a 'code' string"
  end

  local chunk, compile_error = io_backend.loadstring(request.code, chunk_name)
  if not chunk then
    return false, tostring(compile_error)
  end

  local ok, result = pcall(chunk)
  if not ok then
    return false, tostring(result)
  end

  return true, result
end

-- Runs arbitrary Lua and returns its result. Tables are written to a dump file instead of being
-- inlined into the response, since the response is a flat text file.
M.registry.eval = function(request)
  local ok, result = _run_code(request, "claude_bridge_eval")
  if not ok then
    return { ok = false, error = result }
  end

  if type(result) == "table" then
    return _dump(request, result)
  end

  return { ok = true, value = result }
end

-- Like 'eval', but always writes a dump file, wrapping a non-table result as { value = ... }
-- so scalar results can still be inspected with the same dump format.
M.registry.dump = function(request)
  local ok, result = _run_code(request, "claude_bridge_dump")
  if not ok then
    return { ok = false, error = result }
  end

  local wrapped = type(result) == "table" and result or { value = result }
  return _dump(request, wrapped)
end

-- Collects a snapshot of game/player state. See bridge/state_probe.lua for the fields.
M.registry.state = function(request)
  return _dump(request, state_probe.collect(), request.depth or 3)
end

-- Puts an on-screen notification up, mainly so the user can visually confirm a command ran.
M.registry.notify = function(request)
  mod:notify(tostring(request.text or ""))
  return { ok = true, value = "notified" }
end

-- Schedules a DMF mod reload. The caller (claude_bridge.lua) writes the response for this
-- request *before* acting on 'ok', since the reload tears this mod down and would otherwise
-- swallow the response.
M.registry.reload = function(request)
  if not DMF:get("developer_mode") then
    return { ok = false, error = "DMF developer_mode is disabled; enable it in the DMF options menu first" }
  end

  return { ok = true, value = "reload scheduled" }
end

-- Best-effort screenshot. FrameCapture.screen_shot is the only in-engine capture call found
-- anywhere in the decompiled Lua tree (game_states/state_game_testify.lua) and is unverified in
-- a retail build, so failure here just means "not available", not a bug.
M.registry.screenshot = function(request)
  if not rawget(_G, "FrameCapture") or not FrameCapture.screen_shot then
    return { ok = false, error = "FrameCapture.screen_shot is not available in this build" }
  end

  local output_dir = request.output_dir or (io_backend.appdata_path() .. "screenshots/")
  local filename = request.filename or _dump_name(request)

  local ok, result = pcall(FrameCapture.screen_shot, "color", nil, 1, output_dir, filename, "png", false)
  if not ok then
    return { ok = false, error = tostring(result) }
  end

  return { ok = true, value = output_dir .. filename .. ".png" }
end

return M
