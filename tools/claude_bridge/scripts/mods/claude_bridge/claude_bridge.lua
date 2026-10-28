local mod = get_mod("claude_bridge")
local DMF = get_mod("DMF")

local io_backend = mod:io_dofile("claude_bridge/scripts/mods/claude_bridge/bridge/io_backend")
local commands = mod:io_dofile("claude_bridge/scripts/mods/claude_bridge/bridge/commands")

-- Tracks the highest request id handled so far, so a mod reload (which re-runs this file)
-- doesn't re-execute the last request, and so a stale request.lua left over from a previous
-- session is ignored on startup.
mod.context = mod:persistent_table("claude_bridge_context", { last_id = 0 })

local _request_path
local _response_path
local function _paths()
  if not _request_path then
    local base = io_backend.appdata_path()
    _request_path = base .. "request.lua"
    _response_path = base .. "response.txt"
  end

  return _request_path, _response_path
end

local function _format_value(value)
  local value_type = type(value)
  if value_type == "string" or value_type == "number" or value_type == "boolean" then
    return tostring(value)
  elseif value_type == "nil" then
    return "nil"
  else
    return string.format("<%s>", value_type)
  end
end

local function _write_response(id, result)
  local _, response_path = _paths()

  local lines = {
    "id: " .. tostring(id),
    "ok: " .. tostring(result.ok == true),
  }

  if result.value ~= nil then
    table.insert(lines, "value: " .. _format_value(result.value))
  end

  if result.dump then
    table.insert(lines, "dump: " .. result.dump)
  end

  if result.error then
    table.insert(lines, "error: " .. tostring(result.error))
  end

  io_backend.write_file(response_path, table.concat(lines, "\n") .. "\n")
end

-- Parses request.lua's contents ("return { id = ..., cmd = ..., ... }") into a table.
local function _parse_request(content)
  local chunk, compile_error = io_backend.loadstring(content, "claude_bridge_request")
  if not chunk then
    return nil, compile_error
  end

  local ok, request = pcall(chunk)
  if not ok then
    return nil, request
  end

  if type(request) ~= "table" then
    return nil, "request did not return a table"
  end

  return request
end

local function _dispatch(request)
  local handler = commands.registry[request.cmd]
  if not handler then
    return { ok = false, error = string.format("unknown command '%s'", tostring(request.cmd)) }
  end

  local ok, result = pcall(handler, request)
  if not ok then
    return { ok = false, error = tostring(result) }
  end

  return result
end

-- Runs one request end to end: dispatch, write the response, optionally echo to chat, and
-- (for 'reload') act on the result only after the response is safely on disk.
local function _execute(id, request)
  if mod:get("verbose_log") then
    mod:info("(claude_bridge) handling request #%s: %s", tostring(id), tostring(request.cmd))
  end

  local result = _dispatch(request)
  _write_response(id, result)

  if mod:get("echo_to_chat") then
    local status = result.ok and "ok" or "error"
    Managers.event:trigger("system_chat_message", string.format("[claude_bridge #%s] %s", tostring(id), status), "SYSTEM")
  end

  if request.cmd == "reload" and result.ok then
    DMF.request_mod_reload()
  end

  return result
end

local function _poll()
  local request_path = _paths()
  local content = io_backend.read_file(request_path)
  if not content then
    return
  end

  local request, parse_error = _parse_request(content)
  if not request then
    mod:error("(claude_bridge) failed to parse request: %s", tostring(parse_error))
    return
  end

  local id = request.id
  if type(id) ~= "number" or id <= mod.context.last_id then
    return
  end

  mod.context.last_id = id

  _execute(id, request)
end

local _poll_elapsed = 0
function mod.update(dt)
  _poll_elapsed = _poll_elapsed + dt

  local interval = mod:get("poll_interval") or 0.25
  if _poll_elapsed < interval then
    return
  end

  _poll_elapsed = 0

  local ok, err = pcall(_poll)
  if not ok then
    mod:error("(claude_bridge) poll failed: %s", tostring(err))
  end
end

-- Lets the user drive the same command registry by hand: "/claude eval return 1+1",
-- "/claude reload", "/claude state".
mod:command("claude", "Runs a claude_bridge command: /claude <cmd> [code...]", function(...)
  local args = { ... }
  local cmd = table.remove(args, 1)
  if not cmd then
    mod:notify("Usage: /claude <cmd> [code...]")
    return
  end

  local id = mod.context.last_id + 1
  mod.context.last_id = id

  local result = _execute(id, { id = id, cmd = cmd, code = table.concat(args, " ") })

  mod:notify(result.ok and "(claude_bridge) ok" or ("(claude_bridge) error: " .. tostring(result.error)))
end)
