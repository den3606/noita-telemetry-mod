-- ng_plus_enter: abandon the run in progress without upload once the game enters NG+.
-- Polled from post_update: do_newgame_plus runs in the ending entity's Lua state, and
-- entering NG+ does not set ending_game_completed, so the NG+ count is the signal.

local run_state = dofile_once("mods/noita-telemetry/src/application/run/run_state.lua")
local session_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/session_reader.lua")
local writer = dofile_once("mods/noita-telemetry/src/application/run/writer.lua")
local run_lifecycle = dofile_once("mods/noita-telemetry/src/application/events/run_lifecycle.lua")
local message = dofile_once("mods/noita-telemetry/src/application/messaging.lua")

local M = {}

function M.maybe_abandon_on_ng_plus()
  if not writer.is_active() then
    return
  end
  -- Runs only start outside NG+ (player_spawned skips NG+ worlds), so any count means we entered it.
  if session_reader.get_ng_plus() <= 0 then
    return
  end

  run_lifecycle.abandon(run_state.get(), message.KEYS.MSG_RUN_SKIPPED_NG_PLUS)
end

return M
