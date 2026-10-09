-- Reads positions, biome names and nearby entities from the world
-- (`EntityGetTransform` / `BiomeMapGetName` / `EntityGetInRadius`).
-- Biome name -> meaning is decided in domain/biome.lua.

local M = {}

function M.get_position(entity_id)
  if entity_id == nil then
    return nil
  end
  local x, y = EntityGetTransform(entity_id)
  return { x = x, y = y }
end

function M.get_biome(entity_id)
  if entity_id == nil then
    return nil
  end
  local position = M.get_position(entity_id)
  if position == nil then
    return nil
  end
  return BiomeMapGetName(position.x, position.y)
end

function M.find_stevari_near(entity_id, radius)
  if entity_id == nil then
    return nil
  end

  local position = M.get_position(entity_id)
  if position == nil then
    return nil
  end

  local entities = EntityGetInRadius(position.x, position.y, radius or 2500)
  if entities == nil then
    return nil
  end

  for _, entity_id_near in ipairs(entities) do
    if EntityGetName(entity_id_near) == "stevari" then
      return entity_id_near
    end
  end

  return nil
end

function M.is_alive(entity_id)
  return entity_id ~= nil and EntityGetIsAlive(entity_id)
end

function M.is_stevari_alive(stevari_id)
  if stevari_id == nil or not EntityGetIsAlive(stevari_id) then
    return false
  end

  local damage_model = EntityGetFirstComponent(stevari_id, "DamageModelComponent")
  if damage_model == nil then
    return true
  end

  return ComponentGetValue2(damage_model, "hp") > 0
end

return M
