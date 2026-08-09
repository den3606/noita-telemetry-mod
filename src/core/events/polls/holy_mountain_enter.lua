-- holy_mountain_enter: snapshot + shop state reset on HM entry.

local run_state = dofile_once("mods/noita-telemetry/src/core/run/run_state.lua")
local emit = dofile_once("mods/noita-telemetry/src/core/events/emit.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
local steal_debug = dofile_once("mods/noita-telemetry/src/core/run/steal_debug.lua")

local M = {}

function M.emit(state, player)
  local snapshot = inventory_reader.get_player_snapshot(player)
  run_state.remember_wands(state, snapshot.wands)
  state.in_holy_mountain = true
  state.holy_mountain_enter_gold = snapshot.gold
  state.holy_mountain_spent = 0
  state.holy_mountain_stole = false
  state.stevari_seen = false
  state.stevari_killed = false
  state.last_gold = snapshot.gold
  state.prev_inventory_ids = inventory_reader.get_inventory_entity_ids(player)
  state.shop_stock = inventory_reader.scan_shop_stock(player)
  local stock_count = 0
  for _ in pairs(state.shop_stock) do
    stock_count = stock_count + 1
  end
  steal_debug.log_hm_enter(snapshot.gold, stock_count)

  emit.emit(state, "holy_mountain_enter", {
    t_ms = emit.timing_fields(state).t_ms,
    playtime_sec = emit.timing_fields(state).playtime_sec,
    biome = snapshot.biome,
    pos = snapshot.position,
    gold = snapshot.gold,
    hp = snapshot.hp,
    wands = snapshot.wands,
    wand_count = snapshot.wand_count,
    items = snapshot.items,
    item_count = snapshot.item_count,
    perks = snapshot.perks,
  })
end

return M
