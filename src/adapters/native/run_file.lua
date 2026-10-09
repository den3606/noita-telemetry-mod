-- .run file lifecycle: open / resume / append / close / patch / is_active / delete.
-- ULID minting lives in native/ulid.lua.

local ffi = require("ffi")
local KEYS = dofile_once("mods/noita-telemetry/src/resources/messages.lua").KEYS
local loader = dofile_once("mods/noita-telemetry/src/adapters/native/loader.lua")
local ffi_call = dofile_once("mods/noita-telemetry/src/adapters/native/ffi_call.lua")

local lib = loader.lib

local M = {}

function M.run_open(runs_dir, run_id, header_json)
  if lib == nil then
    return false, KEYS.MSG_ERROR_NATIVE_DLL_MISSING
  end

  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_run_open(runs_dir, run_id, header_json, error_buf, 256)
  if result == 0 then
    return true
  end

  return false, ffi_call.read_error(error_buf)
end

function M.run_resume(runs_dir, run_id)
  if lib == nil then
    return false, KEYS.MSG_ERROR_NATIVE_DLL_MISSING
  end

  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_run_resume(runs_dir, run_id, error_buf, 256)
  if result == 0 then
    return true
  end

  return false, ffi_call.read_error(error_buf)
end

function M.run_append(event_json)
  if lib == nil then
    return false, KEYS.MSG_ERROR_NATIVE_DLL_MISSING
  end

  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_run_append(event_json, error_buf, 256)
  if result == 0 then
    return true
  end

  return false, ffi_call.read_error(error_buf)
end

function M.run_close(runs_dir, run_id, footer_json)
  if lib == nil then
    return false, KEYS.MSG_ERROR_NATIVE_DLL_MISSING
  end

  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_run_close(runs_dir, run_id, footer_json, error_buf, 256)
  if result == 0 then
    return true
  end

  return false, ffi_call.read_error(error_buf)
end

--- Merge JSON fields into the header line of a finished .run file.
function M.run_patch_header(runs_dir, run_id, fields_json)
  if lib == nil then
    return false, KEYS.MSG_ERROR_NATIVE_DLL_MISSING
  end
  if ffi_call.native_export(lib, "telemetry_run_patch_header") == nil then
    return false, KEYS.MSG_ERROR_NATIVE_EXPORT_MISSING
  end

  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_run_patch_header(runs_dir, run_id, fields_json, error_buf, 256)
  if result == 0 then
    return true
  end

  return false, ffi_call.read_error(error_buf)
end

--- Whether the .run file exists and has no footer yet (resumable).
function M.run_is_active(runs_dir, run_id)
  if lib == nil then
    return nil, KEYS.MSG_ERROR_NATIVE_DLL_MISSING
  end
  if ffi_call.native_export(lib, "telemetry_run_is_active") == nil then
    return nil, KEYS.MSG_ERROR_NATIVE_EXPORT_MISSING
  end

  local out_active = ffi.new("int[1]")
  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_run_is_active(runs_dir, run_id, out_active, error_buf, 256)
  if result == 0 then
    return out_active[0] == 1
  end

  return nil, ffi_call.read_error(error_buf)
end

function M.run_delete(run_path)
  if lib == nil then
    return false, KEYS.MSG_ERROR_NATIVE_DLL_MISSING
  end
  if ffi_call.native_export(lib, "telemetry_run_delete") == nil then
    return false, KEYS.MSG_ERROR_NATIVE_EXPORT_MISSING
  end

  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_run_delete(run_path, error_buf, 256)
  if result == 0 then
    return true
  end

  return false, ffi_call.read_error(error_buf)
end

return M
