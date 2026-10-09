-- OnWorldPostUpdate: session/upload polling plus the throttled polls/* sweep.
-- Called from application/events.lua (init.lua never loads this module directly).

local run_state = dofile_once("mods/noita-telemetry/src/application/run/run_state.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local world_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/world_reader.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
local loader = dofile_once("mods/noita-telemetry/src/adapters/native/loader.lua")
local session = dofile_once("mods/noita-telemetry/src/application/run/session.lua")
local writer = dofile_once("mods/noita-telemetry/src/application/run/writer.lua")
local biome_enter = dofile_once("mods/noita-telemetry/src/application/events/polls/biome_enter.lua")
local god_event = dofile_once("mods/noita-telemetry/src/application/events/polls/god_event.lua")
local timeline_tick = dofile_once("mods/noita-telemetry/src/application/events/polls/timeline_tick.lua")
local inventory_carry_start = dofile_once("mods/noita-telemetry/src/application/events/polls/inventory_carry_start.lua")
local inventory_carry_end = dofile_once("mods/noita-telemetry/src/application/events/polls/inventory_carry_end.lua")
local victory = dofile_once("mods/noita-telemetry/src/application/events/victory.lua")
local ng_plus_enter = dofile_once("mods/noita-telemetry/src/application/events/ng_plus_enter.lua")
local hook_messages = dofile_once("mods/noita-telemetry/src/application/events/hook_messages.lua")

local M = {}

function M.run()
  session.poll_open()
  writer.poll_upload()
  victory.maybe_finish_on_ending_flag()
  ng_plus_enter.maybe_abandon_on_ng_plus()

  if not writer.is_active() then
    -- No run starts in this world until the next world_initialized; drop what hooks queued.
    if not run_state.get().lifecycle.waiting_for_player then
      hook_messages.discard_pending()
    end
    return
  end

  local player = player_reader.get_entity_id()
  if player == nil then
    return
  end

  local state = run_state.get()
  state.run.player_entity_id = player
  -- Every frame (not throttled); messages queued before the run opened wait until now.
  hook_messages.dispatch_pending()
  state.run.poll_counter = state.run.poll_counter + 1
  if state.run.poll_counter < loader.get_poll_interval_frames() then
    return
  end
  state.run.poll_counter = 0

  local biome_id = world_reader.get_biome(player)
  local gold = player_reader.get_gold(player)
  local current_inventory_ids = inventory_reader.get_inventory_entity_ids(player)

  biome_enter.maybe_emit(state, player, biome_id)
  god_event.maybe_emit(state, player)
  timeline_tick.maybe_emit(state, player)

  local current_carried = inventory_reader.get_carried_entities(player)
  inventory_carry_start.maybe_emit(state, player, current_carried)
  inventory_carry_end.maybe_emit(state, player, current_carried)

  state.inventory.prev_ids = current_inventory_ids
  state.inventory.last_gold = gold
end

return M
