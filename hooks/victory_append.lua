-- Runs at the end of sampo_start_ending_sequence.lua when the player completes the work.
if GameHasFlagRun("ending_game_completed") and telemetry_on_victory ~= nil then
  telemetry_on_victory()
end
