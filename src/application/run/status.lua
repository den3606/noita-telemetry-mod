local sync_settings = dofile_once("mods/noita-telemetry/src/application/run/sync_settings.lua")
local message = dofile_once("mods/noita-telemetry/src/application/messaging.lua")
local token = dofile_once("mods/noita-telemetry/src/adapters/native/token_file.lua")

local M = {}

function M.is_remote()
  local sync = sync_settings.get()
  if sync.enabled ~= true then
    return false
  end
  return token.is_configured()
end

function M.announce_startup()
  local KEYS = message.KEYS
  message.print(KEYS.MSG_STATUS_ENABLED)
  local type_key = M.is_remote() and KEYS.MSG_STATUS_TYPE_REMOTE or KEYS.MSG_STATUS_TYPE_LOCAL
  message.print(type_key)
end

return M
