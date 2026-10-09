-- Which kind of item an entity is, from what the adapter read off it.

local M = {}

---@class ItemFacts
---@field is_wand boolean
---@field action_id? string set on spell cards
---@field has_material boolean holds a material inventory (flasks, pouches)
---@field name string item name, also the id of non-spell items

--- Wand first, then spell, then potion (by material, else by name), else other.
---@param facts ItemFacts
---@return "wand"|"spell"|"potion"|"other" item_type
---@return string item_id
function M.classify(facts)
  if facts.is_wand then
    return "wand", facts.name
  end
  if facts.action_id ~= nil and facts.action_id ~= "" then
    return "spell", facts.action_id
  end
  if facts.has_material or string.find(facts.name, "potion", 1, true) ~= nil then
    return "potion", facts.name
  end
  return "other", facts.name
end

return M
