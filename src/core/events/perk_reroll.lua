-- perk_reroll: one queued item_pickup on the perk reroll machine (hooks/perk_reroll_append.lua → core/hook_queue.lua).
-- Emits JSONL shop_action with action="reroll" (not a poll).

local run_state = dofile_once("mods/noita-telemetry/src/core/run/run_state.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local steal_debug = dofile_once("mods/noita-telemetry/src/core/run/steal_debug.lua")
local writer = dofile_once("mods/noita-telemetry/src/core/run/writer.lua")
local shop_action = dofile_once("mods/noita-telemetry/src/core/events/polls/shop_action.lua")

local M = {}

--- fields: { picker_entity_id, cost } as pushed by the perk_reroll hook.
-- The hook reads the cost because the original item_pickup kills the machine.
function M.emit(fields)
  if not writer.is_active() then
    return
  end

  local state = run_state.get()
  local player = tonumber(fields[1]) or player_reader.get_entity_id() or state.player_entity_id
  local gold_after = player_reader.get_gold(player)
  local gold_spent = tonumber(fields[2])
  if gold_spent == nil then
    gold_spent = math.max(0, state.last_gold - gold_after)
  end

  steal_debug.log_shop_reroll(state.last_gold, gold_after)
  state.pending_shop_removals = {}
  if state.in_holy_mountain then
    state.holy_mountain_spent = state.holy_mountain_spent + gold_spent
  end
  shop_action.emit(state, {
    action = "reroll",
    gold_spent = gold_spent,
    gold_after = gold_after,
    item_id = "",
    item_type = "other",
    stole = false,
  })
  -- Advance last_gold so the same-frame steal poll does not see a false spend.
  state.last_gold = gold_after
end

return M
