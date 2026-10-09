-- Diff of two polls of an entity-keyed table (inventory ids or carried entities).

local M = {}

--- Keys present now but not in the previous poll. Order is unspecified.
---@generic K
---@param current table<K, any>
---@param previous table<K, any>
---@return K[]
function M.added_keys(current, previous)
  local added = {}
  for key in pairs(current) do
    if previous[key] == nil then
      added[#added + 1] = key
    end
  end
  return added
end

--- Keys in the previous poll that are gone now. Order is unspecified.
---@generic K
---@param current table<K, any>
---@param previous table<K, any>
---@return K[]
function M.removed_keys(current, previous)
  return M.added_keys(previous, current)
end

return M
