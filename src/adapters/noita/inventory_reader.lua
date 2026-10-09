local item_rules = dofile_once("mods/noita-telemetry/src/domain/item.lua")
local perk_rules = dofile_once("mods/noita-telemetry/src/domain/perk.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local world_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/world_reader.lua")
local M = {}

local FRAMES_PER_SECOND = 60
local perk_list_ready = false

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

--- perk entity VariableStorageComponent name="perk_id" (set by perk_spawn).
function M.get_perk_id(entity_id)
  if entity_id == nil then
    return nil
  end

  local components = EntityGetComponent(entity_id, "VariableStorageComponent")
  if components == nil then
    return nil
  end

  for _, comp_id in ipairs(components) do
    if ComponentGetValue2(comp_id, "name") == "perk_id" then
      local perk_id = ComponentGetValue2(comp_id, "value_string")
      if perk_id ~= nil and perk_id ~= "" then
        return perk_id
      end
    end
  end
  return nil
end

local function get_component(entity_id, component_name)
  return EntityGetFirstComponentIncludingDisabled(entity_id, component_name)
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

  for _, spell_entity_id in ipairs(children) do
    local item_action = get_component(spell_entity_id, "ItemActionComponent")
    if item_action ~= nil then
      local action_id = ComponentGetValue2(item_action, "action_id")
      if action_id ~= nil and action_id ~= "" then
        local inventory_x = 999
        local always_cast = false
        local item_component = get_component(spell_entity_id, "ItemComponent")
        if item_component ~= nil then
          inventory_x = ComponentGetValue2(item_component, "inventory_slot") or 999
          -- Always-cast spells are attached for good and sit outside the wand's slots.
          always_cast = ComponentGetValue2(item_component, "permanently_attached") == true
        end
        spells[#spells + 1] = {
          entity_id = spell_entity_id,
          action_id = action_id,
          inventory_x = inventory_x,
          always_cast = always_cast,
        }
      end
    end
  end

  table.sort(spells, function(a, b)
    return a.inventory_x < b.inventory_x
  end)

  return spells
end

--- Slotted spell ids in slot order, then the always-cast spell ids.
local function get_wand_spells(wand_entity_id)
  local spell_ids = {}
  local always_cast_ids = {}
  for _, spell in ipairs(get_wand_spell_entries(wand_entity_id)) do
    if spell.always_cast then
      always_cast_ids[#always_cast_ids + 1] = spell.action_id
    else
      spell_ids[#spell_ids + 1] = spell.action_id
    end
  end
  return spell_ids, always_cast_ids
end

--- Spells the player can take off the wand: always-cast spells are not carried items.
local function get_wand_carried_spell_entries(wand_entity_id)
  local entries = {}
  for _, spell in ipairs(get_wand_spell_entries(wand_entity_id)) do
    if not spell.always_cast then
      entries[#entries + 1] = spell
    end
  end
  return entries
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
  if not world_reader.is_alive(entity_id) then
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
function M.get_carried_entities(player_entity_id)
  local carried = {}
  if not world_reader.is_alive(player_entity_id) then
    return carried
  end

  local inventory = GameGetAllInventoryItems(player_entity_id) or {}
  for _, entity_id in ipairs(inventory) do
    if is_wand(entity_id) then
      for _, spell in ipairs(get_wand_carried_spell_entries(entity_id)) do
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

  local action_id = nil
  local item_action = get_component(entity_id, "ItemActionComponent")
  if item_action ~= nil then
    action_id = ComponentGetValue2(item_action, "action_id")
  end
  local material_id = GetMaterialInventoryMainMaterial(entity_id, true)

  return item_rules.classify({
    is_wand = is_wand(entity_id),
    action_id = action_id,
    has_material = material_id ~= nil and material_id > 0,
    name = get_item_name(entity_id),
  })
end

function M.describe_item(entity_id)
  local item_type, item_id = M.classify_item(entity_id)
  return {
    entity_id = entity_id,
    item_id = item_id,
    item_type = item_type,
  }
end

--- ItemCostComponent's cost, 0 included; nil once the component is gone (bought or stolen).
function M.get_shop_price(entity_id)
  if entity_id == nil then
    return nil
  end
  local cost_component = get_component(entity_id, "ItemCostComponent")
  if cost_component == nil then
    return nil
  end
  return tonumber(ComponentGetValue2(cost_component, "cost"))
end

--- A positive price, or nil.
function M.get_item_shop_cost(entity_id)
  local cost = M.get_shop_price(entity_id)
  if cost == nil or cost <= 0 then
    return nil
  end
  return cost
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
  for _, spell in ipairs(get_wand_carried_spell_entries(wand_entity_id)) do
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
function M.scan_inventory(player_entity_id)
  local empty = {
    wands = {},
    items = {},
    carried = {},
    inventory_ids = {},
    item_count = 0,
  }
  if not world_reader.is_alive(player_entity_id) then
    return empty
  end

  local wands = {}
  local items = {}
  local carried = {}
  local inventory_ids = {}
  local item_count = 0
  local inventory = GameGetAllInventoryItems(player_entity_id) or {}

  for _, entity_id in ipairs(inventory) do
    inventory_ids[entity_id] = true

    if is_wand(entity_id) then
      local spell_ids, always_cast_ids = get_wand_spells(entity_id)

      wands[#wands + 1] = {
        entity_id = entity_id,
        name = get_item_name(entity_id),
        stats = get_wand_stats(entity_id),
        spells = spell_ids,
        always_cast = always_cast_ids,
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

--- One wand's name, stats, slotted spells in slot order and always-cast spells; nil when the entity is not a wand.
function M.get_wand(wand_entity_id)
  if not is_wand(wand_entity_id) then
    return nil
  end
  local spells, always_cast = get_wand_spells(wand_entity_id)
  return {
    entity_id = wand_entity_id,
    name = get_item_name(wand_entity_id),
    stats = get_wand_stats(wand_entity_id),
    spells = spells,
    always_cast = always_cast,
    spell_count = #spells,
  }
end

function M.get_wands(entity_id)
  if not world_reader.is_alive(entity_id) then
    return {}
  end

  local wands = {}
  local items = GameGetAllInventoryItems(entity_id) or {}

  for _, item_entity_id in ipairs(items) do
    local wand = M.get_wand(item_entity_id)
    if wand ~= nil then
      wands[#wands + 1] = wand
    end
  end

  return wands
end

function M.get_items(entity_id)
  if not world_reader.is_alive(entity_id) then
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
  local perks = {}
  for _, perk in ipairs(perk_list) do
    for _ = 1, counts[perk.id] or 0 do
      perks[#perks + 1] = perk.id
    end
  end
  return perks
end

function M.get_perk_counts()
  if not ensure_perk_list() then
    return {}
  end

  local game_counts = {}
  for _, perk in ipairs(perk_list) do
    local flag_name = get_perk_picked_flag_name(perk.id)
    local pickup_count = tonumber(GlobalsGetValue(flag_name .. "_PICKUP_COUNT", "0")) or 0
    if GameHasFlagRun(flag_name) and pickup_count > 0 then
      game_counts[perk.id] = pickup_count
    end
  end

  return perk_rules.picked_counts(game_counts, perk_list)
end

function M.get_player_snapshot(entity_id)
  local wands = M.get_wands(entity_id)
  local items = M.get_items(entity_id)
  local item_count = 0
  for _, item in ipairs(items) do
    item_count = item_count + (item.count or 1)
  end

  return {
    hp = player_reader.get_hp(entity_id),
    gold = player_reader.get_gold(entity_id),
    biome = world_reader.get_biome(entity_id),
    position = world_reader.get_position(entity_id),
    wands = wands,
    wand_count = #wands,
    items = items,
    item_count = item_count,
    perks = M.get_perks(entity_id),
  }
end

return M
