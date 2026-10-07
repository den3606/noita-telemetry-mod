-- perk_pick: one queued perk_pickup (hooks/perk_pickup_append.lua → core/hook_queue.lua).
-- JSONL event name remains "perk_pick" (not a poll).

local run_state = dofile_once("mods/noita-telemetry/src/core/run/run_state.lua")
local emit = dofile_once("mods/noita-telemetry/src/core/events/emit.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local world_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/world_reader.lua")
local writer = dofile_once("mods/noita-telemetry/src/core/run/writer.lua")

local M = {}

--- fields: { perk_id, picker_entity_id, frame } as pushed by the perk_pickup hook.
function M.emit(fields)
  if not writer.is_active() then
    return
  end

  local perk_id = fields[1]
  local picker = tonumber(fields[2])
  local frame = tonumber(fields[3])
  if perk_id == nil or perk_id == "" or frame == nil then
    return
  end

  local state = run_state.get()
  local player = player_reader.get_entity_id() or state.player_entity_id
  if player == nil then
    return
  end
  if picker ~= nil and picker ~= player then
    return
  end

  state.telemetry_perk_pick_index = state.telemetry_perk_pick_index + 1
  local timing_fields = emit.timing_fields_at(state, frame)
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
