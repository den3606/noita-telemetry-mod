-- Run-file upload via telemetry_upload_file*: takes a file_path (native
-- reads the file from disk itself), not a method/body -- so it doesn't fit
-- native/http.lua's generic HTTP shape. Logging goes through http_log.lua.

local ffi = require("ffi")
local message = dofile_once("mods/noita-telemetry/src/core/messaging.lua")
local loader = dofile_once("mods/noita-telemetry/src/adapters/native/loader.lua")
local ffi_call = dofile_once("mods/noita-telemetry/src/adapters/native/ffi_call.lua")
local http_log = dofile_once("mods/noita-telemetry/src/adapters/native/http_log.lua")

local lib = loader.lib

local NATIVE_ERROR_BUF_LEN = 8192
local UPLOAD_POLL_RUNNING = 1
local UPLOAD_POLL_SUCCESS = 2
local UPLOAD_POLL_FAILED = 3

local pending_upload_request = nil

local M = {}

function M.upload_file_async(url, api_key, file_path)
  if lib == nil then
    return false, message.KEYS.MSG_ERROR_NATIVE_DLL_MISSING
  end
  if ffi_call.native_export(lib, "telemetry_upload_file_async") == nil then
    return false, message.KEYS.MSG_ERROR_NATIVE_EXPORT_MISSING
  end

  local target = http_log.target_label(url) .. " (upload)"
  local error_buf = ffi.new("char[?]", NATIVE_ERROR_BUF_LEN)
  local result = lib.telemetry_upload_file_async(url, api_key, file_path, error_buf, NATIVE_ERROR_BUF_LEN)
  if result == 0 then
    pending_upload_request = { target = target }
    return true
  end

  local err = ffi_call.read_error(error_buf)
  http_log.emit_log("POST", target, false, err, true)
  return false, err
end

function M.upload_poll()
  if lib == nil then
    return "idle"
  end
  if ffi_call.native_export(lib, "telemetry_upload_poll") == nil then
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
      http_log.emit_log("POST", pending.target, true, nil, true)
    end
    return "success"
  end
  if result == UPLOAD_POLL_FAILED then
    local pending = pending_upload_request
    pending_upload_request = nil
    local err = ffi_call.read_error(error_buf)
    if pending ~= nil then
      http_log.emit_log("POST", pending.target, false, err, true)
    end
    return "failed", err
  end
  return "idle"
end

return M
