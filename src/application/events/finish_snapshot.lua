-- Finish-snapshot helpers shared by victory and run finalize.
-- Not an event emitter: JSONL rows are written by player_died / victory.

local run_state = dofile_once("mods/noita-telemetry/src/application/run/run_state.lua")
local inventory = dofile_once("mods/noita-telemetry/src/application/run/state/inventory.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")

local M = {}

function M.capture(state, player)
  state = state or run_state.get()
  if player == nil then
    return nil
  end
  return inventory.apply_wand_fallback(state.inventory, inventory_reader.get_player_snapshot(player))
end

function M.resolve(state, player)
  state = state or run_state.get()
  if state.run.end_snapshot ~= nil then
    return state.run.end_snapshot
  end
  return M.capture(state, player)
end

function M.empty()
  return {
    pos = { x = 0, y = 0 },
    hp = { current = 0, max = 0 },
    wands = {},
    items = {},
    perks = {},
    gold = 0,
  }
end

return M
