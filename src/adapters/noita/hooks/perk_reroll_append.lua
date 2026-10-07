-- Append to data/scripts/perks/perk_reroll.lua: queue a perk_reroll for the init.lua context.
-- This script runs in the reroll machine's Lua state, where init.lua globals are not visible.
if item_pickup ~= nil then
  local __telemetry_old_item_pickup = item_pickup
  local safe_call = dofile_once("mods/noita-telemetry/src/core/safe_call.lua")
  function item_pickup(entity_item, entity_who_picked, item_name)
    -- Read the cost before the original pickup kills the machine.
    safe_call.silent(function()
      local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
      local hook_queue = dofile_once("mods/noita-telemetry/src/core/hook_queue.lua")
      local cost = inventory_reader.get_item_shop_cost(entity_item)
      hook_queue.push("perk_reroll", { entity_who_picked or "", cost or "" })
    end)
    return __telemetry_old_item_pickup(entity_item, entity_who_picked, item_name)
  end
end
