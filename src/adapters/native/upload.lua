-- Run-file upload via telemetry_upload_file*: takes a file_path (native
-- reads the file from disk itself), not a method/body -- so it doesn't fit
-- native/http.lua's generic HTTP shape. Callers log the outcome (application/run/http_log.lua).

local ffi = require("ffi")
local KEYS = dofile_once("mods/noita-telemetry/src/resources/messages.lua").KEYS
local loader = dofile_once("mods/noita-telemetry/src/adapters/native/loader.lua")
local ffi_call = dofile_once("mods/noita-telemetry/src/adapters/native/ffi_call.lua")

local lib = loader.lib

local NATIVE_ERROR_BUF_LEN = 8192
local UPLOAD_POLL_RUNNING = 1
local UPLOAD_POLL_SUCCESS = 2
local UPLOAD_POLL_FAILED = 3

local M = {}

function M.upload_file_async(url, api_key, file_path)
  if lib == nil then
    return false, KEYS.MSG_ERROR_NATIVE_DLL_MISSING
  end
  if ffi_call.native_export(lib, "telemetry_upload_file_async") == nil then
    return false, KEYS.MSG_ERROR_NATIVE_EXPORT_MISSING
  end

  local error_buf = ffi.new("char[?]", NATIVE_ERROR_BUF_LEN)
  local result = lib.telemetry_upload_file_async(url, api_key, file_path, error_buf, NATIVE_ERROR_BUF_LEN)
  if result == 0 then
    return true
  end
  return false, ffi_call.read_error(error_buf)
end

---@return "idle"|"running"|"success"|"failed" status
---@return NativeHttpFailure|nil failure
function M.upload_poll()
  if lib == nil then
    return "idle"
  end
  if ffi_call.native_export(lib, "telemetry_upload_poll") == nil then
    return "idle"
  end

  local failure = ffi.new("telemetry_http_failure_t")
  local result = lib.telemetry_upload_poll(failure)
  if result == UPLOAD_POLL_RUNNING then
    return "running"
  end
  if result == UPLOAD_POLL_SUCCESS then
    return "success"
  end
  if result == UPLOAD_POLL_FAILED then
    return "failed", ffi_call.read_http_failure(failure)
  end
  return "idle"
end

return M
