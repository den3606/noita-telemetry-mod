-- Appended to the end of sampo_start_ending_sequence.lua (mountain altar + The Work endings).
-- Cache inventory while the ending sequence still has a live player entity.
if TelemetryOnPedestalStart ~= nil then
  local safe_call = dofile_once("mods/noita-telemetry/src/core/safe_call.lua")
  safe_call.silent(TelemetryOnPedestalStart)
end
