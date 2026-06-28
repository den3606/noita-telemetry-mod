-- Append to boss_centipede_update.lua: cache inventory when Kolmisilmä dies.
local __telemetry_check_death = check_death
function check_death()
  local was_dead = is_dead
  __telemetry_check_death()
  if was_dead == false and is_dead == true and telemetry_on_kolmis_defeated ~= nil then
    telemetry_on_kolmis_defeated()
  end
end
