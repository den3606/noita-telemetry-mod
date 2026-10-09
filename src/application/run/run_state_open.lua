-- Rebuilds run_state from the game at the moment a run opens (start or resume). The lifecycle
-- sub-state survives: it gates the opening itself.

local location = dofile_once("mods/noita-telemetry/src/application/run/state/location.lua")
local holy_mountain = dofile_once("mods/noita-telemetry/src/application/run/state/holy_mountain.lua")
local inventory = dofile_once("mods/noita-telemetry/src/application/run/state/inventory.lua")
local run = dofile_once("mods/noita-telemetry/src/application/run/state/run.lua")
local frame_clock = dofile_once("mods/noita-telemetry/src/adapters/noita/frame_clock.lua")
local session_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/session_reader.lua")
local world_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/world_reader.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
local loader = dofile_once("mods/noita-telemetry/src/adapters/native/loader.lua")
local biome_rules = dofile_once("mods/noita-telemetry/src/domain/biome.lua")
local timeline = dofile_once("mods/noita-telemetry/src/domain/timeline.lua")
local timing = dofile_once("mods/noita-telemetry/src/libs/timing.lua")

local M = {}

---@param state RunStateTable
---@param player integer
---@param scan? table inventory_reader.scan_inventory result, to avoid reading the inventory twice
function M.reset(state, player, scan)
  local start_frame = frame_clock.get_frame()
  local playtime_sec = timing.elapsed_sec(frame_clock.get_frame(), start_frame)
  -- boot already validated the native interval, so this only fires on a broken DLL.
  local interval_sec = assert(loader.get_timeline_interval_sec())
  state.run = run.new({
    start_frame = start_frame,
    player_entity_id = player,
    world_seed = session_reader.get_world_seed(),
    started_stamp = os.date("!%Y%m%d-%H%M%S") --[[@as string]],
    ending_completed_at_start = session_reader.is_ending_completed(),
    next_timeline_at = timeline.first_tick_at(playtime_sec, interval_sec),
  })
  local biome = world_reader.get_biome(player)
  state.location = location.new(biome, biome_rules.is_holy_mountain(biome))
  state.holy_mountain = holy_mountain.new(player_reader.get_gold(player))
  local inventory_ids = scan ~= nil and scan.inventory_ids or inventory_reader.get_inventory_entity_ids(player)
  state.inventory = inventory.new(inventory_ids, player_reader.get_gold(player))
end

return M
