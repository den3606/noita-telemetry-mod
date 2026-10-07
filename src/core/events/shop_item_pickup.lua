-- shop_item_pickup: one queued shop_effect.lua item_pickup (HM shop buy) from core/hook_queue.lua.
-- Sole buy path for vanilla generate_shop_* stock. Steal stays on polls/shop_action.

local run_state = dofile_once("mods/noita-telemetry/src/core/run/run_state.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
local steal_debug = dofile_once("mods/noita-telemetry/src/core/run/steal_debug.lua")
local writer = dofile_once("mods/noita-telemetry/src/core/run/writer.lua")
local shop_action = dofile_once("mods/noita-telemetry/src/core/events/polls/shop_action.lua")
local shop_pending = dofile_once("mods/noita-telemetry/src/core/events/polls/shop_pending.lua")

local M = {}

--- fields: { entity_item, picker_entity_id, cost_before } as pushed by the shop_effect hook.
function M.emit(fields)
  if not writer.is_active() then
    return
  end

  local entity_item = tonumber(fields[1])
  local entity_who_picked = tonumber(fields[2])
  local cost_before = tonumber(fields[3])

  local state = run_state.get()
  if not state.in_holy_mountain then
    return
  end

  local player = player_reader.get_entity_id() or state.player_entity_id
  if player == nil then
    return
  end
  if entity_who_picked ~= nil and entity_who_picked ~= player then
    return
  end
  if entity_item == nil then
    return
  end
  if state.emitted_shop_buy_entities[entity_item] then
    return
  end

  local gold_after = player_reader.get_gold(player)
  local gold_delta = math.max(0, state.last_gold - gold_after)
  -- Steal / free pickup: gold did not drop. Poll steal path still owns these.
  -- Do not trust ItemCost alone — it can still be present on stealable pickups.
  if gold_delta <= 0 then
    return
  end

  local gold_spent = cost_before
  if gold_spent == nil then
    gold_spent = gold_delta
  end

  local description = inventory_reader.describe_item(entity_item)
  state.emitted_shop_buy_entities[entity_item] = true
  state.holy_mountain_spent = state.holy_mountain_spent + gold_spent
  steal_debug.log_shop_buy(state.last_gold, gold_after, 1)
  shop_action.emit(state, {
    action = "buy",
    gold_spent = gold_spent,
    gold_after = gold_after,
    item_id = description.item_id,
    item_type = description.item_type,
    stole = false,
  })
  shop_pending.remove_match(state, description.item_id, description.item_type)
  -- Advance last_gold so the same-frame steal poll does not see a false spend.
  state.last_gold = gold_after
end

return M
