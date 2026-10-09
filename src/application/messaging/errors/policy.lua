-- Error wire / display policy tables (not numeric codes).
-- Used by errors/resolve.lua and messaging.lua.

local i18n = dofile_once("mods/noita-telemetry/src/resources/messages.lua")
local KEYS = i18n.KEYS

local M = {}

-- Wire slug -> catalogue key (and native-ish aliases).
M.API_SLUG_TO_KEY = {
  not_authenticated = KEYS.MSG_ERROR_API_NOT_AUTHENTICATED,
  unauthorized = KEYS.MSG_ERROR_API_UNAUTHORIZED,
  http_failed = KEYS.MSG_ERROR_API_HTTP_FAILED,
  no_ingest_session = KEYS.MSG_ERROR_API_NO_INGEST_SESSION,
  session_expired = KEYS.MSG_ERROR_API_SESSION_EXPIRED,
  disallowed_mods = KEYS.MSG_ERROR_API_DISALLOWED_MODS,
  client_version_mismatch = KEYS.MSG_ERROR_API_CLIENT_VERSION_MISMATCH,
  invalid_client_version = KEYS.MSG_ERROR_API_CLIENT_VERSION_MISMATCH,
  forbidden = KEYS.MSG_ERROR_API_OPEN_FAILED,
  started_at_mismatch = KEYS.MSG_ERROR_API_STARTED_AT_MISMATCH,
  run_not_registered = KEYS.MSG_ERROR_API_STARTED_AT_MISMATCH,
  run_already_ingested = KEYS.MSG_ERROR_API_STARTED_AT_MISMATCH,
  invalid_started_at = KEYS.MSG_ERROR_API_INVALID_STARTED_AT,
  invalid_ended_at = KEYS.MSG_ERROR_API_INVALID_ENDED_AT,
  daily_ingest_limit = KEYS.MSG_ERROR_API_DAILY_INGEST_LIMIT,
  invalid_response = KEYS.MSG_ERROR_API_INVALID_RESPONSE,
  open_failed = KEYS.MSG_ERROR_API_OPEN_FAILED,
  not_ready = KEYS.MSG_ERROR_TELEMETRY_NOT_READY,
  unknown = KEYS.MSG_ERROR_API_UNKNOWN,
  native_dll_missing = KEYS.MSG_ERROR_NATIVE_DLL_MISSING,
  native_export_missing = KEYS.MSG_ERROR_NATIVE_EXPORT_MISSING,
}

-- Generic connect/upload failure only when nothing more specific is known.
M.CONNECT_FALLBACK_KEYS = {
  [KEYS.MSG_ERROR_API_HTTP_FAILED] = true,
  [KEYS.MSG_ERROR_UNKNOWN] = true,
}

return M
