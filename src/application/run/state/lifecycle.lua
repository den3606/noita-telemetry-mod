-- Gate between worlds: run_lifecycle.await_player sets it, player_spawned consumes it.

---@class LifecycleState
---@field waiting_for_player boolean
---@field resuming boolean set when the world loads with a run still open (save & quit)

local M = {}

---@return LifecycleState
function M.new()
  return {
    waiting_for_player = false,
    resuming = false,
  }
end

return M
