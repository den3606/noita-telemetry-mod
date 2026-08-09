-- ng_plus_enter: abandon in-progress recording without upload.

local run_state = dofile_once("mods/noita-telemetry/src/core/run/run_state.lua")
local run_skip = dofile_once("mods/noita-telemetry/src/core/events/run_skip.lua")
local message = dofile_once("mods/noita-telemetry/src/core/messaging.lua")

local M = {}

function M.emit()
  run_skip.skip_recording(run_state.get(), message.KEYS.MSG_RUN_SKIPPED_NG_PLUS)
end

return M
