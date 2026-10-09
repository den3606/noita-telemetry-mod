-- shop_item_pickup: one queued shop_effect.lua item_pickup from adapters/noita/hook_queue.lua.
-- The hook fires on every pickup of a generate_shop_* item, re-pickups included. Only a pickup
-- that still had its ItemCostComponent is a buy: the engine removes it once the item is bought,
-- or as soon as a stealable item leaves the shop. Steals are not tracked (#344).

local run_state = dofile_once("mods/noita-telemetry/src/application/run/run_state.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
local writer = dofile_once("mods/noita-telemetry/src/application/run/writer.lua")
local shop_action = dofile_once("mods/noita-telemetry/src/application/events/shop_action.lua")
local snapshot_shape = dofile_once("mods/noita-telemetry/src/domain/snapshot_shape.lua")

local M = {}

--- fields: { entity_item, picker_entity_id, price } as pushed by the shop_effect hook;
--- price is "" when the item had no ItemCostComponent.
function M.emit(fields)
  if not writer.is_active() then
    return
  end

  local entity_item = tonumber(fields[1])
  local entity_who_picked = tonumber(fields[2])
  local price = tonumber(fields[3])
  if entity_item == nil or price == nil then
    return
  end

  local state = run_state.get()
  local player = player_reader.get_entity_id() or state.run.player_entity_id
  if player == nil then
    return
  end
  if entity_who_picked ~= nil and entity_who_picked ~= player then
    return
  end

  -- The engine takes the gold after the hook ran, so it is gone by the time this drains.
  local gold_after = player_reader.get_gold(player)
  local description = inventory_reader.describe_item(entity_item)
  if state.location.in_holy_mountain then
    state.holy_mountain.spent = state.holy_mountain.spent + price
  end
  -- A wand comes with its spells, so record the wand as bought (#61).
  local bought = inventory_reader.get_wand(entity_item)
  local wand = bought and snapshot_shape.wand(bought)
  shop_action.emit(state, {
    action = "buy",
    gold_before = gold_after + price,
    gold_spent = price,
    gold_after = gold_after,
    item_id = description.item_id,
    item_type = description.item_type,
    wand = wand,
  })
  state.inventory.last_gold = gold_after
end

return M
