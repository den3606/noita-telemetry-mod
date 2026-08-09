-- inventory_carry_end: carried entity removed (or run_end close).

local run_state = dofile_once("mods/noita-telemetry/src/core/run/run_state.lua")
local emit = dofile_once("mods/noita-telemetry/src/core/events/emit.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")

local M = {}

function M.emit(state, info, reason, playtime_sec, t_ms)
  state = state or run_state.get()
  emit.emit(state, "inventory_carry_end", {
    t_ms = t_ms,
    playtime_sec = playtime_sec,
    entity_id = info.entity_id,
    item_id = info.item_id,
    item_type = info.item_type,
    reason = reason,
  })
end

function M.close_open_carries(state)
  state = state or run_state.get()
  local timing = emit.timing_fields(state)
  for _, info in pairs(state.prev_carried or {}) do
    M.emit(state, info, "run_end", timing.playtime_sec, timing.t_ms)
  end
  state.prev_carried = {}
end

--- Emit ends for entities no longer carried, then advance prev_carried.
--- Call after inventory_carry_start.maybe_emit on the same poll tick.
function M.maybe_emit(state, player, current)
  state = state or run_state.get()
  current = current or inventory_reader.get_carried_entities(player)
  local previous = state.prev_carried or {}
  local timing = emit.timing_fields(state)

  for entity_id, info in pairs(previous) do
    if current[entity_id] == nil then
      M.emit(state, info, "removed", timing.playtime_sec, timing.t_ms)
    end
  end

  state.prev_carried = current
  run_state.remember_wands(state, inventory_reader.get_wands(player))
end

return M
