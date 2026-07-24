local ffi = require("ffi")

local errors = dofile_once("mods/noita-telemetry/lib/telemetry/errors.lua")
local i18n = dofile_once("mods/noita-telemetry/lib/telemetry/i18n.lua")

local M = {}

ffi.cdef([[
  int telemetry_http_request(
    const char* method,
    const char* url,
    const char* bearer,
    const char* body,
    char* response_buf,
    size_t response_buf_len,
    char* error_buf,
    size_t error_buf_len
  );

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

  int telemetry_upload_file(
    const char* url,
    const char* api_key,
    const char* file_path,
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

  int telemetry_get_default_api_url(
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

  int telemetry_run_append_diagnostic(
    const char* runs_dir,
    const char* run_id,
    const char* line_json,
    char* error_buf,
    size_t error_buf_len
  );

  int telemetry_generate_id(
    char* out_buf,
    size_t out_buf_len
  );
]])

local DLL_PATH = "mods/noita-telemetry/lib/bin/telemetry_native"
local errors = dofile_once("mods/noita-telemetry/lib/telemetry/errors.lua")
local lib = nil

local loaded, native_or_err = pcall(ffi.load, DLL_PATH)
if loaded then
  lib = native_or_err
end

function M.available()
  return lib ~= nil
end

local function read_error(error_buf)
  return ffi.string(error_buf)
end

local pending_http_request = nil
local pending_upload_request = nil

local NATIVE_ERROR_BUF_LEN = 8192

local function http_target_label(url)
  if type(url) ~= "string" or url == "" then
    return "?"
  end
  return url:gsub("%?.*", "")
end

local function emit_http_log(method, target, ok, err, upload)
  local detail = err
  if type(err) == "string" and err ~= "" then
    detail = errors.resolve_detail(err)
  end
  i18n.emit_console(ok and "http_request_ok" or "http_request_failed", {
    method = method or "?",
    target = target or "?",
    detail = detail or "",
  })
  if not ok then
    return
  end
  if upload then
    GamePrint(i18n.t("data_send_ok"))
  else
    GamePrint(i18n.t("connect_ok"))
  end
end

local function emit_http_log_for_pending(pending, ok, err)
  if pending == nil then
    return
  end
  if pending.quiet then
    local detail = err
    if type(err) == "string" and err ~= "" then
      detail = errors.resolve_detail(err)
    end
    i18n.emit_console(ok and "http_request_ok" or "http_request_failed", {
      method = pending.method or "?",
      target = pending.target or "?",
      detail = detail or "",
    })
    return
  end
  emit_http_log(pending.method, pending.target, ok, err)
end

local function native_export(name)
  if lib == nil then
    return nil
  end
  local ok, export = pcall(function()
    return lib[name]
  end)
  if not ok then
    return nil
  end
  return export
end

local function bool_flag(value)
  return value and 1 or 0
end

local function as_i32(value)
  return math.floor(tonumber(value) or 0)
end

local function as_u32(value)
  local number = tonumber(value) or 0
  if number < 0 then
    number = number + 4294967296
  end
  return number
end

local function call_append(fn, ...)
  if lib == nil then
    return false, "telemetry_native.dll not found (run npm run build:native)"
  end
  if fn == nil then
    return false, "native export missing (run npm run build:native)"
  end

  local error_buf = ffi.new("char[?]", 256)
  local argc = select("#", ...)
  local args = { ... }
  args[argc + 1] = error_buf
  args[argc + 2] = 256

  local ok, result = pcall(function()
    return fn(unpack(args, 1, argc + 2))
  end)
  if not ok then
    return false, result
  end
  if result == 0 then
    return true
  end

  return false, read_error(error_buf)
end

function M.http_request(method, url, bearer, body)
  if lib == nil then
    return false, nil, "telemetry_native.dll not found (run npm run build:native)"
  end

  local response_buf = ffi.new("char[?]", 8192)
  local error_buf = ffi.new("char[?]", NATIVE_ERROR_BUF_LEN)
  local result = lib.telemetry_http_request(
    method,
    url,
    bearer or "",
    body or "",
    response_buf,
    8192,
    error_buf,
    NATIVE_ERROR_BUF_LEN
  )
  if result == 0 then
    emit_http_log(method, http_target_label(url), true, nil)
    return true, ffi.string(response_buf)
  end

  local err = read_error(error_buf)
  emit_http_log(method, http_target_label(url), false, err)
  return false, nil, err
end

local HTTP_POLL_IDLE = 0
local HTTP_POLL_RUNNING = 1
local HTTP_POLL_SUCCESS = 2
local HTTP_POLL_FAILED = 3

function M.http_request_async(method, url, bearer, body, opts)
  if lib == nil then
    return false, errors.native_dll_missing
  end
  if native_export("telemetry_http_request_async") == nil then
    return false, errors.native_export_missing
  end

  local error_buf = ffi.new("char[?]", NATIVE_ERROR_BUF_LEN)
  local result = lib.telemetry_http_request_async(
    method,
    url,
    bearer or "",
    body or "",
    error_buf,
    NATIVE_ERROR_BUF_LEN
  )
  if result == 0 then
    pending_http_request = {
      method = method,
      target = http_target_label(url),
      quiet = type(opts) == "table" and opts.quiet == true,
    }
    return true
  end

  local err = read_error(error_buf)
  emit_http_log(method, http_target_label(url), false, err)
  return false, err
end

function M.http_request_poll()
  if lib == nil then
    return "idle"
  end
  if native_export("telemetry_http_request_poll") == nil then
    return "idle"
  end

  local response_buf = ffi.new("char[?]", 8192)
  local error_buf = ffi.new("char[?]", NATIVE_ERROR_BUF_LEN)
  local result = lib.telemetry_http_request_poll(response_buf, 8192, error_buf, NATIVE_ERROR_BUF_LEN)
  if result == HTTP_POLL_RUNNING then
    return "running"
  end
  if result == HTTP_POLL_SUCCESS then
    local pending = pending_http_request
    pending_http_request = nil
    emit_http_log_for_pending(pending, true, nil)
    return "success", ffi.string(response_buf)
  end
  if result == HTTP_POLL_FAILED then
    local pending = pending_http_request
    pending_http_request = nil
    local err = read_error(error_buf)
    emit_http_log_for_pending(pending, false, err)
    return "failed", nil, err
  end
  return "idle"
end

function M.get_default_api_url()
  if lib == nil then
    return nil, errors.native_dll_missing
  end
  if lib.telemetry_get_default_api_url == nil then
    return nil, errors.native_export_missing
  end

  local out_buf = ffi.new("char[?]", 512)
  local result = lib.telemetry_get_default_api_url(out_buf, 512)
  if result == 0 then
    local url = ffi.string(out_buf)
    if url == nil or url == "" then
      return nil, errors.api_url_missing
    end
    return url
  end

  return nil, errors.api_url_missing
end

function M.get_token_file_path()
  if lib == nil then
    return nil
  end
  if native_export("telemetry_get_token_file_path") == nil then
    return nil
  end

  local out_buf = ffi.new("char[?]", 512)
  local result = lib.telemetry_get_token_file_path(out_buf, 512)
  if result == 0 then
    local path = ffi.string(out_buf)
    if path == nil or path == "" then
      return nil
    end
    return path
  end

  return nil
end

function M.get_poll_interval_frames()
  if lib == nil then
    return nil, errors.native_dll_missing
  end
  if lib.telemetry_get_poll_interval_frames == nil then
    return nil, errors.native_export_missing
  end

  local value = lib.telemetry_get_poll_interval_frames()
  if type(value) ~= "number" or value <= 0 then
    return nil, errors.poll_interval_invalid
  end

  return value
end

function M.get_timeline_interval_sec()
  if lib == nil then
    return nil, errors.native_dll_missing
  end
  if lib.telemetry_get_timeline_interval_sec == nil then
    return nil, errors.native_export_missing
  end

  local value = lib.telemetry_get_timeline_interval_sec()
  if type(value) ~= "number" or value <= 0 then
    return nil, errors.timeline_interval_invalid
  end

  return value
end

function M.upload_file(url, api_key, file_path)
  if lib == nil then
    return false, "telemetry_native.dll not found (run npm run build:native)"
  end

  local target = http_target_label(url) .. " (upload)"
  local error_buf = ffi.new("char[?]", NATIVE_ERROR_BUF_LEN)
  local result = lib.telemetry_upload_file(url, api_key, file_path, error_buf, NATIVE_ERROR_BUF_LEN)
  if result == 0 then
    emit_http_log("POST", target, true, nil, true)
    return true
  end

  local err = read_error(error_buf)
  emit_http_log("POST", target, false, err, true)
  return false, err
end

local UPLOAD_POLL_IDLE = 0
local UPLOAD_POLL_RUNNING = 1
local UPLOAD_POLL_SUCCESS = 2
local UPLOAD_POLL_FAILED = 3

function M.upload_file_async(url, api_key, file_path)
  if lib == nil then
    return false, errors.native_dll_missing
  end
  if native_export("telemetry_upload_file_async") == nil then
    return false, errors.native_export_missing
  end

  local target = http_target_label(url) .. " (upload)"
  local error_buf = ffi.new("char[?]", NATIVE_ERROR_BUF_LEN)
  local result = lib.telemetry_upload_file_async(url, api_key, file_path, error_buf, NATIVE_ERROR_BUF_LEN)
  if result == 0 then
    pending_upload_request = { target = target }
    return true
  end

  local err = read_error(error_buf)
  emit_http_log("POST", target, false, err, true)
  return false, err
end

function M.upload_poll()
  if lib == nil then
    return "idle"
  end
  if native_export("telemetry_upload_poll") == nil then
    return "idle"
  end

  local error_buf = ffi.new("char[?]", NATIVE_ERROR_BUF_LEN)
  local result = lib.telemetry_upload_poll(error_buf, NATIVE_ERROR_BUF_LEN)
  if result == UPLOAD_POLL_RUNNING then
    return "running"
  end
  if result == UPLOAD_POLL_SUCCESS then
    local pending = pending_upload_request
    pending_upload_request = nil
    if pending ~= nil then
      emit_http_log("POST", pending.target, true, nil, true)
    end
    return "success"
  end
  if result == UPLOAD_POLL_FAILED then
    local pending = pending_upload_request
    pending_upload_request = nil
    local err = read_error(error_buf)
    if pending ~= nil then
      emit_http_log("POST", pending.target, false, err, true)
    end
    return "failed", err
  end
  return "idle"
end

function M.apply_streak_patch()
  if lib == nil then
    return false, "telemetry_native.dll not found (run npm run build:native)"
  end

  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_streak_patch_apply(error_buf, 256)
  if result == 0 then
    return true
  end

  return false, read_error(error_buf)
end

--- Read GlobalStats.session.streak (requires streak patch applied).
--- @return number|nil streak
--- @return string|nil err
function M.get_win_streak()
  if lib == nil then
    return nil, "telemetry_native.dll not found (run npm run build:native)"
  end
  if native_export("telemetry_streak_get") == nil then
    return nil, "telemetry_streak_get export missing (rebuild native DLL)"
  end

  local out = ffi.new("int[1]")
  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_streak_get(out, error_buf, 256)
  if result == 0 then
    return tonumber(out[0])
  end

  return nil, read_error(error_buf)
end

--- Write GlobalStats.session.streak (requires streak patch applied).
--- @param streak number
--- @return boolean ok
--- @return string|nil err
function M.set_win_streak(streak)
  if lib == nil then
    return false, "telemetry_native.dll not found (run npm run build:native)"
  end
  if native_export("telemetry_streak_set") == nil then
    return false, "telemetry_streak_set export missing (rebuild native DLL)"
  end
  if type(streak) ~= "number" or streak ~= math.floor(streak) then
    return false, "streak must be an integer"
  end

  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_streak_set(streak, error_buf, 256)
  if result == 0 then
    return true
  end

  return false, read_error(error_buf)
end

function M.run_open(runs_dir, run_id, header_json)
  if lib == nil then
    return false, "telemetry_native.dll not found (run npm run build:native)"
  end

  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_run_open(runs_dir, run_id, header_json, error_buf, 256)
  if result == 0 then
    return true
  end

  return false, read_error(error_buf)
end

function M.run_resume(runs_dir, run_id)
  if lib == nil then
    return false, "telemetry_native.dll not found (run npm run build:native)"
  end

  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_run_resume(runs_dir, run_id, error_buf, 256)
  if result == 0 then
    return true
  end

  return false, read_error(error_buf)
end

function M.run_append(event_json)
  if lib == nil then
    return false, "telemetry_native.dll not found (run npm run build:native)"
  end

  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_run_append(event_json, error_buf, 256)
  if result == 0 then
    return true
  end

  return false, read_error(error_buf)
end

function M.run_close(runs_dir, run_id, footer_json)
  if lib == nil then
    return false, "telemetry_native.dll not found (run npm run build:native)"
  end

  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_run_close(runs_dir, run_id, footer_json, error_buf, 256)
  if result == 0 then
    return true
  end

  return false, read_error(error_buf)
end

function M.run_append_diagnostic(runs_dir, run_id, line_json)
  if lib == nil then
    return false, errors.native_dll_missing
  end
  if native_export("telemetry_run_append_diagnostic") == nil then
    return false, errors.native_export_missing
  end

  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_run_append_diagnostic(
    runs_dir,
    run_id,
    line_json,
    error_buf,
    256
  )
  if result == 0 then
    return true
  end

  return false, read_error(error_buf)
end

function M.generate_id()
  if lib == nil then
    return nil, "telemetry_native.dll not found (run npm run build:native)"
  end

  local out_buf = ffi.new("char[?]", 27)
  local result = lib.telemetry_generate_id(out_buf, 27)
  if result == 0 then
    return ffi.string(out_buf)
  end

  return nil, "telemetry_generate_id failed"
end

function M.append_timeline_tick(t_ms, playtime_sec, biome, x, y, hp_current, hp_max, gold)
  return call_append(
    lib.telemetry_append_timeline_tick,
    as_i32(t_ms),
    as_i32(playtime_sec),
    biome,
    x,
    y,
    hp_current,
    hp_max,
    as_i32(gold)
  )
end

function M.append_biome_enter(t_ms, playtime_sec, biome, from_biome, x, y)
  return call_append(
    lib.telemetry_append_biome_enter,
    as_i32(t_ms),
    as_i32(playtime_sec),
    biome,
    from_biome,
    x,
    y
  )
end

function M.append_inventory_carry_start(
  t_ms,
  playtime_sec,
  biome,
  entity_id,
  item_id,
  item_type,
  container,
  wand_entity_id
)
  return call_append(
    lib.telemetry_append_inventory_carry_start,
    as_i32(t_ms),
    as_i32(playtime_sec),
    biome,
    as_u32(entity_id),
    item_id,
    item_type,
    container,
    as_i32(wand_entity_id == nil and -1 or wand_entity_id)
  )
end

function M.append_inventory_carry_end(t_ms, playtime_sec, biome, entity_id, item_id, item_type, reason)
  return call_append(
    lib.telemetry_append_inventory_carry_end,
    as_i32(t_ms),
    as_i32(playtime_sec),
    biome,
    as_u32(entity_id),
    item_id,
    item_type,
    reason
  )
end

function M.append_shop_action(
  t_ms,
  playtime_sec,
  biome,
  x,
  y,
  has_position,
  action,
  gold_before,
  gold_spent,
  gold_after,
  item_id,
  item_type,
  stole
)
  return call_append(
    lib.telemetry_append_shop_action,
    as_i32(t_ms),
    as_i32(playtime_sec),
    biome,
    x,
    y,
    as_i32(bool_flag(has_position)),
    action,
    as_i32(gold_before),
    as_i32(gold_spent),
    as_i32(gold_after),
    item_id,
    item_type,
    as_i32(bool_flag(stole))
  )
end

function M.append_perk_pick(t_ms, playtime_sec, x, y, perk_id, perk_index, biome)
  return call_append(
    lib.telemetry_append_perk_pick,
    as_i32(t_ms),
    as_i32(playtime_sec),
    x,
    y,
    perk_id,
    as_i32(perk_index),
    biome
  )
end

function M.append_god_event(t_ms, playtime_sec, x, y, angered, killed, biome)
  return call_append(
    lib.telemetry_append_god_event,
    as_i32(t_ms),
    as_i32(playtime_sec),
    x,
    y,
    as_i32(bool_flag(angered)),
    as_i32(bool_flag(killed)),
    biome
  )
end

function M.append_death(t_ms, playtime_sec, biome, x, y, killed_by, killed_with, hp_current, hp_max)
  return call_append(
    lib.telemetry_append_death,
    as_i32(t_ms),
    as_i32(playtime_sec),
    biome,
    x,
    y,
    killed_by,
    killed_with,
    hp_current,
    hp_max
  )
end

function M.append_run_start(
  t_ms,
  playtime_sec,
  seed,
  ng_plus,
  game_mode,
  noita_version,
  mods_json,
  x,
  y,
  hp_current,
  hp_max,
  wands_json,
  items_json
)
  return call_append(
    lib.telemetry_append_run_start,
    as_i32(t_ms),
    as_i32(playtime_sec),
    as_i32(seed),
    as_i32(ng_plus),
    game_mode,
    noita_version,
    mods_json,
    x,
    y,
    hp_current,
    hp_max,
    wands_json,
    items_json
  )
end

function M.append_run_end(
  t_ms,
  playtime_sec,
  result,
  x,
  y,
  hp_current,
  hp_max,
  gold,
  enemies_killed,
  places_visited,
  projectiles_shot,
  wands_json,
  items_json,
  perks_json
)
  return call_append(
    lib.telemetry_append_run_end,
    as_i32(t_ms),
    as_i32(playtime_sec),
    result,
    x,
    y,
    hp_current,
    hp_max,
    as_i32(gold),
    as_i32(enemies_killed),
    as_i32(places_visited),
    as_i32(projectiles_shot),
    wands_json,
    items_json,
    perks_json
  )
end

function M.append_holy_mountain_enter(
  t_ms,
  playtime_sec,
  biome,
  x,
  y,
  gold,
  hp_current,
  hp_max,
  wand_count,
  item_count,
  wands_json,
  items_json,
  perks_json
)
  return call_append(
    lib.telemetry_append_holy_mountain_enter,
    as_i32(t_ms),
    as_i32(playtime_sec),
    biome,
    x,
    y,
    as_i32(gold),
    hp_current,
    hp_max,
    as_i32(wand_count),
    as_i32(item_count),
    wands_json,
    items_json,
    perks_json
  )
end

function M.append_holy_mountain_exit(
  t_ms,
  playtime_sec,
  biome,
  x,
  y,
  gold,
  gold_spent_total,
  hp_current,
  hp_max,
  wands_json,
  items_json,
  perks_json
)
  return call_append(
    lib.telemetry_append_holy_mountain_exit,
    as_i32(t_ms),
    as_i32(playtime_sec),
    biome,
    x,
    y,
    as_i32(gold),
    as_i32(gold_spent_total),
    hp_current,
    hp_max,
    wands_json,
    items_json,
    perks_json
  )
end

return M

