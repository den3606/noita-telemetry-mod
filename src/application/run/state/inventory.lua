-- What the player held at the last poll, so the next poll can diff against it.
-- last_wands survives the frame the player dies in, when the wands can no longer be read.

---@class InventoryState
---@field prev_ids table<integer, boolean> top-level inventory entity ids
---@field prev_carried table<integer, table> carried entities, keyed by entity id
---@field last_gold number
---@field last_wands table[]|nil copy of the last non-empty wand list

local M = {}

---@param prev_ids? table<integer, boolean>
---@param gold? number
---@return InventoryState
function M.new(prev_ids, gold)
  return {
    prev_ids = prev_ids or {},
    prev_carried = {},
    last_gold = gold or 0,
    last_wands = nil,
  }
end

local function copy_wand_stats(stats)
  if stats == nil then
    return nil
  end
  return {
    capacity = stats.capacity,
    recharge_time = stats.recharge_time,
    mana_max = stats.mana_max,
    mana_charge_speed = stats.mana_charge_speed,
    spread = stats.spread,
    speed_multiplier = stats.speed_multiplier,
  }
end

local function copy_list(values)
  local copy = {}
  for index, value in ipairs(values or {}) do
    copy[index] = value
  end
  return copy
end

local function copy_wands(wands)
  local copy = {}
  for i, wand in ipairs(wands) do
    local spells = copy_list(wand.spells)
    copy[i] = {
      entity_id = wand.entity_id,
      name = wand.name,
      spells = spells,
      always_cast = copy_list(wand.always_cast),
      spell_count = wand.spell_count or #spells,
      stats = copy_wand_stats(wand.stats),
    }
  end
  return copy
end

---@param inventory InventoryState
---@param wands table[]|nil
function M.remember_wands(inventory, wands)
  if wands ~= nil and #wands > 0 then
    inventory.last_wands = copy_wands(wands)
  end
end

--- Fills an empty wand list from memory; a snapshot that has wands refreshes the memory instead.
---@param inventory InventoryState
---@param snapshot table|nil
---@return table|nil
function M.apply_wand_fallback(inventory, snapshot)
  if snapshot == nil then
    return nil
  end
  if snapshot.wands ~= nil and #snapshot.wands > 0 then
    M.remember_wands(inventory, snapshot.wands)
    return snapshot
  end
  if inventory.last_wands ~= nil and #inventory.last_wands > 0 then
    snapshot.wands = copy_wands(inventory.last_wands)
    snapshot.wand_count = #snapshot.wands
  end
  return snapshot
end

return M
