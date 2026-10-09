-- holy_mountain_enter: snapshot + visit state reset on HM entry.

local inventory = dofile_once("mods/noita-telemetry/src/application/run/state/inventory.lua")
local holy_mountain = dofile_once("mods/noita-telemetry/src/application/run/state/holy_mountain.lua")
local emit = dofile_once("mods/noita-telemetry/src/application/events/emit.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
local snapshot_shape = dofile_once("mods/noita-telemetry/src/domain/snapshot_shape.lua")

---@class HolyMountainEnterEvent : GameplayEventBase
---@field gold integer
---@field hp? EventHp
---@field wands WandSnapshot[]
---@field wand_count integer
---@field items ItemSnapshot[]
---@field item_count integer
---@field perks string[]

local M = {}

function M.emit(state, player)
  local snapshot = inventory_reader.get_player_snapshot(player)
  inventory.remember_wands(state.inventory, snapshot.wands)
  state.location.in_holy_mountain = true
  state.holy_mountain = holy_mountain.new(snapshot.gold)
  state.inventory.last_gold = snapshot.gold
  state.inventory.prev_ids = inventory_reader.get_inventory_entity_ids(player)

  ---@type HolyMountainEnterEvent
  local event = {
    t_ms = emit.timing_fields(state).t_ms,
    playtime_sec = emit.timing_fields(state).playtime_sec,
    biome = snapshot.biome,
    pos = snapshot.position,
    gold = snapshot.gold,
    hp = snapshot.hp,
    wands = snapshot_shape.wands(snapshot.wands),
    wand_count = snapshot.wand_count,
    items = snapshot_shape.items(snapshot.items),
    item_count = snapshot.item_count,
    perks = snapshot_shape.perks(snapshot.perks),
  }
  emit.emit(state, "holy_mountain_enter", event)
end

return M
