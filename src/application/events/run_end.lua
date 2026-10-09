-- run_end: the closing events of a run, in order. run_lifecycle.finish decides when and closes
-- the run file afterwards.
-- Holy Mountain exit, the last biome and open carries come first because polling stops with
-- the run: a run that ends inside the Holy Mountain would never get its exit event otherwise,
-- and the backend closes the visit (and reads its gold spent) from that event.

local emit = dofile_once("mods/noita-telemetry/src/application/events/emit.lua")
local finish_snapshot = dofile_once("mods/noita-telemetry/src/application/events/finish_snapshot.lua")
local biome_enter = dofile_once("mods/noita-telemetry/src/application/events/polls/biome_enter.lua")
local inventory_carry_end = dofile_once("mods/noita-telemetry/src/application/events/polls/inventory_carry_end.lua")
local holy_mountain_exit = dofile_once("mods/noita-telemetry/src/application/events/polls/holy_mountain_exit.lua")
local session_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/session_reader.lua")
local snapshot_shape = dofile_once("mods/noita-telemetry/src/domain/snapshot_shape.lua")

---@class RunEndEvent : GameplayEventBase
---@field result string
---@field hp? EventHp
---@field gold integer
---@field enemies_killed integer
---@field places_visited integer
---@field projectiles_shot integer
---@field wands WandSnapshot[]
---@field items ItemSnapshot[]
---@field perks string[]

local M = {}

local function stat(key)
  return tonumber(session_reader.get_stat(key)) or 0
end

--- Holy Mountain exit (if inside), the last biome, open carries closed, then run_end.
---@param state RunStateTable
---@param player integer|nil
---@param result "win"|"lose"
function M.emit(state, player, result)
  local snapshot = finish_snapshot.resolve(state, player) or finish_snapshot.empty()

  if state.location.in_holy_mountain then
    holy_mountain_exit.emit(state, player, snapshot)
  end

  local finish_biome = snapshot.biome or state.location.current_biome
  biome_enter.maybe_emit(state, player, finish_biome)

  inventory_carry_end.close_open_carries(state)

  local timing_fields = emit.timing_fields(state)
  ---@type RunEndEvent
  local event = {
    t_ms = timing_fields.t_ms,
    playtime_sec = timing_fields.playtime_sec,
    result = result,
    pos = snapshot.position,
    hp = snapshot.hp,
    wands = snapshot_shape.wands(snapshot.wands),
    items = snapshot_shape.items(snapshot.items),
    perks = snapshot_shape.perks(snapshot.perks),
    gold = snapshot.gold,
    enemies_killed = stat("enemies_killed"),
    places_visited = stat("places_visited"),
    projectiles_shot = stat("projectiles_shot"),
  }
  emit.emit(state, "run_end", event)
end

return M
