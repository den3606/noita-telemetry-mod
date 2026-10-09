-- What a Noita biome name means for telemetry. The name itself comes from
-- adapters/noita/world_reader.lua.

local M = {}

--- Shop interior only (`$biome_holymountain`). The portal pool is
--- `mountain_top` and the tutorial is `mountain_hall`; neither is a shop.
function M.is_holy_mountain(biome)
  if biome == nil then
    return false
  end
  return string.find(biome, "holymountain", 1, true) ~= nil
end

--- The room behind the final boss: dying here means the run was won.
function M.is_victory_room(biome)
  if biome == nil then
    return false
  end
  return string.find(biome, "victoryroom", 1, true) ~= nil
end

return M
