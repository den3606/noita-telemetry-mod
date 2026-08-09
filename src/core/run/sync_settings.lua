-- Cloud sync toggles (MOD settings) plus DLL-baked API URLs from loader.

local mod_settings = dofile_once("mods/noita-telemetry/src/adapters/noita/mod_settings.lua")
local loader = dofile_once("mods/noita-telemetry/src/adapters/native/loader.lua")

local M = {}

function M.get()
  return {
    enabled = mod_settings.get_bool("sync_enabled", true),
    delete_run_after_upload = mod_settings.get_bool("delete_run_after_upload", false),
    ingest_url = loader.get_ingest_url(),
    runs_open_url = loader.get_runs_open_url(),
    current_streak_url = loader.get_current_streak_url(),
  }
end

return M
