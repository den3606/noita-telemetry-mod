-- The Noita build version of this session, read once at load (see domain/game_version.lua).

local text_file_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/text_file_reader.lua")
local game_version = dofile_once("mods/noita-telemetry/src/domain/game_version.lua")

local M = {}

local value = game_version.LATEST

--- Must run inside the mod load window (see src/boot.lua): the game data files
--- are only readable there.
function M.init()
  local raw = text_file_reader.get_content("data/version.txt")
  if raw == nil then
    return
  end
  value = game_version.normalize(raw)
end

function M.get()
  return value
end

return M
