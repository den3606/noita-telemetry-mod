-- pedestal_start: cache finish snapshot before ending cutscene.

local run_state = dofile_once("mods/noita-telemetry/src/core/run/run_state.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local writer = dofile_once("mods/noita-telemetry/src/core/run/writer.lua")
local finish_snapshot = dofile_once("mods/noita-telemetry/src/core/events/finish_snapshot.lua")

local M = {}

function M.emit()
  local state = run_state.get()
  if not writer.is_active() or state.pedestal_snapshot_cached then
    return
  end

  state.pedestal_snapshot_cached = true
  local player = player_reader.get_entity_id() or state.player_entity_id
  finish_snapshot.cache(state, player)
end

return M
