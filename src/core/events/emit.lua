-- Event row assembly + append. Takes run state for enrich / timing; does not own it.

local frame_clock = dofile_once("mods/noita-telemetry/src/adapters/noita/frame_clock.lua")
local world_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/world_reader.lua")
local timing = dofile_once("mods/noita-telemetry/src/libs/timing.lua")
local writer = dofile_once("mods/noita-telemetry/src/core/run/writer.lua")

local M = {}

function M.utc_timestamp()
  if os and os.date then
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
  end
  return "unknown"
end

function M.timing_fields(state)
  local frame = frame_clock.get_frame()
  return {
    t_ms = timing.elapsed_ms(frame, state.run_start_frame),
    playtime_sec = timing.elapsed_sec(frame, state.run_start_frame),
  }
end

function M.enrich_event_fields(state, fields)
  if state.player_entity_id ~= nil then
    if fields.pos == nil then
      fields.pos = world_reader.get_position(state.player_entity_id)
    end
    if fields.biome == nil then
      fields.biome = world_reader.get_biome(state.player_entity_id) or ""
    end
  end
  if fields.biome == nil then
    fields.biome = ""
  end
  return fields
end

function M.emit(state, event_name, fields)
  fields = M.enrich_event_fields(state, fields or {})
  fields.event = event_name
  fields.at = M.utc_timestamp()
  writer.append_event(fields)
end

return M
