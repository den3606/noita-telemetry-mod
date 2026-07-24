--- Align in-game win streak to ntel `current_win_streak` after open succeeds.
--- Caller must invoke only when Settings `force_win_streak` is ON.
--- Missing scope (404) leaves the game value alone.

local i18n = dofile_once("mods/noita-telemetry/lib/telemetry/i18n.lua")
local native = dofile_once("mods/noita-telemetry/lib/telemetry/native.lua")

local M = {}

local INGEST_SUFFIX = "/mod/ingest"
local STREAK_SUFFIX = "/mod/stats/current-streak"

local pending = nil

local function url_encode(value)
  return (tostring(value):gsub("([^%w%-%.%_%~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end))
end

local function current_streak_url(api_url, game_mode, noita_version)
  local base
  if api_url:sub(-#INGEST_SUFFIX) == INGEST_SUFFIX then
    base = api_url:sub(1, #api_url - #INGEST_SUFFIX)
  else
    base = api_url:gsub("/?$", "")
  end
  return base
    .. STREAK_SUFFIX
    .. "?game_mode="
    .. url_encode(game_mode)
    .. "&noita_version="
    .. url_encode(noita_version)
end

local function parse_current_win_streak(response)
  if type(response) ~= "string" or response == "" then
    return nil
  end
  if not response:find('"ok"%s*:%s*true') then
    return nil
  end
  local streak = response:match('"current_win_streak"%s*:%s*(-?%d+)')
  if streak == nil then
    return nil
  end
  return tonumber(streak)
end

local function apply_ntel_streak(ntel_streak)
  local game_streak = native.get_win_streak()
  if game_streak == nil then
    return
  end
  if game_streak == ntel_streak then
    return
  end

  local ok = native.set_win_streak(ntel_streak)
  if not ok then
    return
  end

  i18n.emit("streak_align_corrected")
end

function M.is_pending()
  return pending ~= nil
end

--- Start async GET. Caller gates on force_win_streak.
function M.queue_after_open(api_url, mod_token, game_mode, noita_version)
  pending = nil

  if type(api_url) ~= "string" or api_url == "" then
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

  local url = current_streak_url(api_url, game_mode, noita_version)
  local ok = native.http_request_async("GET", url, mod_token, nil, { quiet = true })
  if not ok then
    return
  end

  pending = true
end

function M.poll()
  if pending == nil then
    return
  end

  local status, response = native.http_request_poll()
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
