-- Append to data/scripts/perks/perk_reroll.lua: emit shop_action.reroll on machine use.
if item_pickup ~= nil then
  local __telemetry_old_item_pickup = item_pickup
  local safe_call = dofile_once("mods/noita-telemetry/src/core/safe_call.lua")
  function item_pickup(entity_item, entity_who_picked, item_name)
    if TelemetryOnPerkReroll ~= nil then
      safe_call.silent(function()
        TelemetryOnPerkReroll(entity_item, entity_who_picked)
      end)
    end
    return __telemetry_old_item_pickup(entity_item, entity_who_picked, item_name)
  end
end
