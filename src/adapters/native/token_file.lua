-- The ingest token from noita-telemetry.token(.local), at the path baked into the DLL.
-- First non-empty, non-comment line; read once.

local loader = dofile_once("mods/noita-telemetry/src/adapters/native/loader.lua")

local M = {}

local cached_token = nil
local token_loaded = false

local function trim(value)
  if value == nil then
    return nil
  end
  return value:match("^%s*(.-)%s*$")
end

local function parse_token_line(line)
  line = trim(line)
  if line == nil or line == "" then
    return nil
  end
  if line:sub(1, 1) == "#" then
    return nil
  end
  return line
end

function M.get()
  if token_loaded then
    return cached_token
  end
  token_loaded = true

  local token_path = loader.get_token_file_path()
  if token_path == nil then
    cached_token = nil
    return nil
  end

  local file = io.open(token_path, "r")
  if file == nil then
    cached_token = nil
    return nil
  end

  for line in file:lines() do
    local token = parse_token_line(line)
    if token ~= nil then
      file:close()
      cached_token = token
      return cached_token
    end
  end

  file:close()
  cached_token = nil
  return nil
end

function M.is_configured()
  return M.get() ~= nil
end

return M
