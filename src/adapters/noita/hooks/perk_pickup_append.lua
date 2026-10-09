-- Append to data/scripts/perks/perk.lua: queue a perk_pick for the init.lua context.
-- This script runs in the perk entity's Lua state, where init.lua globals are not visible.
if perk_pickup ~= nil then
  local __telemetry_old_perk_pickup = perk_pickup
  local safe_call = dofile_once("mods/noita-telemetry/src/application/safe_call.lua")
  function perk_pickup(entity_item, entity_who_picked, item_name, ...)
    -- Read perk_id before the original pickup kills the perk entity.
    safe_call.silent(function()
      local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
      local frame_clock = dofile_once("mods/noita-telemetry/src/adapters/noita/frame_clock.lua")
      local hook_queue = dofile_once("mods/noita-telemetry/src/adapters/noita/hook_queue.lua")
      local perk_id = inventory_reader.get_perk_id(entity_item)
      if perk_id ~= nil then
        hook_queue.push("perk_pick", { perk_id, entity_who_picked or "", frame_clock.get_frame() })
      end
    end)
    return __telemetry_old_perk_pickup(entity_item, entity_who_picked, item_name, ...)
  end
end
