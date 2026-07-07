local collector = dofile_once("mods/noita-telemetry/lib/telemetry/collector.lua")

local M = {}

local FRAMES_PER_SECOND = 60
local perk_list_ready = false
local perk_game_effects = nil

-- Perks auto-granted with another altar pick in the same frame (Noita bundled perks).
local bundled_perk_suppressors = {
  PROTECTION_EXPLOSION = { "EXPLODING_CORPSES" },
}

local function ensure_perk_meta()
  if perk_game_effects ~= nil then
    return
  end
  perk_game_effects = {}
  if not ensure_perk_list() then
    return
  end
  for _, perk in ipairs(perk_list) do
    if perk.id and perk.game_effect then
      perk_game_effects[perk.id] = perk.game_effect
    end
  end
end

local function is_suppressed_telemetry_perk(perk_id, active_ids)
  ensure_perk_meta()
  for other_id, _ in pairs(active_ids) do
    if other_id ~= perk_id then
      if perk_game_effects and perk_game_effects[other_id] == perk_id then
        return true
      end
      local suppressors = bundled_perk_suppressors[perk_id]
      if suppressors then
        for _, parent_id in ipairs(suppressors) do
          if parent_id == other_id then
            return true
          end
        end
      end
    end
  end
  return false
end

function M.filter_telemetry_perk_picks(pick_ids)
  if #pick_ids <= 1 then
    return pick_ids
  end

  local active = {}
  for _, perk_id in ipairs(pick_ids) do
    active[perk_id] = true
  end

  local filtered = {}
  for _, perk_id in ipairs(pick_ids) do
    if not is_suppressed_telemetry_perk(perk_id, active) then
      filtered[#filtered + 1] = perk_id
    end
  end
  return filtered
end

local function ensure_perk_list()
  if perk_list_ready then
    return true
  end
  local ok = pcall(function()
    dofile_once("data/scripts/perks/perk_list.lua")
  end)
  perk_list_ready = ok
  return ok
end

local function get_component(entity_id, component_name)
  return EntityGetFirstComponentIncludingDisabled(entity_id, component_name)
end

local function is_alive_entity(entity_id)
  return entity_id ~= nil and EntityGetIsAlive(entity_id)
end

local function is_wand(entity_id)
  local ability = get_component(entity_id, "AbilityComponent")
  if ability == nil then
    return false
  end
  return ComponentGetValue2(ability, "use_gun_script") == true
end

local function get_item_name(entity_id)
  local item_component = get_component(entity_id, "ItemComponent")
  if item_component ~= nil then
    local item_name = ComponentGetValue2(item_component, "item_name")
    if item_name ~= nil and item_name ~= "" then
      return item_name
    end
  end
  return EntityGetName(entity_id) or ""
end

local function get_wand_spell_entries(wand_entity_id)
  local spells = {}
  local children = EntityGetAllChildren(wand_entity_id) or {}

  for _, spell_entity in ipairs(children) do
    local item_action = get_component(spell_entity, "ItemActionComponent")
    if item_action ~= nil then
      local action_id = ComponentGetValue2(item_action, "action_id")
      if action_id ~= nil and action_id ~= "" then
        local inventory_x = 999
        local item_component = get_component(spell_entity, "ItemComponent")
        if item_component ~= nil then
          inventory_x = ComponentGetValue2(item_component, "inventory_slot") or 999
        end
        spells[#spells + 1] = {
          entity_id = spell_entity,
          action_id = action_id,
          inventory_x = inventory_x,
        }
      end
    end
  end

  table.sort(spells, function(a, b)
    return a.inventory_x < b.inventory_x
  end)

  return spells
end

local function get_wand_spells(wand_entity_id)
  local entries = get_wand_spell_entries(wand_entity_id)
  local spell_ids = {}
  for _, spell in ipairs(entries) do
    spell_ids[#spell_ids + 1] = spell.action_id
  end
  return spell_ids
end

local function get_wand_stats(wand_entity_id)
  local ability = get_component(wand_entity_id, "AbilityComponent")
  if ability == nil then
    return {}
  end

  local reload_frames = ComponentObjectGetValue2(ability, "gun_config", "reload_time") or 0
  return {
    capacity = ComponentObjectGetValue2(ability, "gun_config", "deck_capacity") or 0,
    recharge_time = reload_frames / FRAMES_PER_SECOND,
    mana_max = ComponentGetValue2(ability, "mana_max") or 0,
    mana_charge_speed = ComponentGetValue2(ability, "mana_charge_speed") or 0,
    spread = ComponentObjectGetValue2(ability, "gunaction_config", "spread_degrees") or 0,
    speed_multiplier = ComponentObjectGetValue2(ability, "gunaction_config", "speed_multiplier") or 1,
  }
end

function M.get_inventory_entity_ids(entity_id)
  if not is_alive_entity(entity_id) then
    return {}
  end

  local ids = {}
  local items = GameGetAllInventoryItems(entity_id) or {}
  for _, item_entity_id in ipairs(items) do
    ids[item_entity_id] = true
  end
  return ids
end

--- Spells (bag + wand slots) and non-wand items the player is carrying, keyed by entity id.
function M.get_carried_entities(player_entity)
  local carried = {}
  if not is_alive_entity(player_entity) then
    return carried
  end

  local inventory = GameGetAllInventoryItems(player_entity) or {}
  for _, entity_id in ipairs(inventory) do
    if is_wand(entity_id) then
      for _, spell in ipairs(get_wand_spell_entries(entity_id)) do
        carried[spell.entity_id] = {
          entity_id = spell.entity_id,
          item_id = spell.action_id,
          item_type = "spell",
          container = "wand",
          wand_entity_id = entity_id,
        }
      end
      for _, child_id in ipairs(EntityGetAllChildren(entity_id) or {}) do
        local item_type, item_id = M.classify_item(child_id)
        if item_type == "potion" and carried[child_id] == nil then
          carried[child_id] = {
            entity_id = child_id,
            item_id = item_id,
            item_type = item_type,
            container = "wand",
            wand_entity_id = entity_id,
          }
        end
      end
    else
      local item_type, item_id = M.classify_item(entity_id)
      if item_type ~= "wand" then
        carried[entity_id] = {
          entity_id = entity_id,
          item_id = item_id,
          item_type = item_type,
          container = "player",
          wand_entity_id = nil,
        }
      end
    end
  end

  return carried
end

function M.classify_item(entity_id)
  if entity_id == nil then
    return "other", ""
  end

  if is_wand(entity_id) then
    return "wand", get_item_name(entity_id)
  end

  local item_action = get_component(entity_id, "ItemActionComponent")
  if item_action ~= nil then
    local action_id = ComponentGetValue2(item_action, "action_id")
    if action_id ~= nil and action_id ~= "" then
      return "spell", action_id
    end
  end

  local material_id = GetMaterialInventoryMainMaterial(entity_id, true)
  if material_id ~= nil and material_id > 0 then
    return "potion", get_item_name(entity_id)
  end

  local item_name = get_item_name(entity_id)
  if string.find(item_name, "potion", 1, true) ~= nil then
    return "potion", item_name
  end

  return "other", item_name
end

function M.describe_item(entity_id)
  local item_type, item_id = M.classify_item(entity_id)
  return {
    entity_id = entity_id,
    item_id = item_id,
    item_type = item_type,
  }
end

local SHOP_SCAN_RADIUS = 900

function M.get_item_shop_cost(entity_id)
  if entity_id == nil then
    return nil
  end

  local cost_component = get_component(entity_id, "ItemCostComponent")
  if cost_component == nil then
    return nil
  end

  local cost = tonumber(ComponentGetValue2(cost_component, "cost"))
  if cost == nil or cost <= 0 then
    return nil
  end

  return cost
end

function M.has_shop_cost(entity_id)
  return M.get_item_shop_cost(entity_id) ~= nil
end

function M.scan_shop_stock(player_entity, radius)
  radius = radius or SHOP_SCAN_RADIUS
  if player_entity == nil then
    return {}
  end

  local position = collector.get_position(player_entity)
  if position == nil then
    return {}
  end

  local inventory_ids = M.get_inventory_entity_ids(player_entity)
  local stock = {}
  local entities = EntityGetInRadius(position.x, position.y, radius) or {}

  for _, entity_id in ipairs(entities) do
    if entity_id ~= player_entity and inventory_ids[entity_id] ~= true then
      local cost = M.get_item_shop_cost(entity_id)
      if cost ~= nil then
        local description = M.describe_item(entity_id)
        stock[entity_id] = {
          entity_id = entity_id,
          item_id = description.item_id,
          item_type = description.item_type,
          cost = cost,
        }
      end
    end
  end

  return stock
end

function M.find_removed_shop_stock(previous_stock, current_stock, inventory_ids)
  local removed = {}

  for entity_id, meta in pairs(previous_stock or {}) do
    if current_stock[entity_id] == nil then
      local in_inventory = inventory_ids ~= nil and inventory_ids[entity_id] == true
      if in_inventory or not EntityGetIsAlive(entity_id) then
        removed[#removed + 1] = meta
      end
    end
  end

  return removed
end

function M.match_shop_steals(removed_shop, new_item_entity_ids)
  local steals = {}
  local used_removed = {}

  for _, item_entity_id in ipairs(new_item_entity_ids) do
    local description = M.describe_item(item_entity_id)

    for index, meta in ipairs(removed_shop) do
      if not used_removed[index]
        and meta.item_id == description.item_id
        and meta.item_type == description.item_type
      then
        used_removed[index] = true
        steals[#steals + 1] = item_entity_id
        break
      end
    end
  end

  return steals
end

local function append_non_wand_item(items, item_entity_id, item_type, item_id)
  if item_type == "spell" then
    if item_id ~= "" then
      items[#items + 1] = {
        id = item_id,
        material = "",
        count = 1,
        item_type = "spell",
      }
      return 1
    end
    return 0
  end

  local material = ""
  local material_id = GetMaterialInventoryMainMaterial(item_entity_id, true)
  if material_id ~= nil and material_id > 0 then
    material = CellFactory_GetName(material_id) or ""
  end

  local count = 1
  local item_component = get_component(item_entity_id, "ItemComponent")
  if item_component ~= nil and ComponentGetValue2(item_component, "is_stackable") == true then
    local ability = get_component(item_entity_id, "AbilityComponent")
    if ability ~= nil then
      count = ComponentGetValue2(ability, "amount_in_inventory") or 1
    end
  end

  items[#items + 1] = {
    id = item_id ~= "" and item_id or get_item_name(item_entity_id),
    material = material,
    count = count,
  }
  return count
end

local function append_wand_carried(carried, wand_entity_id)
  for _, spell in ipairs(get_wand_spell_entries(wand_entity_id)) do
    carried[spell.entity_id] = {
      entity_id = spell.entity_id,
      item_id = spell.action_id,
      item_type = "spell",
      container = "wand",
      wand_entity_id = wand_entity_id,
    }
  end

  for _, child_id in ipairs(EntityGetAllChildren(wand_entity_id) or {}) do
    local item_type, item_id = M.classify_item(child_id)
    if item_type == "potion" and carried[child_id] == nil then
      carried[child_id] = {
        entity_id = child_id,
        item_id = item_id,
        item_type = item_type,
        container = "wand",
        wand_entity_id = wand_entity_id,
      }
    end
  end
end

--- One inventory pass for run start: wands, items, carried entities, and inventory ids.
function M.scan_inventory(player_entity)
  local empty = {
    wands = {},
    items = {},
    carried = {},
    inventory_ids = {},
    item_count = 0,
  }
  if not is_alive_entity(player_entity) then
    return empty
  end

  local wands = {}
  local items = {}
  local carried = {}
  local inventory_ids = {}
  local item_count = 0
  local inventory = GameGetAllInventoryItems(player_entity) or {}

  for _, entity_id in ipairs(inventory) do
    inventory_ids[entity_id] = true

    if is_wand(entity_id) then
      local spell_entries = get_wand_spell_entries(entity_id)
      local spell_ids = {}
      for _, spell in ipairs(spell_entries) do
        spell_ids[#spell_ids + 1] = spell.action_id
      end

      wands[#wands + 1] = {
        entity_id = entity_id,
        name = get_item_name(entity_id),
        stats = get_wand_stats(entity_id),
        spells = spell_ids,
        spell_count = #spell_ids,
      }
      append_wand_carried(carried, entity_id)
    else
      local item_type, item_id = M.classify_item(entity_id)
      if item_type ~= "wand" then
        carried[entity_id] = {
          entity_id = entity_id,
          item_id = item_id,
          item_type = item_type,
          container = "player",
          wand_entity_id = nil,
        }
        item_count = item_count + append_non_wand_item(items, entity_id, item_type, item_id)
      end
    end
  end

  return {
    wands = wands,
    items = items,
    carried = carried,
    inventory_ids = inventory_ids,
    item_count = item_count,
  }
end

function M.get_wands(entity_id)
  if not is_alive_entity(entity_id) then
    return {}
  end

  local wands = {}
  local items = GameGetAllInventoryItems(entity_id) or {}

  for _, item_entity_id in ipairs(items) do
    if is_wand(item_entity_id) then
      local spells = get_wand_spells(item_entity_id)
      wands[#wands + 1] = {
        entity_id = item_entity_id,
        name = get_item_name(item_entity_id),
        stats = get_wand_stats(item_entity_id),
        spells = spells,
        spell_count = #spells,
      }
    end
  end

  return wands
end

function M.get_items(entity_id)
  if not is_alive_entity(entity_id) then
    return {}
  end

  local items = {}
  local inventory = GameGetAllInventoryItems(entity_id) or {}

  for _, item_entity_id in ipairs(inventory) do
    if not is_wand(item_entity_id) then
      local item_type, item_id = M.classify_item(item_entity_id)
      append_non_wand_item(items, item_entity_id, item_type, item_id)
    end
  end

  return items
end

function M.get_perks(_entity_id)
  if not ensure_perk_list() then
    return {}
  end

  local counts = M.get_perk_counts()
  local active = {}
  for perk_id, count in pairs(counts) do
    if count > 0 then
      active[perk_id] = true
    end
  end

  local perks = {}
  for _, perk in ipairs(perk_list) do
    local perk_id = perk.id
    local pickup_count = counts[perk_id] or 0
    if pickup_count > 0 and not is_suppressed_telemetry_perk(perk_id, active) then
      for _ = 1, pickup_count do
        perks[#perks + 1] = perk_id
      end
    end
  end

  return perks
end

function M.get_perk_counts()
  if not ensure_perk_list() then
    return {}
  end

  local counts = {}
  for _, perk in ipairs(perk_list) do
    local flag_name = get_perk_picked_flag_name(perk.id)
    local pickup_count = tonumber(GlobalsGetValue(flag_name .. "_PICKUP_COUNT", "0")) or 0
    if GameHasFlagRun(flag_name) and pickup_count > 0 then
      counts[perk.id] = pickup_count
    end
  end
  return counts
end

function M.get_player_snapshot(entity_id)
  local wands = M.get_wands(entity_id)
  local items = M.get_items(entity_id)
  local item_count = 0
  for _, item in ipairs(items) do
    item_count = item_count + (item.count or 1)
  end

  return {
    hp = collector.get_hp(entity_id),
    gold = collector.get_gold(entity_id),
    biome = collector.get_biome(entity_id),
    position = collector.get_position(entity_id),
    wands = wands,
    wand_count = #wands,
    items = items,
    item_count = item_count,
    perks = M.get_perks(entity_id),
  }
end

return M
