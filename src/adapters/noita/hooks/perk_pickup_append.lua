-- Append to data/scripts/perks/perk.lua: emit perk_pick on perk_pickup.
if perk_pickup ~= nil then
  local __telemetry_old_perk_pickup = perk_pickup
  local safe_call = dofile_once("mods/noita-telemetry/src/core/safe_call.lua")
  function perk_pickup(entity_item, entity_who_picked, item_name, ...)
    -- Capture before the original may kill the perk entity.
    if TelemetryOnPerkPick ~= nil then
      safe_call.silent(function()
        TelemetryOnPerkPick(entity_item, entity_who_picked, item_name)
      end)
    end
    return __telemetry_old_perk_pickup(entity_item, entity_who_picked, item_name, ...)
  end
end
