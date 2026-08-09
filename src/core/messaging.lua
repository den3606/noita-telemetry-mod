-- Public messaging facade (print / print_console / t / lines / KEYS).
-- Implementation lives under messaging/ (i18n, locale, errors/*).
-- Wire / native error display: messaging/errors/report.lua (re-exported as
-- format / error / notify_player). Resolve helpers: messaging/errors/resolve.lua.
-- Noita I/O: adapters/noita/message.lua.
-- Callers use message.KEYS.* — do not pass raw catalogue strings.
-- Brand [ntel] is applied here / in report (not in the catalogue).

local resolve = dofile_once("mods/noita-telemetry/src/core/messaging/errors/resolve.lua")
local report = dofile_once("mods/noita-telemetry/src/core/messaging/errors/report.lua")
local noita_message = dofile_once("mods/noita-telemetry/src/adapters/noita/message.lua")
local locale = dofile_once("mods/noita-telemetry/src/core/messaging/locale.lua")
local i18n = dofile_once("mods/noita-telemetry/src/core/messaging/i18n.lua")

local M = {}

M.KEYS = i18n.KEYS

-- Resolve / parse surface used by session / http.
M.parse_error_wire_json = resolve.parse_error_wire_json
M.resolve_detail = resolve.resolve_detail
M.resolve = resolve.resolve
M.is_retryable_api_err = resolve.is_retryable_api_err

-- Error display (may accept wire / native failure strings).
M.format = report.format
M.error = report.error
M.notify_player = report.notify_player

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

function M.t(key, vars, forced_locale)
  return interpolate(i18n.text(forced_locale or locale.current(), key), vars)
end

local function t_en(key, vars)
  return M.t(key, vars, "en")
end

--- Write English to log.txt (`print`) only.
function M.print_console(key, vars)
  noita_message.console(with_brand(t_en(key, vars)))
end

--- Write English to log.txt (`print`) and localized text in-game (`GamePrint`).
function M.print(key, vars, console_vars)
  noita_message.console(with_brand(t_en(key, console_vars or vars)))
  noita_message.game(with_brand(M.t(key, vars)))
end

function M.lines(key)
  return i18n.lines(locale.current(), key)
end

return M
