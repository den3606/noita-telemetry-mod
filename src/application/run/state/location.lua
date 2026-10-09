-- Where the player is, as last seen by the biome poll.

---@class LocationState
---@field current_biome string|nil
---@field in_holy_mountain boolean

local M = {}

---@param current_biome? string
---@param in_holy_mountain? boolean
---@return LocationState
function M.new(current_biome, in_holy_mountain)
  return {
    current_biome = current_biome,
    in_holy_mountain = in_holy_mountain == true,
  }
end

return M
