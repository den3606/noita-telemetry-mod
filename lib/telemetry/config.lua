local errors = dofile_once("mods/noita-telemetry/lib/telemetry/errors.lua")

local MOD_ID = "noita-telemetry"

local function mod_setting(id, default)
  if ModSettingGet == nil then
    return default
  end

  local value = ModSettingGet(MOD_ID .. "." .. id)
  if value == nil then
    return default
  end

  return value
end

local function mod_setting_bool(id, default)
  local value = mod_setting(id, default)
  if type(value) == "boolean" then
    return value
  end
  if type(value) == "number" then
    return value ~= 0
  end
  return default
end

local function boot_validate()
  local native = dofile_once("mods/noita-telemetry/lib/telemetry/native.lua")

  if not native.available() then
    return false, errors.native_dll_missing
  end

  local api_url, api_err = native.get_default_api_url()
  if api_url == nil then
    return false, api_err or errors.api_url_missing
  end

  local poll_interval_frames, poll_err = native.get_poll_interval_frames()
  if poll_interval_frames == nil then
    return false, poll_err or errors.poll_interval_invalid
  end

  local timeline_interval_sec, timeline_err = native.get_timeline_interval_sec()
  if timeline_interval_sec == nil then
    return false, timeline_err or errors.timeline_interval_invalid
  end

  return true, {
    api_url = api_url,
    poll_interval_frames = poll_interval_frames,
    timeline_interval_sec = timeline_interval_sec,
  }
end

local M = {
  mod_id = MOD_ID,
  client_version = "20260628-359b2ca",
  runs_dir = "mods/noita-telemetry/runs",
  ready = false,
  boot_error_code = nil,
  poll_interval_frames = nil,
  timeline_interval_sec = nil,
  _default_api_url = nil,
}

local boot_ok, boot_result = boot_validate()
M.ready = boot_ok
if boot_ok then
  M._default_api_url = boot_result.api_url
  M.poll_interval_frames = boot_result.poll_interval_frames
  M.timeline_interval_sec = boot_result.timeline_interval_sec
else
  M.boot_error_code = boot_result or errors.unknown
end

function M.boot_error_message()
  return errors.format(M.boot_error_code or errors.unknown)
end

function M.force_win_streak_enabled()
  return mod_setting_bool("force_win_streak", false)
end

function M.get_sync()
  if not M.ready then
    return nil, M.boot_error_code or errors.unknown
  end

  return {
    enabled = mod_setting_bool("sync_enabled", true),
    delete_run_after_upload = mod_setting_bool("delete_run_after_upload", false),
    api_url = M._default_api_url,
  }
end

return M
