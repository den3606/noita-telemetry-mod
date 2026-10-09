-- Gold arithmetic shared by the shop, reroll and carry detection.

local M = {}

--- Gold spent between two reads; picking up gold in between counts as nothing spent.
---@param before number
---@param after number
---@return number
function M.spent(before, after)
  return math.max(0, before - after)
end

return M
