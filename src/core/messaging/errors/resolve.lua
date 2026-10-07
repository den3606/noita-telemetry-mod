-- Map native / API error strings (and ErrorWire JSON) to KEYS.MSG_ERROR_* keys.
-- Catalogue keys: i18n.lua. Policy tables: errors/policy.lua. Player output: messaging.lua.

local i18n = dofile_once("mods/noita-telemetry/src/core/messaging/i18n.lua")
local json = dofile_once("mods/noita-telemetry/src/libs/json.lua")

local KEYS = i18n.KEYS
local M = {}

local policy = dofile_once("mods/noita-telemetry/src/core/messaging/errors/policy.lua")
local API_SLUG_TO_KEY = policy.API_SLUG_TO_KEY
local DEFINITIVE_API_SLUGS = policy.DEFINITIVE_API_SLUGS
local NON_RETRYABLE_API_KEYS = policy.NON_RETRYABLE_API_KEYS
local CONNECT_FALLBACK_KEYS = policy.CONNECT_FALLBACK_KEYS

local function format_mod_list(mods)
  if type(mods) ~= "table" then
    return nil
  end
  local names = {}
  for _, mod_id in ipairs(mods) do
    if type(mod_id) == "string" and mod_id ~= "" then
      names[#names + 1] = mod_id
    end
  end
  if #names == 0 then
    return nil
  end
  return table.concat(names, ", ")
end

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

function M.parse_error_wire_json(body)
  if type(body) ~= "string" or body == "" then
    return nil
  end
  local ok, parsed = pcall(json.decode, body)
  if ok and type(parsed) == "table" then
    if type(parsed.message) == "string" and parsed.message ~= "" then
      return parsed
    end
    if type(parsed.error) == "string" and parsed.error ~= "" then
      parsed.message = parsed.error
      return parsed
    end
    -- Valid JSON but not ErrorWire (e.g. native diag envelope) — avoid regex on nested fields.
    return nil
  end

  local message = body:match('\\"message\\"%s*:%s*\\"([^\\"]+)\\"')
    or body:match('"message"%s*:%s*"([^"]+)"')
    or body:match('\\"error\\"%s*:%s*\\"([^\\"]+)\\"')
    or body:match('"error"%s*:%s*"([^"]+)"')
  if message == nil then
    return nil
  end

  local wire = { message = message }
  local mods = {}
  local mods_inner = body:match('\\"disallowed_mods\\"%s*:%s*%[(.-)%]')
    or body:match('"disallowed_mods"%s*:%s*%[([^%]]*)%]')
  if mods_inner ~= nil then
    for mod_id in mods_inner:gmatch('"([^"]+)"') do
      mods[#mods + 1] = mod_id
    end
  end
  if #mods > 0 then
    wire.disallowed_mods = mods
  end
  return wire
end

local function parse_native_failure(raw)
  if type(raw) ~= "string" or raw == "" then
    return { detail = tostring(raw or "") }
  end
  if raw:sub(1, 1) ~= "{" then
    return { detail = raw }
  end

  local ok, parsed = pcall(json.decode, raw)
  if not ok or type(parsed) ~= "table" then
    return { detail = raw }
  end
  return parsed
end

function M.resolve_detail(input)
  if type(input) == "table" and type(input.detail) == "string" then
    return input.detail
  end
  if type(input) == "string" then
    local diag = parse_native_failure(input)
    if type(diag.detail) == "string" and diag.detail ~= "" then
      return diag.detail
    end
    return input
  end
  return "unknown"
end

local function vars_from_native_failure(raw)
  local diag = parse_native_failure(raw)
  local vars = {}
  local http = diag.http
  if type(http) == "table" and http.status ~= nil then
    vars.http_status = http.status
    vars.status_suffix = " (HTTP " .. tostring(http.status) .. ")"
  else
    vars.status_suffix = ""
  end
  if type(diag.detail) == "string" then
    vars.detail = diag.detail
  end
  return vars, diag
end

local function wire_from_native_err(input)
  if type(input) ~= "string" or input:sub(1, 1) ~= "{" then
    return nil
  end
  local diag = parse_native_failure(input)
  if type(diag.http) == "table" and type(diag.http.response) == "string" and diag.http.response ~= "" then
    local wire = M.parse_error_wire_json(diag.http.response)
    if wire ~= nil and type(wire.message) == "string" and wire.message ~= "" then
      return wire
    end
  end
  local wire = M.parse_error_wire_json(input)
  if wire ~= nil and type(wire.message) == "string" and wire.message ~= "" then
    return wire
  end
  return nil
end

local function normalize_api_slug(err)
  if type(err) ~= "string" or err == "" then
    return "unknown"
  end

  if err:sub(1, 4) == "api:" then
    return err:sub(5)
  end

  if err:find("401", 1, true) ~= nil then
    return "unauthorized"
  end

  if err:match("^http status:?%s*") or err:match("^request failed:%s*http status:?%s*") then
    return "http_failed"
  end

  if err:find("telemetry_native.dll not found", 1, true) then
    return "native_dll_missing"
  end

  if err:find("native export missing", 1, true) then
    return "native_export_missing"
  end

  return err
end

local function slug_from_native_detail(detail)
  if type(detail) ~= "string" or detail == "" then
    return nil
  end
  if detail:sub(1, 4) == "api:" then
    return detail:sub(5)
  end
  return normalize_api_slug(detail)
end

local function infer_http_status_code(err)
  if type(err) ~= "string" then
    return nil
  end
  local status = err:match("http status:?(%d+)")
    or err:match("http status (%d+)")
  if status ~= nil then
    return tonumber(status)
  end
  return nil
end

local function infer_key_from_plain_http_err(err)
  local status = infer_http_status_code(err)
  if status == 401 then
    return KEYS.MSG_ERROR_API_UNAUTHORIZED
  end
  if status == 403 then
    return KEYS.MSG_ERROR_API_DISALLOWED_MODS
  end
  if status == 400 then
    return KEYS.MSG_ERROR_API_OPEN_FAILED
  end
  return nil
end

local function infer_slug_from_raw(err)
  if type(err) ~= "string" or err == "" then
    return nil
  end
  if err:find("api:disallowed_mods", 1, true) ~= nil
    or err:find('"message":"disallowed_mods"', 1, true) ~= nil
    or err:find('\\"message\\":\\"disallowed_mods\\"', 1, true) ~= nil then
    return "disallowed_mods"
  end
  if err:find("api:unauthorized", 1, true) ~= nil
    or err:find('"message":"unauthorized"', 1, true) ~= nil
    or err:find('\\"message\\":\\"unauthorized\\"', 1, true) ~= nil then
    return "unauthorized"
  end
  if err:find("api:not_authenticated", 1, true) ~= nil
    or err:find('"message":"not_authenticated"', 1, true) ~= nil then
    return "not_authenticated"
  end
  if err:find("api:session_expired", 1, true) ~= nil
    or err:find('"message":"session_expired"', 1, true) ~= nil then
    return "session_expired"
  end
  if err:sub(1, 4) == "api:" then
    return err:sub(5)
  end
  return nil
end

local function native_http_status(err)
  if type(err) ~= "string" then
    return nil
  end
  if err:sub(1, 1) == "{" then
    local diag = parse_native_failure(err)
    if type(diag.http) == "table" and diag.http.status ~= nil then
      return tonumber(diag.http.status)
    end
  end
  local status = err:match('"status"%s*:%s*(%d+)')
    or err:match('\\"status\\"%s*:%s*(%d+)')
  if status ~= nil then
    return tonumber(status)
  end
  return nil
end

local function resolve_api_slug(input)
  if type(input) == "string" then
    local inferred = infer_slug_from_raw(input)
    if inferred ~= nil then
      return inferred
    end
  end
  if type(input) == "string" and input:sub(1, 1) == "{" then
    local wire = wire_from_native_err(input)
    if wire ~= nil and type(wire.message) == "string" and wire.message ~= "" then
      return wire.message
    end
    local diag = parse_native_failure(input)
    local slug = slug_from_native_detail(diag.detail)
    if slug ~= nil and slug ~= "http_failed" and slug ~= "unknown" then
      return slug
    end
    input = M.resolve_detail(input)
  end
  if type(input) ~= "string" or input == "" then
    return nil
  end
  return normalize_api_slug(input)
end

local function vars_from_api_error(input, vars)
  vars = vars or {}
  if type(input) ~= "string" or input:sub(1, 1) ~= "{" then
    return vars
  end

  local wire = wire_from_native_err(input)
  if wire == nil then
    return vars
  end

  local mods = format_mod_list(wire.disallowed_mods)
  if mods ~= nil then
    vars.mods = mods
  end
  if type(wire.message) == "string" and wire.message ~= "" then
    vars.api_message = wire.message
  end
  return vars
end

--- Already a catalogue error identity (`KEYS.MSG_ERROR_*`).
local function is_resolved_error_key(input)
  return type(input) == "string"
    and KEYS[input] == input
    and input:sub(1, 10) == "MSG_ERROR_"
end

function M.resolve(input, vars)
  if is_resolved_error_key(input) then
    return input, vars
  end

  local native_vars
  local native_diag
  if type(input) == "string" and input:sub(1, 1) == "{" then
    native_vars, native_diag = vars_from_native_failure(input)
    vars = merge_vars(native_vars, vars)
    vars = vars_from_api_error(input, vars)
    local wire = wire_from_native_err(input)
    if wire ~= nil and type(wire.message) == "string" and wire.message ~= "" then
      input = wire.message
    else
      local slug = slug_from_native_detail(native_diag.detail)
      if slug ~= nil and slug ~= "http_failed" and slug ~= "unknown" then
        input = slug
      else
        input = M.resolve_detail(input)
      end
    end
  end

  if type(input) ~= "string" then
    return KEYS.MSG_ERROR_UNKNOWN, vars
  end

  local slug = normalize_api_slug(input)
  local key = API_SLUG_TO_KEY[slug]
  if key ~= nil then
    return key, vars
  end

  return KEYS.MSG_ERROR_API_GENERIC, merge_vars(vars, { detail = slug })
end

function M.is_retryable_api_err(err)
  local slug = resolve_api_slug(err)
  if slug ~= nil and slug ~= "http_failed" and slug ~= "unknown" then
    if DEFINITIVE_API_SLUGS[slug] == true or API_SLUG_TO_KEY[slug] ~= nil then
      return false
    end
  end

  local status = native_http_status(err)
  if type(status) == "number" then
    if status == 408 or status == 429 then
      -- transient; keep retry unless a definitive slug was found above
    elseif status >= 400 and status < 500 then
      return false
    end
  end

  if type(err) == "string" and err:match("http status:?%s*4") then
    return false
  end
  if type(err) == "string" and err:match("http status %d") then
    return false
  end

  local plain_key = infer_key_from_plain_http_err(err)
  if plain_key ~= nil and CONNECT_FALLBACK_KEYS[plain_key] ~= true then
    return false
  end

  local key = select(1, M.resolve(err))
  if key == KEYS.MSG_ERROR_API_HTTP_FAILED then
    return true
  end
  return NON_RETRYABLE_API_KEYS[key] ~= true
end

--- Prefer a specific API slug over a generic http_failed when notifying the player.
function M.resolve_for_player(input, vars)
  local slug = resolve_api_slug(input)
  local key, message_vars = M.resolve(input, vars)

  if slug ~= nil and slug ~= "http_failed" and slug ~= "unknown" then
    local mapped = API_SLUG_TO_KEY[slug]
    if mapped ~= nil then
      key = mapped
    else
      key = KEYS.MSG_ERROR_API_GENERIC
      message_vars = merge_vars(message_vars, { detail = slug })
    end
    message_vars = vars_from_api_error(input, message_vars)
  elseif key == KEYS.MSG_ERROR_API_HTTP_FAILED then
    local plain_key = infer_key_from_plain_http_err(input)
    if plain_key ~= nil then
      key = plain_key
      message_vars = vars_from_api_error(input, message_vars)
    end
  end

  return key, message_vars
end

M.merge_vars = merge_vars

return M
