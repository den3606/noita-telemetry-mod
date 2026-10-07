-- Append to data/scripts/items/shop_effect.lua: queue a shop_buy for the init.lua context.
-- This script runs in the shop item's Lua state, where init.lua globals are not visible.
-- generate_shop_item / generate_shop_wand already attach this script; no Entity mutation.
if item_pickup ~= nil then
  local __telemetry_old_item_pickup = item_pickup
  local safe_call = dofile_once("mods/noita-telemetry/src/core/safe_call.lua")
  function item_pickup(entity_item, entity_who_picked, item_name)
    -- ItemCost may be removed during the original pickup; capture cost first.
    local cost_before = safe_call.silent(function()
      local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
      return inventory_reader.get_item_shop_cost(entity_item)
    end)

    local result = __telemetry_old_item_pickup(entity_item, entity_who_picked, item_name)

    -- Queue after the original so the gold deduction (if any) is visible on drain.
    safe_call.silent(function()
      local hook_queue = dofile_once("mods/noita-telemetry/src/core/hook_queue.lua")
      if entity_item ~= nil then
        hook_queue.push("shop_buy", { entity_item, entity_who_picked or "", cost_before or "" })
      end
    end)
    return result
  end
end
