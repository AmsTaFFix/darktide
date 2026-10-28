local mod = get_mod("claude_bridge")
local DMF = get_mod("DMF")

-- Local backups of the raw io/os/loadstring globals, captured by the mod loader before the
-- game's release-build patch (scripts/foundation/patches/scrub_dangerous_functions.lua) removes
-- them from scope. Mirrors the idiom used by DMF's own core/io.lua and by the uptime mod's
-- data/uptime_io.lua.
local _io = DMF:persistent_table("_io")
_io.initialized = _io.initialized or false
if not _io.initialized then
  _io = DMF.deepcopy(Mods.lua.io)
end

local _os = DMF:persistent_table("_os")
_os.initialized = _os.initialized or false
if not _os.initialized then
  _os = DMF.deepcopy(Mods.lua.os)
end

local _loadstring = Mods.lua.loadstring

local M = {}

-- Working directory for the bridge's request/response files.
function M.appdata_path()
  local appdata = _os.getenv("APPDATA")
  return appdata .. "/Fatshark/Darktide/claude_bridge/"
end

-- Returns the file's contents, or nil if it doesn't exist / can't be opened.
function M.read_file(path)
  local f = _io.open(path, "r")
  if not f then
    return nil
  end

  local content = f:read("*all")
  f:close()

  return content
end

-- Overwrites (or creates) the file at 'path' with 'content'. Returns true on success.
function M.write_file(path, content)
  local f = _io.open(path, "w+")
  if not f then
    return false
  end

  f:write(content)
  f:close()

  return true
end

-- Compiles a Lua chunk from a string. Returns the chunk function, or nil plus a compile error.
function M.loadstring(code, chunk_name)
  return _loadstring(code, chunk_name)
end

return M
