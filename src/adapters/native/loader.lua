-- Registers the FFI C declarations and loads telemetry_native.dll. Owns
-- `lib`/`available()` and getters for DLL-baked values (ingest / runs-open /
-- current-streak URLs, token path, poll/timeline intervals). Getters memoize
-- on first success; boot validates by calling them. Generic FFI helpers live
-- in native/ffi_call.lua.

local ffi = require("ffi")

local message = dofile_once("mods/noita-telemetry/src/core/messaging.lua")
local ffi_call = dofile_once("mods/noita-telemetry/src/adapters/native/ffi_call.lua")

ffi.cdef([[
  int telemetry_http_request_async(
    const char* method,
    const char* url,
    const char* bearer,
    const char* body,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_http_request_poll(
    char* response_buf,
    size_t response_buf_len,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_upload_file_async(
    const char* url,
    const char* api_key,
    const char* file_path,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_upload_poll(
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_get_ingest_url(
    char* out_buf,
    size_t out_buf_len
  );

  int telemetry_get_runs_open_url(
    char* out_buf,
    size_t out_buf_len
  );

  int telemetry_get_current_streak_url(
    char* out_buf,
    size_t out_buf_len
  );

  int telemetry_get_token_file_path(
    char* out_buf,
    size_t out_buf_len
  );

  int telemetry_get_poll_interval_frames(void);

  int telemetry_get_timeline_interval_sec(void);

  int telemetry_streak_patch_apply(
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_streak_get(
    int* out_streak,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_streak_set(
    int streak,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_run_open(
    const char* runs_dir,
    const char* run_id,
    const char* header_json,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_run_resume(
    const char* runs_dir,
    const char* run_id,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_run_append(
    const char* event_json,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_run_patch_header(
    const char* runs_dir,
    const char* run_id,
    const char* fields_json,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_run_is_active(
    const char* runs_dir,
    const char* run_id,
    int* out_active,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_run_delete(
    const char* run_path,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_append_timeline_tick(
    int t_ms,
    int playtime_sec,
    const char* biome,
    double x,
    double y,
    double hp_current,
    double hp_max,
    int gold,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_append_biome_enter(
    int t_ms,
    int playtime_sec,
    const char* biome,
    const char* from_biome,
    double x,
    double y,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_append_inventory_carry_start(
    int t_ms,
    int playtime_sec,
    const char* biome,
    unsigned int entity_id,
    const char* item_id,
    const char* item_type,
    const char* container,
    int wand_entity_id,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_append_inventory_carry_end(
    int t_ms,
    int playtime_sec,
    const char* biome,
    unsigned int entity_id,
    const char* item_id,
    const char* item_type,
    const char* reason,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_append_shop_action(
    int t_ms,
    int playtime_sec,
    const char* biome,
    double x,
    double y,
    int has_position,
    const char* action,
    int gold_before,
    int gold_spent,
    int gold_after,
    const char* item_id,
    const char* item_type,
    int stole,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_append_perk_pick(
    int t_ms,
    int playtime_sec,
    double x,
    double y,
    const char* perk_id,
    int perk_index,
    const char* biome,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_append_god_event(
    int t_ms,
    int playtime_sec,
    double x,
    double y,
    int angered,
    int killed,
    const char* biome,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_append_death(
    int t_ms,
    int playtime_sec,
    const char* biome,
    double x,
    double y,
    const char* killed_by,
    const char* killed_with,
    double hp_current,
    double hp_max,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_append_run_start(
    int t_ms,
    int playtime_sec,
    int seed,
    int ng_plus,
    const char* game_mode,
    const char* noita_version,
    const char* mods_json,
    double x,
    double y,
    double hp_current,
    double hp_max,
    const char* wands_json,
    const char* items_json,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_append_run_end(
    int t_ms,
    int playtime_sec,
    const char* result,
    double x,
    double y,
    double hp_current,
    double hp_max,
    int gold,
    int enemies_killed,
    int places_visited,
    int projectiles_shot,
    const char* wands_json,
    const char* items_json,
    const char* perks_json,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_append_holy_mountain_enter(
    int t_ms,
    int playtime_sec,
    const char* biome,
    double x,
    double y,
    int gold,
    double hp_current,
    double hp_max,
    int wand_count,
    int item_count,
    const char* wands_json,
    const char* items_json,
    const char* perks_json,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_append_holy_mountain_exit(
    int t_ms,
    int playtime_sec,
    const char* biome,
    double x,
    double y,
    int gold,
    int gold_spent_total,
    double hp_current,
    double hp_max,
    const char* wands_json,
    const char* items_json,
    const char* perks_json,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_run_close(
    const char* runs_dir,
    const char* run_id,
    const char* footer_json,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_generate_id(
    char* out_buf,
    size_t out_buf_len
  );
]])

local DLL_PATH = "mods/noita-telemetry/bin/telemetry_native"

local M = {}

-- Memoized after first successful read (DLL-baked; never changes at runtime).
local cache = {
  ingest_url = nil,
  runs_open_url = nil,
  current_streak_url = nil,
  token_file_path = nil,
  poll_interval_frames = nil,
  timeline_interval_sec = nil,
}

local loaded, native_or_err = pcall(ffi.load, DLL_PATH)
if loaded then
  M.lib = native_or_err
end

function M.available()
  return M.lib ~= nil
end

local function get_baked_url(export_name)
  if M.lib == nil then
    return nil, message.KEYS.MSG_ERROR_NATIVE_DLL_MISSING
  end
  if M.lib[export_name] == nil then
    return nil, message.KEYS.MSG_ERROR_NATIVE_EXPORT_MISSING
  end

  local out_buf = ffi.new("char[?]", 512)
  local result = M.lib[export_name](out_buf, 512)
  if result == 0 then
    local url = ffi.string(out_buf)
    if url == nil or url == "" then
      return nil, message.KEYS.MSG_ERROR_API_URL_MISSING
    end
    return url
  end

  return nil, message.KEYS.MSG_ERROR_API_URL_MISSING
end

function M.get_ingest_url()
  if cache.ingest_url ~= nil then
    return cache.ingest_url
  end
  local url, err = get_baked_url("telemetry_get_ingest_url")
  if url ~= nil then
    cache.ingest_url = url
  end
  return url, err
end

function M.get_runs_open_url()
  if cache.runs_open_url ~= nil then
    return cache.runs_open_url
  end
  local url, err = get_baked_url("telemetry_get_runs_open_url")
  if url ~= nil then
    cache.runs_open_url = url
  end
  return url, err
end

function M.get_current_streak_url()
  if cache.current_streak_url ~= nil then
    return cache.current_streak_url
  end
  local url, err = get_baked_url("telemetry_get_current_streak_url")
  if url ~= nil then
    cache.current_streak_url = url
  end
  return url, err
end

function M.get_token_file_path()
  if cache.token_file_path ~= nil then
    return cache.token_file_path
  end
  if M.lib == nil then
    return nil
  end
  if ffi_call.native_export(M.lib, "telemetry_get_token_file_path") == nil then
    return nil
  end

  local out_buf = ffi.new("char[?]", 512)
  local result = M.lib.telemetry_get_token_file_path(out_buf, 512)
  if result == 0 then
    local path = ffi.string(out_buf)
    if path == nil or path == "" then
      return nil
    end
    cache.token_file_path = path
    return path
  end

  return nil
end

function M.get_poll_interval_frames()
  if cache.poll_interval_frames ~= nil then
    return cache.poll_interval_frames
  end
  if M.lib == nil then
    return nil, message.KEYS.MSG_ERROR_NATIVE_DLL_MISSING
  end
  if M.lib.telemetry_get_poll_interval_frames == nil then
    return nil, message.KEYS.MSG_ERROR_NATIVE_EXPORT_MISSING
  end

  local value = M.lib.telemetry_get_poll_interval_frames()
  if type(value) ~= "number" or value <= 0 then
    return nil, message.KEYS.MSG_ERROR_POLL_INTERVAL_INVALID
  end

  cache.poll_interval_frames = value
  return value
end

function M.get_timeline_interval_sec()
  if cache.timeline_interval_sec ~= nil then
    return cache.timeline_interval_sec
  end
  if M.lib == nil then
    return nil, message.KEYS.MSG_ERROR_NATIVE_DLL_MISSING
  end
  if M.lib.telemetry_get_timeline_interval_sec == nil then
    return nil, message.KEYS.MSG_ERROR_NATIVE_EXPORT_MISSING
  end

  local value = M.lib.telemetry_get_timeline_interval_sec()
  if type(value) ~= "number" or value <= 0 then
    return nil, message.KEYS.MSG_ERROR_TIMELINE_INTERVAL_INVALID
  end

  cache.timeline_interval_sec = value
  return value
end

return M
