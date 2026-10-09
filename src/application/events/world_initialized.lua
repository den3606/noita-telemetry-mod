-- world_initialized: OnWorldInitialized; run_lifecycle.await_player readies the coming player spawn.

local run_state = dofile_once("mods/noita-telemetry/src/application/run/run_state.lua")
local run_lifecycle = dofile_once("mods/noita-telemetry/src/application/events/run_lifecycle.lua")

local M = {}

function M.emit()
  run_lifecycle.await_player(run_state.get())
end

return M
