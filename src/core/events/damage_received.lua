-- damage_received: player LuaComponent script_damage_received callback.
-- JSONL event name remains "damage_taken".

local run_state = dofile_once("mods/noita-telemetry/src/core/run/run_state.lua")
local emit = dofile_once("mods/noita-telemetry/src/core/events/emit.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local world_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/world_reader.lua")
local damage_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/damage_reader.lua")
local writer = dofile_once("mods/noita-telemetry/src/core/run/writer.lua")

local M = {}

function M.emit(
  damage_amount,
  message,
  entity_thats_responsible,
  _is_fatal,
  projectile_thats_responsible
)
  if not writer.is_active() then
    return
  end

  local amount = tonumber(damage_amount)
  if amount == nil or amount <= 0 then
    return
  end

  local state = run_state.get()
  local player = state.player_entity_id or player_reader.get_entity_id()
  if player == nil then
    return
  end

  local pos = world_reader.get_position(player)
  local hp = player_reader.get_hp(player)
  local timing = emit.timing_fields(state)

  emit.emit(state, "damage_taken", {
    t_ms = timing.t_ms,
    playtime_sec = timing.playtime_sec,
    amount = amount,
    source = damage_reader.resolve_source(entity_thats_responsible, message),
    damage_type = damage_reader.classify_damage_type(
      entity_thats_responsible,
      projectile_thats_responsible,
      player
    ),
    biome = world_reader.get_biome(player),
    pos = pos,
    hp_after = hp ~= nil and hp.current or nil,
  })
end

return M
