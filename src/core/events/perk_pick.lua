-- perk_pick: perk_pickup hook (hooks/perk_pickup_append.lua → TelemetryOnPerkPick).
-- JSONL event name remains "perk_pick" (not a poll).

local run_state = dofile_once("mods/noita-telemetry/src/core/run/run_state.lua")
local emit = dofile_once("mods/noita-telemetry/src/core/events/emit.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local world_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/world_reader.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
local writer = dofile_once("mods/noita-telemetry/src/core/run/writer.lua")

local M = {}

function M.emit(entity_item, entity_who_picked, _item_name)
  if not writer.is_active() then
    return
  end

  local state = run_state.get()
  local player = player_reader.get_entity_id() or state.player_entity_id
  if player == nil then
    return
  end
  if entity_who_picked ~= nil and entity_who_picked ~= player then
    return
  end

  local perk_id = inventory_reader.get_perk_id(entity_item)
  if perk_id == nil or not inventory_reader.should_emit_telemetry_perk_pick(perk_id) then
    return
  end

  state.telemetry_perk_pick_index = state.telemetry_perk_pick_index + 1
  local timing_fields = emit.timing_fields(state)
  emit.emit(state, "perk_pick", {
    t_ms = timing_fields.t_ms,
    playtime_sec = timing_fields.playtime_sec,
    pos = world_reader.get_position(player),
    perk_id = perk_id,
    perk_index = state.telemetry_perk_pick_index,
    options_offered = {},
    biome = world_reader.get_biome(player),
  })
end

return M
