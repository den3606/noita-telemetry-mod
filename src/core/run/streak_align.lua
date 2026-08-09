--- Align in-game win streak to ntel `current_win_streak` after open succeeds.
--- Caller must invoke only when Settings `force_win_streak` is ON.
--- Missing scope (404) leaves the game value alone.

local message = dofile_once("mods/noita-telemetry/src/core/messaging.lua")
local http = dofile_once("mods/noita-telemetry/src/adapters/native/http.lua")
local streak = dofile_once("mods/noita-telemetry/src/adapters/native/streak.lua")

local M = {}

local pending = nil

local function url_encode(value)
  return (tostring(value):gsub("([^%w%-%.%_%~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end))
end

local function with_streak_query(current_streak_url, game_mode, noita_version)
  return current_streak_url
    .. "?game_mode="
    .. url_encode(game_mode)
    .. "&noita_version="
    .. url_encode(noita_version)
end

local function parse_current_win_streak(response)
  if type(response) ~= "string" or response == "" then
    return nil
  end
  -- Success is HTTP 2xx from native; body has no ok wrapper.
  local streak_value = response:match('"current_win_streak"%s*:%s*(-?%d+)')
  if streak_value == nil then
    return nil
  end
  return tonumber(streak_value)
end

local function apply_ntel_streak(ntel_streak)
  local game_streak = streak.get_win_streak()
  if game_streak == nil then
    return
  end
  if game_streak == ntel_streak then
    return
  end

  local ok = streak.set_win_streak(ntel_streak)
  if not ok then
    return
  end

  message.print(message.KEYS.MSG_STREAK_ALIGN_CORRECTED)
end

function M.is_pending()
  return pending ~= nil
end

--- Start async GET. Caller gates on force_win_streak.
function M.queue_after_open(current_streak_url, mod_token, game_mode, noita_version)
  pending = nil

  if type(current_streak_url) ~= "string" or current_streak_url == "" then
    return
  end
  if type(mod_token) ~= "string" or mod_token == "" then
    return
  end
  if type(game_mode) ~= "string" or game_mode == "" then
    return
  end
  if type(noita_version) ~= "string" or noita_version == "" then
    return
  end

  local url = with_streak_query(current_streak_url, game_mode, noita_version)
  local ok = http.http_request_async("GET", url, mod_token, nil, { quiet = true })
  if not ok then
    return
  end

  pending = true
end

function M.poll()
  if pending == nil then
    return
  end

  local status, response = http.http_request_poll()
  if status == "running" then
    return
  end

  pending = nil
  if status ~= "success" then
    -- 404 / network / auth: keep game streak
    return
  end

  local ntel_streak = parse_current_win_streak(response)
  if ntel_streak == nil then
    return
  end

  apply_ntel_streak(ntel_streak)
end

function M.clear()
  pending = nil
end

return M
