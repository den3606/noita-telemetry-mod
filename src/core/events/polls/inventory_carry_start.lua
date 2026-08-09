-- inventory_carry_start: new carried entity detected (top-level or wand slot).

local run_state = dofile_once("mods/noita-telemetry/src/core/run/run_state.lua")
local emit = dofile_once("mods/noita-telemetry/src/core/events/emit.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local world_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/world_reader.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
local steal_debug = dofile_once("mods/noita-telemetry/src/core/run/steal_debug.lua")
local shop_action = dofile_once("mods/noita-telemetry/src/core/events/polls/shop_action.lua")
local shop_pending = dofile_once("mods/noita-telemetry/src/core/events/polls/shop_pending.lua")

local M = {}

function M.emit(state, info, playtime_sec, t_ms)
  state = state or run_state.get()
  local event = {
    t_ms = t_ms,
    playtime_sec = playtime_sec,
    entity_id = info.entity_id,
    item_id = info.item_id,
    item_type = info.item_type,
    container = info.container,
  }
  if info.wand_entity_id ~= nil then
    event.wand_entity_id = info.wand_entity_id
  end
  emit.emit(state, "inventory_carry_start", event)
end

function M.seed_initial_carries(state, carried)
  state = state or run_state.get()
  state.prev_carried = carried or {}
  for _, info in pairs(state.prev_carried) do
    M.emit(state, info, 0, 0)
  end
end

--- Emit starts for newly carried entities. Caller must update state.prev_carried
--- after inventory_carry_end.maybe_emit (same poll tick).
function M.maybe_emit(state, player, current)
  state = state or run_state.get()
  current = current or inventory_reader.get_carried_entities(player)
  local previous = state.prev_carried or {}
  local timing = emit.timing_fields(state)

  for entity_id, info in pairs(current) do
    if previous[entity_id] == nil then
      local gold = player_reader.get_gold(player)
      local shop_cost = inventory_reader.get_item_shop_cost(entity_id)
      local gold_spent = math.max(0, state.last_gold - gold)
      steal_debug.log_new_carry({
        entity_id = entity_id,
        item_id = info.item_id,
        item_type = info.item_type,
        container = info.container,
        biome = world_reader.get_biome(player) or "",
        in_holy_mountain = state.in_holy_mountain,
        gold = gold,
        last_gold = state.last_gold,
        shop_cost = shop_cost,
        in_tracked_stock = state.shop_stock[entity_id] ~= nil,
        pending_count = #state.pending_shop_removals,
        would_steal_now = gold_spent == 0
          and (shop_cost ~= nil
            or state.shop_stock[entity_id] ~= nil
            or shop_pending.matches_item(state, info.item_id, info.item_type)),
        playtime_sec = timing.playtime_sec,
      })
      shop_action.try_emit_steal_on_carry(state, player, gold, entity_id, info)
      M.emit(state, info, timing.playtime_sec, timing.t_ms)
    end
  end

  return current
end

return M
