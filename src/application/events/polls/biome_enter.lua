-- biome_enter: biome transition detection, including Holy Mountain enter/exit routing.

local run_state = dofile_once("mods/noita-telemetry/src/application/run/run_state.lua")
local emit = dofile_once("mods/noita-telemetry/src/application/events/emit.lua")
local world_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/world_reader.lua")
local biome_transition = dofile_once("mods/noita-telemetry/src/domain/biome_transition.lua")
local holy_mountain_enter = dofile_once("mods/noita-telemetry/src/application/events/polls/holy_mountain_enter.lua")
local holy_mountain_exit = dofile_once("mods/noita-telemetry/src/application/events/polls/holy_mountain_exit.lua")

---@class BiomeEnterEvent : GameplayEventBase
---@field from_biome string

local M = {}

function M.maybe_emit(state, player, biome)
  state = state or run_state.get()
  local change = biome_transition.diff(state.location.current_biome, biome, state.location.in_holy_mountain)

  if change == nil then
    return
  end

  if change.kind == "init" then
    state.location.current_biome = change.biome
    return
  end

  state.location.current_biome = change.to
  local timing_fields = emit.timing_fields(state)
  ---@type BiomeEnterEvent
  local event = {
    t_ms = timing_fields.t_ms,
    playtime_sec = timing_fields.playtime_sec,
    biome = change.to,
    from_biome = change.from or "",
    pos = world_reader.get_position(player),
  }
  emit.emit(state, "biome_enter", event)

  if change.hm == "enter" then
    holy_mountain_enter.emit(state, player)
  elseif change.hm == "reenter" then
    holy_mountain_exit.emit(state, player)
    holy_mountain_enter.emit(state, player)
  elseif change.hm == "exit" then
    holy_mountain_exit.emit(state, player)
  end
end

return M
