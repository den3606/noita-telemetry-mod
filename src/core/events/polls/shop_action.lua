-- shop_action: steal detection inside Holy Mountain (poll).
-- buy is hook-driven: events/shop_item_pickup.lua (shop_effect).
-- reroll is hook-driven: events/perk_reroll.lua.

local emit = dofile_once("mods/noita-telemetry/src/core/events/emit.lua")
local world_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/world_reader.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
local steal_debug = dofile_once("mods/noita-telemetry/src/core/run/steal_debug.lua")
local shop_pending = dofile_once("mods/noita-telemetry/src/core/events/polls/shop_pending.lua")

local M = {}

local function find_new_inventory_ids(current_ids, previous_ids)
  local new_ids = {}
  for entity_id in pairs(current_ids) do
    if previous_ids[entity_id] ~= true then
      new_ids[#new_ids + 1] = entity_id
    end
  end
  return new_ids
end

function M.emit(state, fields)
  local pos = nil
  if state.player_entity_id ~= nil then
    pos = world_reader.get_position(state.player_entity_id)
  end

  emit.emit(state, "shop_action", {
    t_ms = emit.timing_fields(state).t_ms,
    playtime_sec = emit.timing_fields(state).playtime_sec,
    pos = pos,
    action = fields.action,
    gold_before = state.last_gold,
    gold_spent = fields.gold_spent,
    gold_after = fields.gold_after,
    item_id = fields.item_id or "",
    item_type = fields.item_type or "other",
    stole = fields.stole or false,
  })
  steal_debug.log_shop_action_emitted(
    fields.action,
    fields.item_id or "",
    fields.item_type or "other",
    fields.stole or false
  )
end

function M.try_emit_steal_on_carry(state, player, gold, entity_id, info)
  if state.emitted_steal_entities[entity_id] then
    return false
  end
  -- Buy hook advances last_gold in the same frame; do not reclassify that pickup as steal.
  if state.emitted_shop_buy_entities[entity_id] then
    return false
  end

  local gold_spent = math.max(0, state.last_gold - gold)
  if gold_spent > 0 then
    return false
  end

  local matched_pending = nil
  local steal = false
  if inventory_reader.has_shop_cost(entity_id) then
    steal = true
  else
    matched_pending = shop_pending.remove_match(state, info.item_id, info.item_type)
    if matched_pending ~= nil then
      steal = true
    end
  end

  if not steal then
    return false
  end

  state.emitted_steal_entities[entity_id] = true
  state.holy_mountain_stole = true
  M.emit(state, {
    action = "steal",
    gold_spent = 0,
    gold_after = gold,
    item_id = info.item_id,
    item_type = info.item_type,
    stole = true,
  })
  steal_debug.log_pickup_steal(info.item_id, info.item_type, matched_pending ~= nil, #state.pending_shop_removals)
  return true
end

local function emit_shop_steals(state, player, gold, new_items, current_inventory_ids)
  local steal_candidates = {}
  for _, item_entity_id in ipairs(new_items) do
    if not state.emitted_shop_buy_entities[item_entity_id] then
      steal_candidates[#steal_candidates + 1] = item_entity_id
    end
  end
  if #steal_candidates == 0 then
    state.shop_stock = inventory_reader.scan_shop_stock(player)
    return
  end

  local stock_before = state.shop_stock
  local current_stock = inventory_reader.scan_shop_stock(player)
  local removed_shop = inventory_reader.find_removed_shop_stock(
    stock_before,
    current_stock,
    current_inventory_ids
  )
  state.shop_stock = current_stock

  local steals = inventory_reader.match_shop_steals(removed_shop, steal_candidates)
  local cost_by_entity = {}
  local matched_steal = {}
  for _, item_entity_id in ipairs(steal_candidates) do
    cost_by_entity[item_entity_id] = inventory_reader.get_item_shop_cost(item_entity_id)
    matched_steal[item_entity_id] = false
    if inventory_reader.has_shop_cost(item_entity_id) then
      local already_matched = false
      for _, matched_id in ipairs(steals) do
        if matched_id == item_entity_id then
          already_matched = true
          break
        end
      end
      if not already_matched then
        steals[#steals + 1] = item_entity_id
      end
    end
  end
  for _, item_entity_id in ipairs(steals) do
    matched_steal[item_entity_id] = true
  end

  steal_debug.log_shop_steal_attempt({
    new_items = steal_candidates,
    removed_shop = removed_shop,
    stock_before = stock_before,
    stock_after = current_stock,
    cost_by_entity = cost_by_entity,
    matched_steal = matched_steal,
    steal_count = #steals,
  })

  if #steals == 0 then
    return
  end

  state.holy_mountain_stole = true
  for _, item_entity_id in ipairs(steals) do
    if not state.emitted_steal_entities[item_entity_id]
      and not state.emitted_shop_buy_entities[item_entity_id]
    then
      local description = inventory_reader.describe_item(item_entity_id)
      state.emitted_steal_entities[item_entity_id] = true
      shop_pending.remove_match(state, description.item_id, description.item_type)
      M.emit(state, {
        action = "steal",
        gold_spent = 0,
        gold_after = gold,
        item_id = description.item_id,
        item_type = description.item_type,
        stole = true,
      })
    end
  end
end

function M.track_shop_stock_changes(state, player)
  if player == nil then
    return
  end

  local current_stock = inventory_reader.scan_shop_stock(player)
  local disappeared = inventory_reader.find_disappeared_shop_stock(state.shop_stock, current_stock)
  if #disappeared > 0 then
    for _, meta in ipairs(disappeared) do
      state.pending_shop_removals[#state.pending_shop_removals + 1] = meta
    end
    steal_debug.log_pending_added(disappeared, #state.pending_shop_removals)
  end
  state.shop_stock = current_stock
end

function M.maybe_emit(state, player, gold, current_inventory_ids)
  local new_top_level_items = find_new_inventory_ids(current_inventory_ids, state.prev_inventory_ids)

  if not state.in_holy_mountain then
    if #new_top_level_items > 0 then
      steal_debug.log_shop_skip("not_in_holy_mountain", gold, #new_top_level_items, false)
    end
    return
  end

  local gold_spent = math.max(0, state.last_gold - gold)

  if gold_spent > 0 then
    -- buy / reroll hooks own spend events; refresh stock so steal matching stays consistent.
    state.shop_stock = inventory_reader.scan_shop_stock(player)
  elseif #new_top_level_items > 0 then
    -- Steal matching still keys off top-level inventory; wand-slot steals use
    -- try_emit_steal_on_carry when inventory_carry_start fires.
    emit_shop_steals(state, player, gold, new_top_level_items, current_inventory_ids)
  else
    state.shop_stock = inventory_reader.scan_shop_stock(player)
  end
end

return M
