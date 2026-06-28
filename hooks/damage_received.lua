-- Player LuaComponent callback (script_damage_received).

function damage_received(
  damage,
  message,
  entity_thats_responsible,
  is_fatal,
  projectile_thats_responsible
)
  pcall(function()
    local events = dofile_once("mods/noita-telemetry/lib/telemetry/events.lua")
    events.on_damage_received(
      damage,
      message,
      entity_thats_responsible,
      is_fatal,
      projectile_thats_responsible
    )
  end)
end
