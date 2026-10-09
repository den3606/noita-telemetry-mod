-- inventory_carry_end: carried entity removed (or run_end close).

local run_state = dofile_once("mods/noita-telemetry/src/application/run/run_state.lua")
local inventory = dofile_once("mods/noita-telemetry/src/application/run/state/inventory.lua")
local emit = dofile_once("mods/noita-telemetry/src/application/events/emit.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
local inventory_diff = dofile_once("mods/noita-telemetry/src/domain/inventory_diff.lua")

---@class InventoryCarryEndEvent : GameplayEventBase
---@field entity_id integer
---@field item_id string
---@field item_type string
---@field reason string

local M = {}

function M.emit(state, info, reason, playtime_sec, t_ms)
  state = state or run_state.get()
  ---@type InventoryCarryEndEvent
  local event = {
    t_ms = t_ms,
    playtime_sec = playtime_sec,
    entity_id = info.entity_id,
    item_id = info.item_id,
    item_type = info.item_type,
    reason = reason,
  }
  emit.emit(state, "inventory_carry_end", event)
end

function M.close_open_carries(state)
  state = state or run_state.get()
  local timing = emit.timing_fields(state)
  for _, info in pairs(state.inventory.prev_carried or {}) do
    M.emit(state, info, "run_end", timing.playtime_sec, timing.t_ms)
  end
  state.inventory.prev_carried = {}
end

--- Emit ends for entities no longer carried, then advance prev_carried.
--- Call after inventory_carry_start.maybe_emit on the same poll tick.
function M.maybe_emit(state, player, current)
  state = state or run_state.get()
  current = current or inventory_reader.get_carried_entities(player)
  local previous = state.inventory.prev_carried or {}
  local timing = emit.timing_fields(state)

  for _, entity_id in ipairs(inventory_diff.removed_keys(current, previous)) do
    M.emit(state, previous[entity_id], "removed", timing.playtime_sec, timing.t_ms)
  end

  state.inventory.prev_carried = current
  inventory.remember_wands(state.inventory, inventory_reader.get_wands(player))
end

return M
