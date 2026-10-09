-- Mod initialization only (ModTextFile* / ModLuaFileAppend window).
-- Called once from init.lua at load time — not from OnWorldInitialized.
-- Validates native DLL + build-embedded config via loader getters; on failure
-- prints branded MSG_ERROR_* and aborts.

local version = dofile_once("mods/noita-telemetry/src/application/version.lua")
local message = dofile_once("mods/noita-telemetry/src/application/messaging.lua")
local noita_message = dofile_once("mods/noita-telemetry/src/adapters/noita/message.lua")
local loader = dofile_once("mods/noita-telemetry/src/adapters/native/loader.lua")

version.init()

local function abort(key)
  message.error(key)
  noita_message.error(message.format(key))
end

local function boot_validate()
  if not loader.available() then
    abort(message.KEYS.MSG_ERROR_NATIVE_DLL_MISSING)
  end

  local ingest_url, ingest_err = loader.get_ingest_url()
  if ingest_url == nil then
    abort(ingest_err or message.KEYS.MSG_ERROR_API_URL_MISSING)
  end

  local runs_open_url, open_err = loader.get_runs_open_url()
  if runs_open_url == nil then
    abort(open_err or message.KEYS.MSG_ERROR_API_URL_MISSING)
  end

  local current_streak_url, streak_err = loader.get_current_streak_url()
  if current_streak_url == nil then
    abort(streak_err or message.KEYS.MSG_ERROR_API_URL_MISSING)
  end

  local poll_interval_frames, poll_err = loader.get_poll_interval_frames()
  if poll_interval_frames == nil then
    abort(poll_err or message.KEYS.MSG_ERROR_POLL_INTERVAL_INVALID)
  end

  local timeline_interval_sec, timeline_err = loader.get_timeline_interval_sec()
  if timeline_interval_sec == nil then
    abort(timeline_err or message.KEYS.MSG_ERROR_TIMELINE_INTERVAL_INVALID)
  end
end

boot_validate()

ModLuaFileAppend(
  "data/scripts/perks/perk_reroll.lua",
  "mods/noita-telemetry/src/adapters/noita/hooks/perk_reroll_append.lua"
)

ModLuaFileAppend("data/scripts/perks/perk.lua", "mods/noita-telemetry/src/adapters/noita/hooks/perk_pickup_append.lua")

ModLuaFileAppend(
  "data/scripts/items/shop_effect.lua",
  "mods/noita-telemetry/src/adapters/noita/hooks/shop_effect_append.lua"
)
