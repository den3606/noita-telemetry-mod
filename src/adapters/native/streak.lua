-- Win-streak memory patch + read/write of GlobalStats.session.streak.

local ffi = require("ffi")
local loader = dofile_once("mods/noita-telemetry/src/adapters/native/loader.lua")
local ffi_call = dofile_once("mods/noita-telemetry/src/adapters/native/ffi_call.lua")

local lib = loader.lib

local M = {}

function M.apply_streak_patch()
  if lib == nil then
    return false, "telemetry_native.dll not found (run npm run build:native)"
  end

  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_streak_patch_apply(error_buf, 256)
  if result == 0 then
    return true
  end

  return false, ffi_call.read_error(error_buf)
end

--- Read GlobalStats.session.streak (requires streak patch applied).
--- @return number|nil streak
--- @return string|nil err
function M.get_win_streak()
  if lib == nil then
    return nil, "telemetry_native.dll not found (run npm run build:native)"
  end
  if ffi_call.native_export(lib, "telemetry_streak_get") == nil then
    return nil, "telemetry_streak_get export missing (rebuild native DLL)"
  end

  local out = ffi.new("int[1]")
  local error_buf = ffi.new("char[?]", 256)
  local result = lib.telemetry_streak_get(out, error_buf, 256)
  if result == 0 then
    return tonumber(out[0])
  end

  return nil, ffi_call.read_error(error_buf)
end

--- Write GlobalStats.session.streak (requires streak patch applied).
--- @param streak number
--- @return boolean ok
--- @return string|nil err
function M.set_win_streak(streak)
  if lib == nil then
    return false, "telemetry_native.dll not found (run npm run build:native)"
  end
  if ffi_call.native_export(lib, "telemetry_streak_set") == nil then
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

  return false, ffi_call.read_error(error_buf)
end

return M
