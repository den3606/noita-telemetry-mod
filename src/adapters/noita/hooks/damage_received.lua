-- Player LuaComponent callback (script_damage_received).

local safe_call = dofile_once("mods/noita-telemetry/src/core/safe_call.lua")

function damage_received(
  damage,
  message,
  entity_thats_responsible,
  is_fatal,
  projectile_thats_responsible
)
  if TelemetryOnDamageReceived == nil then
    return
  end

  safe_call.silent(function()
    TelemetryOnDamageReceived(damage, message, entity_thats_responsible, is_fatal, projectile_thats_responsible)
  end)
end
