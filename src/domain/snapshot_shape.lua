-- Shapes wand / item / perk / mod lists into the tables written to the .run file:
-- only the recorded fields, with fixed defaults. JSON encoding is libs/json.lua's job.

local M = {}

---@class WandStats
---@field capacity number
---@field recharge_time number
---@field mana_max number
---@field mana_charge_speed number
---@field spread number
---@field speed_multiplier number

---@class WandSnapshot
---@field entity_id integer
---@field name string
---@field spells string[] slotted spells, in slot order
---@field always_cast string[] spells attached to the wand outside its slots
---@field spell_count integer
---@field stats WandStats

---@class ItemSnapshot
---@field id string
---@field material string
---@field count integer
---@field item_type? string

---@param values string[]|nil
---@return string[]
local function string_list(values)
  local list = {}
  for index, value in ipairs(values or {}) do
    list[index] = tostring(value)
  end
  return list
end

---@param wand table
---@return WandSnapshot
local function wand_snapshot(wand)
  local stats = wand.stats or {}
  return {
    entity_id = wand.entity_id or 0,
    name = wand.name or "",
    spells = string_list(wand.spells),
    always_cast = string_list(wand.always_cast),
    spell_count = wand.spell_count or 0,
    stats = {
      capacity = stats.capacity or 0,
      recharge_time = stats.recharge_time or 0,
      mana_max = stats.mana_max or 0,
      mana_charge_speed = stats.mana_charge_speed or 0,
      spread = stats.spread or 0,
      speed_multiplier = stats.speed_multiplier or 1,
    },
  }
end

---@param item table
---@return ItemSnapshot
local function item_snapshot(item)
  ---@type ItemSnapshot
  local snapshot = {
    id = item.id or "",
    material = item.material or "",
    count = item.count or 1,
  }
  if item.item_type ~= nil and item.item_type ~= "" then
    snapshot.item_type = item.item_type
  end
  return snapshot
end

---@param wand table
---@return WandSnapshot
function M.wand(wand)
  return wand_snapshot(wand)
end

---@param wands table[]|nil
---@return WandSnapshot[]
function M.wands(wands)
  local list = {}
  for index, wand in ipairs(wands or {}) do
    list[index] = wand_snapshot(wand)
  end
  return list
end

---@param items table[]|nil
---@return ItemSnapshot[]
function M.items(items)
  local list = {}
  for index, item in ipairs(items or {}) do
    list[index] = item_snapshot(item)
  end
  return list
end

---@param perks string[]|nil
---@return string[]
function M.perks(perks)
  return string_list(perks)
end

---@param mods string[]|nil
---@return string[]
function M.mods(mods)
  return string_list(mods)
end

return M
