-- Error display: wire / KEYS.MSG_ERROR_* → branded GamePrint + log.txt.
-- Native / API string interpretation lives in resolve.lua; catalogue in resources/messages.lua.
-- Callers usually go through messaging.lua re-exports.

local policy = dofile_once("mods/noita-telemetry/src/application/messaging/errors/policy.lua")
local resolve = dofile_once("mods/noita-telemetry/src/application/messaging/errors/resolve.lua")
local noita_message = dofile_once("mods/noita-telemetry/src/adapters/noita/message.lua")
local locale = dofile_once("mods/noita-telemetry/src/application/messaging/locale.lua")
local i18n = dofile_once("mods/noita-telemetry/src/resources/messages.lua")

local M = {}

local KEYS = i18n.KEYS
local BRAND = "[ntel] "

local function with_brand(text)
  return BRAND .. text
end

local function interpolate(template, vars)
  if vars == nil then
    return template
  end
  for name, value in pairs(vars) do
    template = template:gsub("{" .. name .. "}", tostring(value))
  end
  return template
end

local function t(key, vars, forced_locale)
  return interpolate(i18n.text(forced_locale or locale.current(), key), vars)
end

local function t_en(key, vars)
  return t(key, vars, "en")
end

local function prepare_error_vars(key, vars)
  if vars == nil then
    vars = {}
  end
  if vars.status_suffix == nil then
    vars.status_suffix = ""
  end
  if vars.mods == nil then
    vars.mods = ""
  end
  if key == KEYS.MSG_ERROR_API_DISALLOWED_MODS then
    vars.mods_detail = vars.mods ~= "" and (": " .. vars.mods) or ""
  end
  if key == KEYS.MSG_ERROR_API_OPEN_FAILED and (vars.api_message == nil or vars.api_message == "") then
    vars.api_message = "forbidden"
  end
  return vars
end

local function error_body(key, vars)
  return t(key, prepare_error_vars(key, vars))
end

local function error_body_en(key, vars)
  return t_en(key, prepare_error_vars(key, vars))
end

function M.format(input, vars)
  local key, message_vars = resolve.resolve(input, vars)
  return with_brand(error_body(key, message_vars))
end

local function format_en(input, vars)
  local key, message_vars = resolve.resolve(input, vars)
  return with_brand(error_body_en(key, message_vars))
end

--- Resolve wire/native err → player message, or print fallback_key for generic failures.
function M.notify_player(input, vars, diag_ctx, fallback_key)
  fallback_key = fallback_key or KEYS.MSG_CONNECT_FAILED
  local key = select(1, resolve.resolve(input, vars))

  if policy.CONNECT_FALLBACK_KEYS[key] == true then
    -- Same shape as message.print(fallback_key); avoid loading message.lua (cycle).
    noita_message.console(with_brand(t_en(fallback_key)))
    noita_message.game(with_brand(t(fallback_key)))
    return nil
  end
  local body = M.format(input, vars)
  local body_en = format_en(input, vars)
  noita_message.console(body_en)
  noita_message.game(body)
  return body
end
function M.error(input, vars, diag_ctx)
  local body = M.format(input, vars)
  noita_message.console(format_en(input, vars))
  noita_message.game(body)
  return body
end

return M
