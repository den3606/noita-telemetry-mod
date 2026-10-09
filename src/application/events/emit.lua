-- Event row assembly + append. Takes run state for enrich / timing; does not own it.

local frame_clock = dofile_once("mods/noita-telemetry/src/adapters/noita/frame_clock.lua")
local world_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/world_reader.lua")
local timing = dofile_once("mods/noita-telemetry/src/libs/timing.lua")
local writer = dofile_once("mods/noita-telemetry/src/application/run/writer.lua")

---@class EventPos
---@field x number
---@field y number

---@class EventHp
---@field current number
---@field max number

--- Fields every gameplay event carries. emit() adds `event` and `at`, and fills
--- `pos` / `biome` from the player when the emitter leaves them out.
---@class GameplayEventBase
---@field t_ms integer
---@field playtime_sec integer
---@field biome? string
---@field pos? EventPos

local M = {}

function M.utc_timestamp()
  if os and os.date then
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
  end
  return "unknown"
end

function M.timing_fields(state)
  return M.timing_fields_at(state, frame_clock.get_frame())
end

function M.timing_fields_at(state, frame)
  return {
    t_ms = timing.elapsed_ms(frame, state.run.start_frame),
    playtime_sec = timing.elapsed_sec(frame, state.run.start_frame),
  }
end

function M.enrich_event_fields(state, fields)
  if state.run.player_entity_id ~= nil then
    if fields.pos == nil then
      fields.pos = world_reader.get_position(state.run.player_entity_id)
    end
    if fields.biome == nil then
      fields.biome = world_reader.get_biome(state.run.player_entity_id) or ""
    end
  end
  if fields.biome == nil then
    fields.biome = ""
  end
  return fields
end

---@param event_name string
---@param fields GameplayEventBase
function M.emit(state, event_name, fields)
  fields = M.enrich_event_fields(state, fields or {})
  fields.event = event_name
  fields.at = M.utc_timestamp()
  writer.append_event(fields)
end

return M
