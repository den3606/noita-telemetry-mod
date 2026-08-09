-- Shared run finalize + upload sequence used by player_died / victory.

local emit = dofile_once("mods/noita-telemetry/src/core/events/emit.lua")
local session_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/session_reader.lua")
local writer = dofile_once("mods/noita-telemetry/src/core/run/writer.lua")
local session = dofile_once("mods/noita-telemetry/src/core/run/session.lua")
local persistence = dofile_once("mods/noita-telemetry/src/core/run/persistence.lua")
local finish_snapshot = dofile_once("mods/noita-telemetry/src/core/events/finish_snapshot.lua")
local biome_enter = dofile_once("mods/noita-telemetry/src/core/events/polls/biome_enter.lua")
local inventory_carry_end = dofile_once("mods/noita-telemetry/src/core/events/polls/inventory_carry_end.lua")
local holy_mountain_exit = dofile_once("mods/noita-telemetry/src/core/events/polls/holy_mountain_exit.lua")
local safe_call = dofile_once("mods/noita-telemetry/src/core/safe_call.lua")

local M = {}

local function finalize_run(state)
  writer.end_run()
  writer.process_pending_upload()
  session.clear()
  persistence.clear()
  state.waiting_for_player = false
  state.run_end_snapshot = nil
  state.last_wands_snapshot = nil
end

local function complete_finish_run(state, player, result)
  if not writer.is_active() then
    finalize_run(state)
    return
  end

  local snapshot = finish_snapshot.resolve(state, player) or finish_snapshot.empty()

  safe_call.silent(function()
    if state.in_holy_mountain then
      holy_mountain_exit.emit(state, player, snapshot)
    end

    local finish_biome = snapshot.biome or state.current_biome
    biome_enter.maybe_emit(state, player, finish_biome)

    inventory_carry_end.close_open_carries(state)

    local timing_fields = emit.timing_fields(state)
    emit.emit(state, "run_end", {
      t_ms = timing_fields.t_ms,
      playtime_sec = timing_fields.playtime_sec,
      result = result,
      pos = snapshot.position,
      hp = snapshot.hp,
      wands = snapshot.wands,
      items = snapshot.items,
      perks = snapshot.perks,
      gold = snapshot.gold,
      enemies_killed = session_reader.get_stat("enemies_killed"),
      places_visited = session_reader.get_stat("places_visited"),
      projectiles_shot = session_reader.get_stat("projectiles_shot"),
    })
  end)

  finalize_run(state)
end

function M.finish_run(state, player, result)
  if not writer.is_active() then
    return
  end

  if state.run_end_snapshot == nil and player ~= nil then
    state.run_end_snapshot = finish_snapshot.capture(state, player)
  end

  complete_finish_run(state, player, result)
end

return M
