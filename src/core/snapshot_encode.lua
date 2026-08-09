local M = {}

local function quote(value)
  return string.format("%q", tostring(value or ""))
end

local function encode_string_array(values)
  if values == nil or #values == 0 then
    return "[]"
  end

  local parts = {}
  for index, value in ipairs(values) do
    parts[index] = quote(value)
  end
  return "[" .. table.concat(parts, ",") .. "]"
end

local function encode_wand(wand)
  local stats = wand.stats or {}
  local spells = encode_string_array(wand.spells or {})
  return string.format(
    '{"entity_id":%d,"name":%s,"spells":%s,"spell_count":%d,"stats":{"capacity":%s,"recharge_time":%s,"mana_max":%s,"mana_charge_speed":%s,"spread":%s,"speed_multiplier":%s}}',
    wand.entity_id or 0,
    quote(wand.name or ""),
    spells,
    wand.spell_count or 0,
    tostring(stats.capacity or 0),
    tostring(stats.recharge_time or 0),
    tostring(stats.mana_max or 0),
    tostring(stats.mana_charge_speed or 0),
    tostring(stats.spread or 0),
    tostring(stats.speed_multiplier or 1)
  )
end

function M.encode_wands(wands)
  if wands == nil or #wands == 0 then
    return "[]"
  end

  local parts = {}
  for index, wand in ipairs(wands) do
    parts[index] = encode_wand(wand)
  end
  return "[" .. table.concat(parts, ",") .. "]"
end

local function encode_item(item)
  if item.item_type ~= nil and item.item_type ~= "" then
    return string.format(
      '{"id":%s,"material":%s,"count":%d,"item_type":%s}',
      quote(item.id or ""),
      quote(item.material or ""),
      item.count or 1,
      quote(item.item_type)
    )
  end

  return string.format(
    '{"id":%s,"material":%s,"count":%d}',
    quote(item.id or ""),
    quote(item.material or ""),
    item.count or 1
  )
end

function M.encode_items(items)
  if items == nil or #items == 0 then
    return "[]"
  end

  local parts = {}
  for index, item in ipairs(items) do
    parts[index] = encode_item(item)
  end
  return "[" .. table.concat(parts, ",") .. "]"
end

function M.encode_perks(perks)
  return encode_string_array(perks or {})
end

function M.encode_mods(mods)
  return encode_string_array(mods or {})
end

return M
