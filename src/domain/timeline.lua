-- When timeline_tick fires: on every interval boundary of playtime.

local M = {}

--- The first boundary strictly after playtime_sec, so a resumed run does not tick twice for one slot.
---@param playtime_sec number
---@param interval_sec number
---@return number
function M.first_tick_at(playtime_sec, interval_sec)
  return math.floor(playtime_sec / interval_sec + 1) * interval_sec
end

return M
