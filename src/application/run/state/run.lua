-- Identity and clocks of the run being recorded.

---@class RunState
---@field start_frame integer frame the run started at (restored on resume)
---@field player_entity_id integer|nil
---@field world_seed integer|nil
---@field started_stamp string|nil UTC "YYYYMMDD-HHMMSS" of the run start
---@field ending_completed_at_start boolean the world was already cleared when the run started
---@field next_timeline_at number playtime_sec of the next timeline_tick
---@field perk_pick_index integer
---@field player_was_dead boolean
---@field poll_counter integer frames since the last poll sweep
---@field end_snapshot table|nil player snapshot captured when the run ended

---@class RunStateInit
---@field start_frame integer
---@field player_entity_id integer|nil
---@field world_seed integer|nil
---@field started_stamp string|nil
---@field ending_completed_at_start boolean
---@field next_timeline_at number

local M = {}

---@param init? RunStateInit
---@return RunState
function M.new(init)
  init = init or { start_frame = 0, ending_completed_at_start = false, next_timeline_at = 0 }
  return {
    start_frame = init.start_frame,
    player_entity_id = init.player_entity_id,
    world_seed = init.world_seed,
    started_stamp = init.started_stamp,
    ending_completed_at_start = init.ending_completed_at_start,
    next_timeline_at = init.next_timeline_at,
    perk_pick_index = 0,
    player_was_dead = false,
    poll_counter = 0,
    end_snapshot = nil,
  }
end

return M
