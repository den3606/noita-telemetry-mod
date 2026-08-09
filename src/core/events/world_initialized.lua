-- world_initialized: gate waiting_for_player / resume detection before spawn.

local run_state = dofile_once("mods/noita-telemetry/src/core/run/run_state.lua")
local writer = dofile_once("mods/noita-telemetry/src/core/run/writer.lua")
local persistence = dofile_once("mods/noita-telemetry/src/core/run/persistence.lua")

local M = {}

function M.emit()
  local state = run_state.get()
  if writer.is_active() then
    return
  end

  local persisted = persistence.load()
  if persisted ~= nil and persistence.is_run_file_active(persisted.run_id) then
    state.resuming = true
  else
    persistence.clear()
    state.resuming = false
  end

  state.waiting_for_player = true
end

return M
