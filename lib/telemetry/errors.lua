local i18n = dofile_once("mods/noita-telemetry/lib/telemetry/i18n.lua")

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

local function normalize_api_slug(err)
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

function M.normalize_api(err)
  local slug = normalize_api_slug(err)
  return API_SLUG_TO_CODE[slug] or M.api_generic
end

function M.resolve(input, vars)
  if type(input) == "number" then
    if MESSAGE_KEYS[input] ~= nil then
      return input, vars
    end
    return M.unknown, vars
  end

  if type(input) ~= "string" then
    return M.unknown, vars
  end

  local slug = normalize_api_slug(input)
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

function M.message(code, vars)
  local key = MESSAGE_KEYS[code] or MESSAGE_KEYS[M.unknown]
  return i18n.t(key, vars)
end

function M.message_en(code, vars)
  local key = MESSAGE_KEYS[code] or MESSAGE_KEYS[M.unknown]
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

function M.print(input, vars)
  local text = M.format(input, vars)
  print(M.format_en(input, vars))
  GamePrint(text)
  return text
end

function M.report(input, vars)
  local text = M.format(input, vars)
  local text_en = M.format_en(input, vars)
  print(text_en)
  GamePrint(text)
  error(text_en)
end

return M
