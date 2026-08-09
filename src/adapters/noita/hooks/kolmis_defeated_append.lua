-- Append to boss_centipede_update.lua: cache inventory when Kolmisilmä dies.
local __telemetry_check_death = check_death
local safe_call = dofile_once("mods/noita-telemetry/src/core/safe_call.lua")
function check_death()
  local was_dead = is_dead
  __telemetry_check_death()
  if was_dead == false and is_dead == true and TelemetryOnKolmiDefeated ~= nil then
    safe_call.silent(TelemetryOnKolmiDefeated)
  end
end
