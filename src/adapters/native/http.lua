-- Generic HTTP transport: any method (GET/POST/PUT/DELETE/...) against an
-- in-memory body, via telemetry_http_request*. File transfers live in
-- upload.lua. Shared success/fail logging is in http_log.lua.

local ffi = require("ffi")
local message = dofile_once("mods/noita-telemetry/src/core/messaging.lua")
local loader = dofile_once("mods/noita-telemetry/src/adapters/native/loader.lua")
local ffi_call = dofile_once("mods/noita-telemetry/src/adapters/native/ffi_call.lua")
local http_log = dofile_once("mods/noita-telemetry/src/adapters/native/http_log.lua")

local lib = loader.lib

local NATIVE_ERROR_BUF_LEN = 8192
local HTTP_POLL_RUNNING = 1
local HTTP_POLL_SUCCESS = 2
local HTTP_POLL_FAILED = 3

local pending_http_request = nil

local M = {}

function M.http_request_async(method, url, bearer, body, opts)
  if lib == nil then
    return false, message.KEYS.MSG_ERROR_NATIVE_DLL_MISSING
  end
  if ffi_call.native_export(lib, "telemetry_http_request_async") == nil then
    return false, message.KEYS.MSG_ERROR_NATIVE_EXPORT_MISSING
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
      target = http_log.target_label(url),
      quiet = type(opts) == "table" and opts.quiet == true,
    }
    return true
  end

  local err = ffi_call.read_error(error_buf)
  http_log.emit_log(method, http_log.target_label(url), false, err)
  return false, err
end

function M.http_request_poll()
  if lib == nil then
    return "idle"
  end
  if ffi_call.native_export(lib, "telemetry_http_request_poll") == nil then
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
    http_log.emit_log_for_pending(pending, true, nil)
    return "success", ffi.string(response_buf)
  end
  if result == HTTP_POLL_FAILED then
    local pending = pending_http_request
    pending_http_request = nil
    local err = ffi_call.read_error(error_buf)
    http_log.emit_log_for_pending(pending, false, err)
    return "failed", nil, err
  end
  return "idle"
end

return M
