-- ULID generation via telemetry_generate_id. Kept separate from run_file.lua:
-- id minting is not part of the .run lifecycle.

local ffi = require("ffi")
local KEYS = dofile_once("mods/noita-telemetry/src/resources/messages.lua").KEYS
local loader = dofile_once("mods/noita-telemetry/src/adapters/native/loader.lua")

local lib = loader.lib

local M = {}

function M.generate_id()
  if lib == nil then
    return nil, KEYS.MSG_ERROR_NATIVE_DLL_MISSING
  end

  local out_buf = ffi.new("char[?]", 27)
  local result = lib.telemetry_generate_id(out_buf, 27)
  if result == 0 then
    return ffi.string(out_buf)
  end

  return nil, "telemetry_generate_id failed"
end

return M
