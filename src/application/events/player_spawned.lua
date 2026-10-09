-- player_spawned: OnPlayerSpawned; starts, resumes or skips the run via run_lifecycle.

local run_state = dofile_once("mods/noita-telemetry/src/application/run/run_state.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local session_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/session_reader.lua")
local writer = dofile_once("mods/noita-telemetry/src/application/run/writer.lua")
local run_lifecycle = dofile_once("mods/noita-telemetry/src/application/events/run_lifecycle.lua")
local message = dofile_once("mods/noita-telemetry/src/application/messaging.lua")

local M = {}

--- Returns an i18n key when this world should not start/resume ntel recording.
local function skip_recording_reason()
  if session_reader.get_ng_plus() > 0 then
    return message.KEYS.MSG_RUN_SKIPPED_NG_PLUS
  end
  if session_reader.is_ending_completed() then
    return message.KEYS.MSG_RUN_SKIPPED_ENDING_COMPLETED
  end
  return nil
end

function M.emit(player_entity_id)
  local state = run_state.get()
  if not writer.is_active() and state.lifecycle.waiting_for_player then
    state.lifecycle.waiting_for_player = false
    -- NG+ and post-clear (ending already completed) worlds are not recorded.
    local skip_key = skip_recording_reason()
    if skip_key ~= nil then
      state.lifecycle.resuming = false
      run_lifecycle.abandon(state, skip_key)
      return
    end
    if state.lifecycle.resuming then
      state.lifecycle.resuming = false
      run_lifecycle.resume(state, player_entity_id)
    else
      run_lifecycle.start(state, player_entity_id)
    end
  end

  if writer.is_active() then
    state.run.player_entity_id = player_entity_id
    state.run.player_was_dead = player_reader.is_dead(player_entity_id)
  end
end

return M
