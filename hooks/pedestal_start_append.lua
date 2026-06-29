-- Appended to the end of sampo_start_ending_sequence.lua (mountain altar + The Work endings).
-- Cache inventory while the ending sequence still has a live player entity.
if telemetry_on_pedestal_start ~= nil then
  telemetry_on_pedestal_start()
end
