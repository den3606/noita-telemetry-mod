-- Perk pickup counts as the player actually picked them.

local M = {}

---@class PerkDefinition
---@field id string
---@field remove_other_perks? string[]

--- The game's per-perk pickup counts without what remove_other_perks added: picking a perk
--- adds 1 to each of those entries to drop them from the pool, without granting them.
---@param game_counts table<string, integer>
---@param perk_list PerkDefinition[]
---@return table<string, integer>
function M.picked_counts(game_counts, perk_list)
  local counts = {}
  for perk_id, count in pairs(game_counts) do
    counts[perk_id] = count
  end
  for _, perk in ipairs(perk_list) do
    local picked = game_counts[perk.id]
    if picked ~= nil and perk.remove_other_perks ~= nil then
      for _, other_id in ipairs(perk.remove_other_perks) do
        if counts[other_id] ~= nil then
          counts[other_id] = counts[other_id] - picked
        end
      end
    end
  end
  for perk_id, count in pairs(counts) do
    if count <= 0 then
      counts[perk_id] = nil
    end
  end
  return counts
end

return M
