local i18n = dofile_once("mods/noita-telemetry/lib/telemetry/i18n.lua")
local json = dofile_once("mods/noita-telemetry/lib/telemetry/json.lua")
local error_phases = dofile_once("mods/noita-telemetry/lib/telemetry/error_phases.lua")

local M = {
  native_dll_missing = 1,
  native_export_missing = 2,
  api_url_missing = 3,
  poll_interval_invalid = 4,
  timeline_interval_invalid = 5,
  logger_run_open_failed = 10,
  logger_run_append_failed = 11,
  streak_patch_skipped = 12,
  ulid_native_failed = 13,
  logger_run_close_failed = 14,
  logger_run_native_open_failed = 15,
  logger_run_native_resume_failed = 16,
  telemetry_not_ready = 17,
  logger_run_delete_failed = 18,
  -- 19 reserved (session_kills removed)
  api_not_authenticated = 100,
  api_unauthorized = 101,
  api_http_failed = 102,
  api_no_ingest_session = 103,
  api_session_expired = 104,
  api_disallowed_mods = 105,
  api_started_at_mismatch = 106,
  api_invalid_started_at = 107,
  api_invalid_ended_at = 108,
  -- 109 reserved (ingest_cooldown removed)
  api_daily_ingest_limit = 110,
  api_invalid_response = 111,
  api_open_failed = 112,
  api_unknown = 113,
  api_generic = 199,
  unknown = 99,
}

local MESSAGE_KEYS = {
  [M.native_dll_missing] = "error_native_dll_missing",
  [M.native_export_missing] = "error_native_export_missing",
  [M.api_url_missing] = "error_api_url_missing",
  [M.poll_interval_invalid] = "error_poll_interval_invalid",
  [M.timeline_interval_invalid] = "error_timeline_interval_invalid",
  [M.logger_run_open_failed] = "error_logger_run_open_failed",
  [M.logger_run_append_failed] = "error_logger_run_append_failed",
  [M.streak_patch_skipped] = "error_streak_patch_skipped",
  [M.ulid_native_failed] = "error_ulid_native_failed",
  [M.logger_run_close_failed] = "error_logger_run_close_failed",
  [M.logger_run_native_open_failed] = "error_logger_run_native_open_failed",
  [M.logger_run_native_resume_failed] = "error_logger_run_native_resume_failed",
  [M.telemetry_not_ready] = "error_telemetry_not_ready",
  [M.logger_run_delete_failed] = "error_logger_run_delete_failed",
  [M.api_not_authenticated] = "error_api_not_authenticated",
  [M.api_unauthorized] = "error_api_unauthorized",
  [M.api_http_failed] = "error_api_http_failed",
  [M.api_no_ingest_session] = "error_api_no_ingest_session",
  [M.api_session_expired] = "error_api_session_expired",
  [M.api_disallowed_mods] = "error_api_disallowed_mods",
  [M.api_started_at_mismatch] = "error_api_started_at_mismatch",
  [M.api_invalid_started_at] = "error_api_invalid_started_at",
  [M.api_invalid_ended_at] = "error_api_invalid_ended_at",
  [M.api_daily_ingest_limit] = "error_api_daily_ingest_limit",
  [M.api_invalid_response] = "error_api_invalid_response",
  [M.api_open_failed] = "error_api_open_failed",
  [M.api_unknown] = "error_api_unknown",
  [M.api_generic] = "error_api_generic",
  [M.unknown] = "error_unknown",
}

local API_SLUG_TO_CODE = {
  not_authenticated = M.api_not_authenticated,
  unauthorized = M.api_unauthorized,
  http_failed = M.api_http_failed,
  no_ingest_session = M.api_no_ingest_session,
  session_expired = M.api_session_expired,
  disallowed_mods = M.api_disallowed_mods,
  started_at_mismatch = M.api_started_at_mismatch,
  run_not_registered = M.api_started_at_mismatch,
  run_already_ingested = M.api_started_at_mismatch,
  invalid_started_at = M.api_invalid_started_at,
  invalid_ended_at = M.api_invalid_ended_at,
  daily_ingest_limit = M.api_daily_ingest_limit,
  invalid_response = M.api_invalid_response,
  open_failed = M.api_open_failed,
  not_ready = M.telemetry_not_ready,
  unknown = M.api_unknown,
}

local DETAIL_TRUNCATE = 512
local TRACE_TRUNCATE = 2048

local ERROR_RECORD_KEY_ORDER = {
  "event",
  "at",
  "t_ms",
  "phase",
  "code",
  "message",
  "http",
  "retry",
  "trace",
}

local CODE_TO_PHASE = {
  [M.logger_run_open_failed] = error_phases.logger.open,
  [M.logger_run_native_open_failed] = error_phases.logger.open,
  [M.logger_run_native_resume_failed] = error_phases.logger.open,
  [M.logger_run_append_failed] = error_phases.logger.append,
  [M.logger_run_close_failed] = error_phases.logger.close,
  [M.logger_run_delete_failed] = error_phases.logger.close,
  [M.ulid_native_failed] = error_phases.logger.open,
  [M.api_not_authenticated] = error_phases.sync.open.queue,
  [M.api_unauthorized] = error_phases.sync.open.queue,
  [M.api_no_ingest_session] = error_phases.sync.upload.queue,
  [M.api_session_expired] = error_phases.sync.open.http_poll,
  [M.api_disallowed_mods] = error_phases.sync.open.http_poll,
  [M.api_started_at_mismatch] = error_phases.sync.upload.http_poll,
  [M.api_invalid_started_at] = error_phases.sync.upload.http_poll,
  [M.api_invalid_ended_at] = error_phases.sync.upload.http_poll,
  [M.api_daily_ingest_limit] = error_phases.sync.upload.http_poll,
  [M.api_invalid_response] = error_phases.sync.open.http_poll,
  [M.api_open_failed] = error_phases.sync.open.http_poll,
  [M.api_http_failed] = error_phases.sync.upload.http_poll,
  [M.api_unknown] = error_phases.sync.upload.http_poll,
  [M.api_generic] = error_phases.sync.upload.http_poll,
}

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

local function truncate(value, max_len)
  if type(value) ~= "string" then
    return value
  end
  if #value <= max_len then
    return value
  end
  return value:sub(1, max_len) .. "…"
end

function M.normalize_api_slug(err)
  if type(err) ~= "string" or err == "" then
    return "unknown"
  end

  if err:sub(1, 4) == "api:" then
    return err:sub(5)
  end

  if err:find("401", 1, true) ~= nil then
    return "unauthorized"
  end

  if err:match("^http status") or err:match("^request failed") then
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

function M.parse_native_failure(raw)
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
    local diag = M.parse_native_failure(input)
    if type(diag.detail) == "string" and diag.detail ~= "" then
      return diag.detail
    end
    return input
  end
  return "unknown"
end

function M.vars_from_native_failure(raw)
  local diag = M.parse_native_failure(raw)
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

function M.normalize_api(err)
  local slug = M.normalize_api_slug(M.resolve_detail(err))
  return API_SLUG_TO_CODE[slug] or M.api_generic
end

function M.resolve(input, vars)
  if type(input) == "number" then
    if MESSAGE_KEYS[input] ~= nil then
      return input, vars
    end
    return M.unknown, vars
  end

  local native_vars
  if type(input) == "string" and input:sub(1, 1) == "{" then
    native_vars, _ = M.vars_from_native_failure(input)
    vars = merge_vars(native_vars, vars)
    input = M.resolve_detail(input)
  end

  if type(input) ~= "string" then
    return M.unknown, vars
  end

  local slug = M.normalize_api_slug(input)
  if slug == "native_dll_missing" then
    return M.native_dll_missing, vars
  end
  if slug == "native_export_missing" then
    return M.native_export_missing, vars
  end

  local code = API_SLUG_TO_CODE[slug]
  if code ~= nil then
    return code, vars
  end

  return M.api_generic, merge_vars(vars, { detail = slug })
end

local TOKEN_PATH_CODES = {
  [M.api_not_authenticated] = true,
  [M.api_unauthorized] = true,
}

local function with_token_path_vars(code, vars)
  if TOKEN_PATH_CODES[code] ~= true then
    return vars
  end
  local link = dofile_once("mods/noita-telemetry/lib/telemetry/link.lua")
  return merge_vars(vars, { path = link.token_file_path() })
end

function M.build_error_record(phase, err, ctx)
  ctx = ctx or {}
  local diag = M.parse_native_failure(err)
  local code, message_vars = M.resolve(err, ctx.vars)
  local detail
  if type(err) == "string" and err:sub(1, 1) == "{" then
    detail = diag.detail or M.resolve_detail(err)
  elseif type(err) == "string" and err ~= "" then
    detail = M.resolve_detail(err)
  else
    detail = M.message_en(code, message_vars)
  end
  local error_key = M.normalize_api_slug(
    type(err) == "string" and err:sub(1, 1) ~= "{" and err ~= "" and err or detail
  )

  local record = {
    event = "error",
    at = ctx.at or "",
    phase = phase,
    code = code,
    message = truncate(detail, DETAIL_TRUNCATE),
  }

  if type(ctx.t_ms) == "number" then
    record.t_ms = ctx.t_ms
  end

  local http = {}
  if type(ctx.http_method) == "string" and ctx.http_method ~= "" then
    http.method = ctx.http_method
  end
  local http_url = ctx.http_url or ctx.http_target
  if type(http_url) == "string" and http_url ~= "" then
    http.url = http_url
  end
  if type(diag.http) == "table" then
    if http.method == nil and type(diag.http.method) == "string" then
      http.method = diag.http.method
    end
    if http.url == nil and type(diag.http.target) == "string" then
      http.url = diag.http.target
    end
    if diag.http.status ~= nil then
      http.status = diag.http.status
    end
    if type(diag.http.response) == "string" and diag.http.response ~= "" then
      http.response = truncate(diag.http.response, 4096)
    end
  end
  if next(http) ~= nil then
    record.http = http
  end

  local retry = {}
  local open_retry = {}
  if type(ctx.retry) == "table" then
    if ctx.retry.attempt ~= nil then
      open_retry.attempt = ctx.retry.attempt
    end
    if ctx.retry.max ~= nil then
      open_retry.max = ctx.retry.max
    end
  end
  if next(open_retry) ~= nil then
    retry.open = open_retry
  end
  local http_retry = {}
  if type(diag.retry) == "table" then
    if diag.retry.http_attempt ~= nil then
      http_retry.attempt = diag.retry.http_attempt
    end
    if diag.retry.http_max ~= nil then
      http_retry.max = diag.retry.http_max
    end
  end
  if next(http_retry) ~= nil then
    retry.http = http_retry
  end
  if next(retry) ~= nil then
    record.retry = retry
  end

  local trace = {}
  if type(ctx.trace_lua) == "string" and ctx.trace_lua ~= "" then
    trace.lua = truncate(ctx.trace_lua, TRACE_TRUNCATE)
  elseif debug ~= nil and type(debug.traceback) == "function" then
    trace.lua = truncate(debug.traceback("", 2), TRACE_TRUNCATE)
  end

  if type(diag.trace_rust) == "string" and diag.trace_rust ~= "" then
    trace.rust = truncate(diag.trace_rust, TRACE_TRUNCATE)
  end
  if next(trace) ~= nil then
    record.trace = trace
  end

  return record
end

function M.encode_error_record(record)
  return json.encode_keys(record, ERROR_RECORD_KEY_ORDER)
end

function M.message(code, vars)
  local key = MESSAGE_KEYS[code] or MESSAGE_KEYS[M.unknown]
  if vars == nil then
    vars = {}
  end
  if vars.status_suffix == nil then
    vars.status_suffix = ""
  end
  return i18n.t(key, vars)
end

function M.message_en(code, vars)
  local key = MESSAGE_KEYS[code] or MESSAGE_KEYS[M.unknown]
  if vars == nil then
    vars = {}
  end
  if vars.status_suffix == nil then
    vars.status_suffix = ""
  end
  return i18n.t_en(key, vars)
end

function M.format(input, vars)
  local code, message_vars = M.resolve(input, vars)
  message_vars = with_token_path_vars(code, message_vars)
  return i18n.t("error_prefix", { code = tostring(code) }) .. " " .. M.message(code, message_vars)
end

function M.format_en(input, vars)
  local code, message_vars = M.resolve(input, vars)
  message_vars = with_token_path_vars(code, message_vars)
  return i18n.t_en("error_prefix", { code = tostring(code) }) .. " " .. M.message_en(code, message_vars)
end

local function diagnostic_run_path(diag_ctx)
  if type(diag_ctx) == "table" and type(diag_ctx.run_path) == "string" and diag_ctx.run_path ~= "" then
    return diag_ctx.run_path
  end
  local logger = dofile_once("mods/noita-telemetry/lib/telemetry/logger.lua")
  if type(logger.get_diagnostic_run_path) == "function" then
    return logger.get_diagnostic_run_path()
  end
  return nil
end

local function diagnostic_context(diag_ctx, code)
  local ctx = {}
  if type(diag_ctx) == "table" then
    for key, value in pairs(diag_ctx) do
      if key ~= "phase" and key ~= "run_path" and key ~= "record_run" then
        ctx[key] = value
      end
    end
    if type(diag_ctx.vars) == "table" then
      ctx.vars = diag_ctx.vars
    end
  end
  return ctx
end

function M.record_to_run(input, vars, diag_ctx)
  if input == nil or input == "disabled" then
    return false
  end
  if type(diag_ctx) == "table" and diag_ctx.record_run == false then
    return false
  end

  local run_path = diagnostic_run_path(diag_ctx)
  if run_path == nil then
    return false
  end

  local code = select(1, M.resolve(input, vars))
  local phase = type(diag_ctx) == "table" and diag_ctx.phase or nil
  if phase == nil then
    phase = CODE_TO_PHASE[code]
  end
  if phase == nil then
    return false
  end

  local run_diagnostic = dofile_once("mods/noita-telemetry/lib/telemetry/run_diagnostic.lua")
  local ctx = diagnostic_context(diag_ctx, code)
  return run_diagnostic.append_error(run_path, phase, input, ctx)
end

function M.print(input, vars, diag_ctx)
  M.record_to_run(input, vars, diag_ctx)
  local text = M.format(input, vars)
  print(M.format_en(input, vars))
  GamePrint(text)
  return text
end

function M.report(input, vars, diag_ctx)
  M.record_to_run(input, vars, diag_ctx)
  local text = M.format(input, vars)
  local text_en = M.format_en(input, vars)
  print(text_en)
  GamePrint(text)
  error(text_en)
end

return M
