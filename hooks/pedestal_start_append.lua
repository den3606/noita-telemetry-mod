-- Append to sampo_start_ending_sequence.lua: cache inventory when the ending pedestal activates.
if telemetry_on_pedestal_start ~= nil then
  telemetry_on_pedestal_start()
end
