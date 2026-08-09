-- timeline_tick: periodic snapshot on a fixed playtime interval.

local run_state = dofile_once("mods/noita-telemetry/src/core/run/run_state.lua")
local emit = dofile_once("mods/noita-telemetry/src/core/events/emit.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
local loader = dofile_once("mods/noita-telemetry/src/adapters/native/loader.lua")

local M = {}

function M.maybe_emit(state, player)
  state = state or run_state.get()
  local timing_fields = emit.timing_fields(state)
  if timing_fields.playtime_sec < state.next_timeline_at then
    return
  end

  local snapshot = inventory_reader.get_player_snapshot(player)
  emit.emit(state, "timeline_tick", {
    t_ms = timing_fields.t_ms,
    playtime_sec = timing_fields.playtime_sec,
    biome = snapshot.biome,
    pos = snapshot.position,
    hp = snapshot.hp,
    gold = snapshot.gold,
  })

  state.next_timeline_at = state.next_timeline_at + loader.get_timeline_interval_sec()
end

return M
