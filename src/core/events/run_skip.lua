-- Shared abandon / skip-recording helpers (NG+ and post-clear worlds).

local writer = dofile_once("mods/noita-telemetry/src/core/run/writer.lua")
local session = dofile_once("mods/noita-telemetry/src/core/run/session.lua")
local persistence = dofile_once("mods/noita-telemetry/src/core/run/persistence.lua")
local message = dofile_once("mods/noita-telemetry/src/core/messaging.lua")

local M = {}

function M.abandon_without_upload(state)
  if writer.is_active() then
    writer.end_run()
    writer.discard_pending_upload()
  end
  session.clear()
  persistence.clear()
  state.waiting_for_player = false
  state.run_end_snapshot = nil
  state.last_wands_snapshot = nil
end

function M.skip_recording(state, reason_key)
  M.abandon_without_upload(state)
  message.print(reason_key)
end

return M
