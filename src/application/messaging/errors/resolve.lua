-- Map DLL failures (NativeHttpFailure), Lua-side slugs and catalogue keys to KEYS.MSG_ERROR_* keys.
-- Catalogue keys: resources/messages.lua. Policy tables: errors/policy.lua. Player output: messaging.lua.

local i18n = dofile_once("mods/noita-telemetry/src/resources/messages.lua")
local json = dofile_once("mods/noita-telemetry/src/libs/json.lua")

local KEYS = i18n.KEYS
local M = {}

local policy = dofile_once("mods/noita-telemetry/src/application/messaging/errors/policy.lua")
local API_SLUG_TO_KEY = policy.API_SLUG_TO_KEY

local function merge_vars(base, extra)
  if extra == nil then
    return base
  end
  if base == nil then
    return extra
  end
  local merged = {}
  for key, value in pairs(base) do
    merged[key] = value
  end
  for key, value in pairs(extra) do
    merged[key] = value
  end
  return merged
end

local function decode_object(raw)
  if type(raw) ~= "string" or raw:sub(1, 1) ~= "{" then
    return nil
  end
  local ok, parsed = pcall(json.decode, raw)
  if ok and type(parsed) == "table" then
    return parsed
  end
  return nil
end

--- Server ErrorWire body: `message` (legacy: `error`) plus optional `disallowed_mods`.
function M.parse_error_wire_json(body)
  local wire = decode_object(body)
  if wire == nil then
    return nil
  end
  if type(wire.message) == "string" and wire.message ~= "" then
    return wire
  end
  if type(wire.error) == "string" and wire.error ~= "" then
    wire.message = wire.error
    return wire
  end
  return nil
end

---@return NativeHttpFailure|nil
local function as_native_failure(input)
  if type(input) == "table" and type(input.detail) == "string" then
    return input
  end
  return nil
end

function M.resolve_detail(input)
  local failure = as_native_failure(input)
  if failure ~= nil and failure.detail ~= "" then
    return failure.detail
  end
  if type(input) == "string" then
    return input
  end
  return "unknown"
end

---@param failure NativeHttpFailure
local function vars_from_native_failure(failure)
  local vars = { detail = failure.detail, status_suffix = "" }
  if failure.http_status ~= nil then
    vars.status_suffix = " (HTTP " .. tostring(failure.http_status) .. ")"
  end
  if failure.api_code ~= nil then
    vars.api_message = failure.api_code
    vars.mods = failure.disallowed_mods
  end
  return vars
end

---@param failure NativeHttpFailure
local function slug_of_native_failure(failure)
  if failure.api_code ~= nil then
    return failure.api_code
  end
  if failure.http_status ~= nil then
    return "http_failed"
  end
  return failure.detail
end

local function key_for_slug(slug, vars)
  local key = API_SLUG_TO_KEY[slug]
  if key ~= nil then
    return key, vars
  end
  return KEYS.MSG_ERROR_API_GENERIC, merge_vars(vars, { detail = slug })
end

--- Already a catalogue error identity (`KEYS.MSG_ERROR_*`).
local function is_resolved_error_key(input)
  return type(input) == "string" and KEYS[input] == input and input:sub(1, 10) == "MSG_ERROR_"
end

--- Input is a catalogue key, a DLL failure (NativeHttpFailure), or a Lua-side slug.
function M.resolve(input, vars)
  if is_resolved_error_key(input) then
    return input, vars
  end

  local failure = as_native_failure(input)
  if failure ~= nil then
    return key_for_slug(slug_of_native_failure(failure), merge_vars(vars_from_native_failure(failure), vars))
  end

  if type(input) ~= "string" then
    return KEYS.MSG_ERROR_UNKNOWN, vars
  end
  if input == "" then
    return key_for_slug("unknown", vars)
  end
  return key_for_slug(input, vars)
end

M.merge_vars = merge_vars

return M
