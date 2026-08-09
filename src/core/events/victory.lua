-- victory: finalize run as a win (pedestal / ending paths).

local run_state = dofile_once("mods/noita-telemetry/src/core/run/run_state.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local session_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/session_reader.lua")
local writer = dofile_once("mods/noita-telemetry/src/core/run/writer.lua")
local finish_snapshot = dofile_once("mods/noita-telemetry/src/core/events/finish_snapshot.lua")
local run_finalize = dofile_once("mods/noita-telemetry/src/core/events/run_finalize.lua")

local M = {}

function M.emit()
  local state = run_state.get()
  local player = player_reader.get_entity_id() or state.player_entity_id
  if player == nil or not writer.is_active() then
    return
  end

  -- Pedestal / kolmis hooks usually cache first; refresh here if the ending path skipped them.
  if state.run_end_snapshot == nil then
    finish_snapshot.cache(state, player)
  end

  -- Finish synchronously: mountain altar endings (Pure/Peaceful) can reload the world
  -- before the next OnWorldPostUpdate. Also poll ending_game_completed for altar paths where
  -- the player survives (Pure, Toxic Immunity) and sampo_start_ending_sequence never returns.
  -- NG+ is handled separately via ng_plus_enter (abandon without upload).
  run_finalize.finish_run(state, player, "win")
end

--- Poll fallback for endings that set ending_game_completed without sampo_start_ending_sequence.
function M.maybe_finish_on_ending_flag()
  local state = run_state.get()
  if not writer.is_active() then
    return
  end
  if state.ending_game_completed_at_start then
    return
  end
  if not session_reader.is_ending_completed() then
    return
  end

  M.emit()
end

return M
