-- victory: finalize run as a win once ending_game_completed is set (polled from post_update).
-- Not hooked: sampo_start_ending_sequence.lua runs in another Lua state, and some
-- altar endings (Pure, Toxic Immunity) never finish that script, so the flag is the only common signal.

local run_state = dofile_once("mods/noita-telemetry/src/application/run/run_state.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local session_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/session_reader.lua")
local writer = dofile_once("mods/noita-telemetry/src/application/run/writer.lua")
local run_lifecycle = dofile_once("mods/noita-telemetry/src/application/events/run_lifecycle.lua")

local M = {}

function M.emit()
  local state = run_state.get()
  local player = player_reader.get_entity_id() or state.run.player_entity_id
  if player == nil or not writer.is_active() then
    return
  end

  -- NG+ is handled separately via ng_plus_enter (abandon without upload).
  run_lifecycle.finish(state, player, "win")
end

function M.maybe_finish_on_ending_flag()
  local state = run_state.get()
  if not writer.is_active() then
    return
  end
  if state.run.ending_completed_at_start then
    return
  end
  if not session_reader.is_ending_completed() then
    return
  end

  M.emit()
end

return M
