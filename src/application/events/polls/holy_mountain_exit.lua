-- holy_mountain_exit: emit the exit snapshot and leave the visit.

local emit = dofile_once("mods/noita-telemetry/src/application/events/emit.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
local snapshot_shape = dofile_once("mods/noita-telemetry/src/domain/snapshot_shape.lua")

---@class HolyMountainExitEvent : GameplayEventBase
---@field gold integer
---@field gold_spent_total integer
---@field hp? EventHp
---@field wands WandSnapshot[]
---@field items ItemSnapshot[]
---@field perks string[]

local M = {}

function M.emit(state, player, cached_snapshot)
  if not state.location.in_holy_mountain then
    return
  end

  local snapshot = cached_snapshot or inventory_reader.get_player_snapshot(player)
  ---@type HolyMountainExitEvent
  local event = {
    t_ms = emit.timing_fields(state).t_ms,
    playtime_sec = emit.timing_fields(state).playtime_sec,
    pos = snapshot.position,
    gold = snapshot.gold,
    gold_spent_total = state.holy_mountain.spent,
    hp = snapshot.hp,
    wands = snapshot_shape.wands(snapshot.wands),
    items = snapshot_shape.items(snapshot.items),
    perks = snapshot_shape.perks(snapshot.perks),
  }
  emit.emit(state, "holy_mountain_exit", event)

  state.location.in_holy_mountain = false
end

return M
