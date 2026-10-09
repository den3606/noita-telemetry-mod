-- Reads per-session values Noita keeps outside the entity world: world seed,
-- NG+ count, run flags and the stats table (`SessionNumbersGetValue` /
-- `StatsGetValue` / `GameHasFlagRun`).

local M = {}

function M.get_world_seed()
  local seed = SessionNumbersGetValue("world_seed")
  if seed ~= nil and seed ~= "" then
    return tonumber(seed)
  end

  local stat_seed = StatsGetValue("world_seed")
  if stat_seed ~= nil and stat_seed ~= "" then
    return tonumber(stat_seed)
  end

  return nil
end

function M.get_ng_plus()
  return tonumber(SessionNumbersGetValue("NEW_GAME_PLUS_COUNT")) or 0
end

function M.is_ending_completed()
  return GameHasFlagRun("ending_game_completed")
end

--- One entry of Noita's run stats table (`killed_by`, `enemies_killed`, ...).
function M.get_stat(key)
  local value = StatsGetValue(key)
  if value == nil or value == "" then
    return nil
  end
  return tonumber(value) or value
end

return M
