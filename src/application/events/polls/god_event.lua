-- god_event: Stevari (Kolmisilma's guardian) angered / killed.

local run_state = dofile_once("mods/noita-telemetry/src/application/run/run_state.lua")
local emit = dofile_once("mods/noita-telemetry/src/application/events/emit.lua")
local world_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/world_reader.lua")

---@class GodEventEvent : GameplayEventBase
---@field angered boolean
---@field killed boolean

local M = {}

function M.maybe_emit(state, player)
  state = state or run_state.get()
  local stevari_id = world_reader.find_stevari_near(player)

  if stevari_id ~= nil and not state.holy_mountain.stevari_seen then
    state.holy_mountain.stevari_seen = true
    local timing_fields = emit.timing_fields(state)
    ---@type GodEventEvent
    local event = {
      t_ms = timing_fields.t_ms,
      playtime_sec = timing_fields.playtime_sec,
      pos = world_reader.get_position(player),
      angered = true,
      killed = false,
      biome = world_reader.get_biome(player),
    }
    emit.emit(state, "god_event", event)
  end

  if state.holy_mountain.stevari_seen and not state.holy_mountain.stevari_killed then
    local alive = stevari_id ~= nil and world_reader.is_stevari_alive(stevari_id)
    if not alive then
      state.holy_mountain.stevari_killed = true
      local timing_fields = emit.timing_fields(state)
      ---@type GodEventEvent
      local event = {
        t_ms = timing_fields.t_ms,
        playtime_sec = timing_fields.playtime_sec,
        pos = world_reader.get_position(player),
        angered = true,
        killed = true,
        biome = world_reader.get_biome(player),
      }
      emit.emit(state, "god_event", event)
    end
  end
end

return M
