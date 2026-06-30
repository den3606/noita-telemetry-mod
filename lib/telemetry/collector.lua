local M = {}

local FRAMES_PER_SECOND = 60

function M.get_player_entity()
  local players = EntityGetWithTag("player_unit")
  if players == nil then
    return nil
  end
  if type(players) == "number" then
    return players
  end
  return players[1]
end

function M.get_frame()
  return GameGetFrameNum()
end

function M.get_run_playtime_sec(run_start_frame)
  if run_start_frame == nil then
    return 0
  end
  return math.max(0, math.floor((M.get_frame() - run_start_frame) / FRAMES_PER_SECOND))
end

function M.get_playtime_sec()
  return M.get_frame() / FRAMES_PER_SECOND
end

function M.get_t_ms(run_start_frame)
  return math.floor((M.get_frame() - run_start_frame) * (1000 / FRAMES_PER_SECOND))
end

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

function M.get_world_seed()
  local seed = SessionNumbersGetValue("world_seed")
  if seed ~= nil and seed ~= "" then
    return tonumber(seed)
  end

  seed = StatsGetValue("world_seed")
  if seed ~= nil and seed ~= "" then
    return tonumber(seed)
  end

  return nil
end

function M.get_ng_plus()
  local ng = GlobalsGetValue("NEW_GAME_PLUS_COUNT", "0")
  return tonumber(ng) or 0
end

function M.get_game_mode()
  if ModIsEnabled("nightmare") then
    return "nightmare"
  end
  return "normal"
end

function M.get_noita_version()
  local version = dofile_once("mods/noita-telemetry/lib/telemetry/version.lua")
  return version.get()
end

function M.get_mods_enabled()
  local mod_ids = ModGetActiveModIDs()
  if mod_ids == nil then
    return {}
  end
  if type(mod_ids) == "string" then
    return { mod_ids }
  end
  return mod_ids
end

function M.is_player_dead(entity_id)
  local hp = M.get_hp(entity_id)
  if hp == nil then
    return false
  end
  return hp.current <= 0
end

function M.is_holy_mountain_biome(biome)
  if biome == nil then
    return false
  end
  -- Shop interior only ($biome_holymountain). Portal pool uses mountain_top; tutorial uses mountain_hall.
  return string.find(biome, "holymountain", 1, true) ~= nil
end

function M.is_victory_death(player_entity)
  if GameHasFlagRun("ending_game_completed") then
    return true
  end

  local biome = M.get_biome(player_entity)
  if biome ~= nil and string.find(biome, "victoryroom", 1, true) ~= nil then
    return true
  end

  return false
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

function M.get_session_stat(key)
  local value = StatsGetValue(key)
  if value == nil or value == "" then
    return nil
  end
  return tonumber(value) or value
end

return M
