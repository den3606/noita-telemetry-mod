-- perk_reroll: one queued item_pickup on the perk reroll machine (hooks/perk_reroll_append.lua → adapters/noita/hook_queue.lua).
-- Emits JSONL shop_action with action="reroll" (not a poll).

local run_state = dofile_once("mods/noita-telemetry/src/application/run/run_state.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local writer = dofile_once("mods/noita-telemetry/src/application/run/writer.lua")
local shop_action = dofile_once("mods/noita-telemetry/src/application/events/shop_action.lua")
local gold_rules = dofile_once("mods/noita-telemetry/src/domain/gold.lua")

local M = {}

--- fields: { picker_entity_id, cost } as pushed by the perk_reroll hook.
-- The hook reads the cost because the original item_pickup kills the machine.
function M.emit(fields)
  if not writer.is_active() then
    return
  end

  local state = run_state.get()
  local player = tonumber(fields[1]) or player_reader.get_entity_id() or state.run.player_entity_id
  local gold_after = player_reader.get_gold(player)
  local gold_spent = tonumber(fields[2])
  if gold_spent == nil then
    gold_spent = gold_rules.spent(state.inventory.last_gold, gold_after)
  end

  if state.location.in_holy_mountain then
    state.holy_mountain.spent = state.holy_mountain.spent + gold_spent
  end
  shop_action.emit(state, {
    action = "reroll",
    gold_spent = gold_spent,
    gold_after = gold_after,
    item_id = "",
    item_type = "other",
  })
  state.inventory.last_gold = gold_after
end

return M
