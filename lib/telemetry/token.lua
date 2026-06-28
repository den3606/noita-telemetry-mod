local native = dofile_once("mods/noita-telemetry/lib/telemetry/native.lua")

local M = {}

local resolved_path = nil
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

local function resolve_token_file_path()
  if resolved_path ~= nil then
    return resolved_path
  end

  local path = native.get_token_file_path()
  if path == nil or path == "" then
    return nil
  end

  resolved_path = path
  return resolved_path
end

function M.token_file_path()
  return resolve_token_file_path()
end

function M.read_file()
  if token_loaded then
    return cached_token
  end
  token_loaded = true

  local token_path = resolve_token_file_path()
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

function M.get()
  return M.read_file()
end

function M.is_configured()
  return M.get() ~= nil
end

return M
