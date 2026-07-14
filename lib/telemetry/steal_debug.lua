-- Temporary steal-detection probe; delete with events.lua hooks when done investigating.
local M = {}

local PREFIX = "[NoitaTelemetry:steal]"

local function line(message)
  print(PREFIX .. " " .. message)
end

local function count_stock(stock)
  local count = 0
  for _ in pairs(stock or {}) do
    count = count + 1
  end
  return count
end

local function format_removed_list(removed)
  local parts = {}
  for _, meta in ipairs(removed or {}) do
    parts[#parts + 1] = string.format(
      "%s:%s@e%d",
      tostring(meta.item_type or "?"),
      tostring(meta.item_id or "?"),
      tonumber(meta.entity_id) or 0
    )
  end
  if #parts == 0 then
    return "(none)"
  end
  return table.concat(parts, ", ")
end

local function format_entity_ids(entity_ids)
  local parts = {}
  for _, entity_id in ipairs(entity_ids or {}) do
    parts[#parts + 1] = tostring(entity_id)
  end
  if #parts == 0 then
    return "(none)"
  end
  return table.concat(parts, ", ")
end

function M.log_hm_enter(gold, stock_count)
  line(string.format(
    "HM enter gold=%s tracked_shop_stock=%d",
    tostring(gold),
    stock_count
  ))
end

function M.log_hm_exit_flush(gold)
  line(string.format("HM exit flush gold=%s", tostring(gold)))
end

function M.log_hm_exit_done(gold_spent_total)
  line(string.format("HM exit done gold_spent_total=%s", tostring(gold_spent_total)))
end

function M.log_shop_skip(reason, gold, new_inventory_count, in_holy_mountain)
  line(string.format(
    "shop poll SKIP reason=%s in_hm=%s gold=%s new_top_inventory=%d",
    reason,
    tostring(in_holy_mountain),
    tostring(gold),
    new_inventory_count
  ))
end

function M.log_shop_buy(gold_before, gold_after, new_inventory_count)
  line(string.format(
    "shop poll BUY gold %s->%s new_top_inventory=%d",
    tostring(gold_before),
    tostring(gold_after),
    new_inventory_count
  ))
end

function M.log_shop_reroll(gold_before, gold_after)
  line(string.format(
    "shop poll REROLL gold %s->%s",
    tostring(gold_before),
    tostring(gold_after)
  ))
end

function M.log_shop_steal_attempt(fields)
  line(string.format(
    "shop steal attempt new_top_inventory=%s removed_shop=[%s] tracked_stock_before=%d tracked_stock_after=%d",
    format_entity_ids(fields.new_items),
    format_removed_list(fields.removed_shop),
    count_stock(fields.stock_before),
    count_stock(fields.stock_after)
  ))

  for _, item_entity_id in ipairs(fields.new_items or {}) do
    line(string.format(
      "  new entity=%d shop_cost=%s matched_steal=%s",
      item_entity_id,
      fields.cost_by_entity[item_entity_id] == nil and "nil" or tostring(fields.cost_by_entity[item_entity_id]),
      tostring(fields.matched_steal[item_entity_id] == true)
    ))
  end

  if fields.steal_count == 0 then
    line("shop steal result NONE (no shop_action steal emitted)")
  else
    line(string.format("shop steal result EMIT count=%d", fields.steal_count))
  end
end

function M.log_new_carry(fields)
  if fields.playtime_sec == 0 then
    return
  end

  line(string.format(
    "carry start entity=%d %s:%s container=%s biome=%s in_hm=%s gold=%s last_gold=%s shop_cost=%s in_tracked_stock=%s pending=%d would_steal_now=%s",
    fields.entity_id,
    tostring(fields.item_type),
    tostring(fields.item_id),
    tostring(fields.container),
    tostring(fields.biome),
    tostring(fields.in_holy_mountain),
    tostring(fields.gold),
    tostring(fields.last_gold),
    fields.shop_cost == nil and "nil" or tostring(fields.shop_cost),
    tostring(fields.in_tracked_stock),
    fields.pending_count or 0,
    tostring(fields.would_steal_now)
  ))
end

function M.log_pending_added(disappeared, pending_total)
  line(string.format(
    "pending +%d [%s] total_pending=%d",
    #disappeared,
    format_removed_list(disappeared),
    pending_total
  ))
end

function M.log_pickup_steal(item_id, item_type, matched_pending, pending_remaining)
  line(string.format(
    "pickup STEAL %s:%s via_%s pending_remaining=%d",
    tostring(item_type),
    tostring(item_id),
    matched_pending and "pending" or "shop_cost",
    pending_remaining
  ))
end

function M.log_shop_action_emitted(action, item_id, item_type, stole)
  line(string.format(
    "shop_action emitted action=%s item=%s:%s stole=%s",
    tostring(action),
    tostring(item_type),
    tostring(item_id),
    tostring(stole)
  ))
end

return M
