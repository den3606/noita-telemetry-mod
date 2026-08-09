-- Reads the player entity and its components (`EntityGetWithTag` /
-- `EntityGetFirstComponent` / `ComponentGetValue2`).

local M = {}

function M.get_entity_id()
  local players = EntityGetWithTag("player_unit")
  if players == nil then
    return nil
  end
  if type(players) == "number" then
    return players
  end
  return players[1]
end

function M.get_hp(entity_id)
  if entity_id == nil then
    return nil
  end

  local damage_model = EntityGetFirstComponent(entity_id, "DamageModelComponent")
  if damage_model == nil then
    return nil
  end

  return {
    current = ComponentGetValue2(damage_model, "hp"),
    max = ComponentGetValue2(damage_model, "max_hp"),
  }
end

function M.is_dead(entity_id)
  local hp = M.get_hp(entity_id)
  if hp == nil then
    return false
  end
  return hp.current <= 0
end

function M.get_gold(entity_id)
  if entity_id == nil then
    return 0
  end

  local wallet = EntityGetFirstComponent(entity_id, "WalletComponent")
  if wallet == nil then
    return 0
  end

  return ComponentGetValue2(wallet, "money")
end

return M
