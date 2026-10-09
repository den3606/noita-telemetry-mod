-- player_died: emit death row, then finalize as win or lose.

local run_state = dofile_once("mods/noita-telemetry/src/application/run/run_state.lua")
local emit = dofile_once("mods/noita-telemetry/src/application/events/emit.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local world_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/world_reader.lua")
local session_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/session_reader.lua")
local biome_rules = dofile_once("mods/noita-telemetry/src/domain/biome.lua")
local death_cause = dofile_once("mods/noita-telemetry/src/domain/death_cause.lua")
local writer = dofile_once("mods/noita-telemetry/src/application/run/writer.lua")
local run_lifecycle = dofile_once("mods/noita-telemetry/src/application/events/run_lifecycle.lua")

---@class DeathEvent : GameplayEventBase
---@field killed_by string
---@field killed_with string
---@field hp? EventHp

local M = {}

function M.emit(player_entity_id)
  local state = run_state.get()
  if not writer.is_active() or not player_reader.is_dead(player_entity_id) then
    return
  end

  if state.run.player_was_dead then
    return
  end

  state.run.player_was_dead = true
  local pos = world_reader.get_position(player_entity_id)
  local death_biome = world_reader.get_biome(player_entity_id)
  local timing_fields = emit.timing_fields(state)

  ---@type DeathEvent
  local event = {
    t_ms = timing_fields.t_ms,
    playtime_sec = timing_fields.playtime_sec,
    biome = death_biome,
    pos = pos,
    killed_by = death_cause.sanitize_killed_by(session_reader.get_stat("killed_by")),
    killed_with = death_cause.sanitize_killed_with(session_reader.get_stat("killed_by_extra")),
    hp = player_reader.get_hp(player_entity_id),
  }
  emit.emit(state, "death", event)

  -- Dying inside the victory room (or after the ending flag is set) is a clear, not a loss.
  local won = session_reader.is_ending_completed() or biome_rules.is_victory_room(death_biome)
  run_lifecycle.finish(state, player_entity_id, won and "win" or "lose")
end

return M
