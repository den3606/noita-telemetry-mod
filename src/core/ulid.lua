-- Run ULID via native DLL only. No Lua fallback: recording already requires
-- the DLL at boot, so a failed generate_id aborts instead of inventing an id.

local ulid_native = dofile_once("mods/noita-telemetry/src/adapters/native/ulid.lua")
local message = dofile_once("mods/noita-telemetry/src/core/messaging.lua")
local noita_message = dofile_once("mods/noita-telemetry/src/adapters/noita/message.lua")

local M = {}

local function abort(key, vars)
  message.error(key, vars)
  noita_message.error(message.format(key, vars))
end

--- Returns a ULID string, or aborts on native failure / missing DLL.
function M.generate()
  local id, err = ulid_native.generate_id()
  if id ~= nil and id ~= "" then
    return id
  end
  abort(message.KEYS.MSG_ERROR_ULID_NATIVE_FAILED, { err = tostring(err or "") })
end

return M
