-- Runs at the end of sampo_start_ending_sequence.lua when the player completes the work.
if GameHasFlagRun("ending_game_completed") and TelemetryOnVictory ~= nil then
  local safe_call = dofile_once("mods/noita-telemetry/src/core/safe_call.lua")
  safe_call.silent(TelemetryOnVictory)
end
