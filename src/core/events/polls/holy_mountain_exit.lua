-- holy_mountain_exit: flush pending shop actions, then emit exit snapshot.

local emit = dofile_once("mods/noita-telemetry/src/core/events/emit.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
local steal_debug = dofile_once("mods/noita-telemetry/src/core/run/steal_debug.lua")
local shop_action = dofile_once("mods/noita-telemetry/src/core/events/polls/shop_action.lua")

local M = {}

function M.emit(state, player, cached_snapshot)
  if not state.in_holy_mountain then
    return
  end

  local gold = cached_snapshot and cached_snapshot.gold or player_reader.get_gold(player)
  local current_inventory_ids = inventory_reader.get_inventory_entity_ids(player)
  steal_debug.log_hm_exit_flush(gold)
  shop_action.track_shop_stock_changes(state, player)
  shop_action.maybe_emit(state, player, gold, current_inventory_ids)

  local snapshot = cached_snapshot or inventory_reader.get_player_snapshot(player)
  emit.emit(state, "holy_mountain_exit", {
    t_ms = emit.timing_fields(state).t_ms,
    playtime_sec = emit.timing_fields(state).playtime_sec,
    pos = snapshot.position,
    gold = snapshot.gold,
    gold_spent_total = state.holy_mountain_spent,
    hp = snapshot.hp,
    wands = snapshot.wands,
    items = snapshot.items,
    perks = snapshot.perks,
  })

  steal_debug.log_hm_exit_done(state.holy_mountain_spent)

  state.in_holy_mountain = false
  state.shop_stock = {}
end

return M
