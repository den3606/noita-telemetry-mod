-- inventory_carry_start: new carried entity detected (top-level or wand slot).

local run_state = dofile_once("mods/noita-telemetry/src/application/run/run_state.lua")
local emit = dofile_once("mods/noita-telemetry/src/application/events/emit.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
local inventory_diff = dofile_once("mods/noita-telemetry/src/domain/inventory_diff.lua")

---@class InventoryCarryStartEvent : GameplayEventBase
---@field entity_id integer
---@field item_id string
---@field item_type string
---@field container string
---@field wand_entity_id? integer

local M = {}

function M.emit(state, info, playtime_sec, t_ms)
  state = state or run_state.get()
  ---@type InventoryCarryStartEvent
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
  state.inventory.prev_carried = carried or {}
  for _, info in pairs(state.inventory.prev_carried) do
    M.emit(state, info, 0, 0)
  end
end

--- Emit starts for newly carried entities. Caller must update state.inventory.prev_carried
--- after inventory_carry_end.maybe_emit (same poll tick).
function M.maybe_emit(state, player, current)
  state = state or run_state.get()
  current = current or inventory_reader.get_carried_entities(player)
  local previous = state.inventory.prev_carried or {}
  local timing = emit.timing_fields(state)

  for _, entity_id in ipairs(inventory_diff.added_keys(current, previous)) do
    local info = current[entity_id]
    M.emit(state, info, timing.playtime_sec, timing.t_ms)
  end

  return current
end

return M
