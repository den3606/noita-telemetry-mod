-- Append to data/scripts/perks/perk_reroll.lua: emit shop_action.reroll on machine use.
if item_pickup ~= nil then
  local __telemetry_old_item_pickup = item_pickup
  function item_pickup(entity_item, entity_who_picked, item_name)
    if telemetry_on_perk_reroll ~= nil then
      telemetry_on_perk_reroll(entity_item, entity_who_picked)
    end
    return __telemetry_old_item_pickup(entity_item, entity_who_picked, item_name)
  end
end
