-- Append to data/scripts/items/shop_effect.lua: observe shop item pickup (buy).
-- generate_shop_item / generate_shop_wand already attach this script; no Entity mutation.
if item_pickup ~= nil then
  local __telemetry_old_item_pickup = item_pickup
  local safe_call = dofile_once("mods/noita-telemetry/src/core/safe_call.lua")
  function item_pickup(entity_item, entity_who_picked, item_name)
    -- ItemCost may be removed during the original pickup; capture cost first.
    -- Emit after original so gold deduction (if any) is visible.
    local cost_before = nil
    if entity_item ~= nil then
      local cost_component = EntityGetFirstComponentIncludingDisabled(entity_item, "ItemCostComponent")
      if cost_component ~= nil then
        local cost = tonumber(ComponentGetValue2(cost_component, "cost"))
        if cost ~= nil and cost > 0 then
          cost_before = cost
        end
      end
    end

    local result = __telemetry_old_item_pickup(entity_item, entity_who_picked, item_name)

    if TelemetryOnShopItemPickup ~= nil then
      safe_call.silent(function()
        TelemetryOnShopItemPickup(entity_item, entity_who_picked, item_name, cost_before)
      end)
    end
    return result
  end
end
