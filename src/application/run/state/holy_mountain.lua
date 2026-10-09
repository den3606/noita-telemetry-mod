-- One Holy Mountain visit: rebuilt on every enter, read on exit.

---@class HolyMountainState
---@field enter_gold number gold when the visit started
---@field spent number gold spent on buys and rerolls during the visit
---@field stevari_seen boolean
---@field stevari_killed boolean

local M = {}

---@param enter_gold? number
---@return HolyMountainState
function M.new(enter_gold)
  return {
    enter_gold = enter_gold or 0,
    spent = 0,
    stevari_seen = false,
    stevari_killed = false,
  }
end

return M
