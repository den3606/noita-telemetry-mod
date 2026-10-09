-- run_start: the opening events of a new run, in order. run_lifecycle.start opens the run file
-- and session first.

local emit = dofile_once("mods/noita-telemetry/src/application/events/emit.lua")
local holy_mountain_enter = dofile_once("mods/noita-telemetry/src/application/events/polls/holy_mountain_enter.lua")
local inventory_carry_start = dofile_once("mods/noita-telemetry/src/application/events/polls/inventory_carry_start.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local world_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/world_reader.lua")
local session_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/session_reader.lua")
local snapshot_shape = dofile_once("mods/noita-telemetry/src/domain/snapshot_shape.lua")

---@class RunStartEvent : GameplayEventBase
--- nil only when Noita reports no world seed; the line is then rejected rather than recorded as seed 0.
---@field seed? integer
---@field ng_plus integer
---@field game_mode string
---@field noita_version string
---@field mods_enabled string[]
---@field hp? EventHp
---@field wands WandSnapshot[]
---@field items ItemSnapshot[]

local M = {}

--- run_start, Holy Mountain enter when the run starts inside one, then the items already held.
---@param state RunStateTable
---@param player integer
---@param scan table inventory_reader.scan_inventory result
---@param header RunHeader
function M.emit(state, player, scan, header)
  ---@type RunStartEvent
  local event = {
    t_ms = 0,
    playtime_sec = 0,
    seed = header.seed,
    ng_plus = session_reader.get_ng_plus(),
    game_mode = header.game_mode,
    noita_version = header.noita_version,
    mods_enabled = snapshot_shape.mods(header.mods_enabled),
    pos = world_reader.get_position(player),
    hp = player_reader.get_hp(player),
    wands = snapshot_shape.wands(scan.wands),
    items = snapshot_shape.items(scan.items),
  }
  emit.emit(state, "run_start", event)

  if state.location.in_holy_mountain then
    holy_mountain_enter.emit(state, player)
  end

  inventory_carry_start.seed_initial_carries(state, scan.carried)
end

return M
