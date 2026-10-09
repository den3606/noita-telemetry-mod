-- Generic HTTP transport: any method (GET/POST/PUT/DELETE/...) against an
-- in-memory body, via telemetry_http_request*. File transfers live in
-- upload.lua. Callers log the outcome (application/run/http_log.lua).

local ffi = require("ffi")
local KEYS = dofile_once("mods/noita-telemetry/src/resources/messages.lua").KEYS
local loader = dofile_once("mods/noita-telemetry/src/adapters/native/loader.lua")
local ffi_call = dofile_once("mods/noita-telemetry/src/adapters/native/ffi_call.lua")

local lib = loader.lib

local NATIVE_ERROR_BUF_LEN = 8192
local HTTP_POLL_RUNNING = 1
local HTTP_POLL_SUCCESS = 2
local HTTP_POLL_FAILED = 3

local M = {}

function M.http_request_async(method, url, bearer, body)
  if lib == nil then
    return false, KEYS.MSG_ERROR_NATIVE_DLL_MISSING
  end
  if ffi_call.native_export(lib, "telemetry_http_request_async") == nil then
    return false, KEYS.MSG_ERROR_NATIVE_EXPORT_MISSING
  end

  local error_buf = ffi.new("char[?]", NATIVE_ERROR_BUF_LEN)
  local result =
    lib.telemetry_http_request_async(method, url, bearer or "", body or "", error_buf, NATIVE_ERROR_BUF_LEN)
  if result == 0 then
    return true
  end
  return false, ffi_call.read_error(error_buf)
end

---@return "idle"|"running"|"success"|"failed" status
---@return string|nil response
---@return NativeHttpFailure|nil failure
function M.http_request_poll()
  if lib == nil then
    return "idle"
  end
  if ffi_call.native_export(lib, "telemetry_http_request_poll") == nil then
    return "idle"
  end

  local response_buf = ffi.new("char[?]", 8192)
  local failure = ffi.new("telemetry_http_failure_t")
  local result = lib.telemetry_http_request_poll(response_buf, 8192, failure)
  if result == HTTP_POLL_RUNNING then
    return "running"
  end
  if result == HTTP_POLL_SUCCESS then
    return "success", ffi.string(response_buf)
  end
  if result == HTTP_POLL_FAILED then
    return "failed", nil, ffi_call.read_http_failure(failure)
  end
  return "idle"
end

return M
