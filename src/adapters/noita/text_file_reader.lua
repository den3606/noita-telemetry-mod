-- Reads game data files through Noita's loader (`ModTextFileGetContent`).
-- Only usable during mod load time (the ModTextFile* window), so callers must
-- cache what they need from src/boot.lua.

local M = {}

function M.get_content(path)
  return ModTextFileGetContent(path)
end

return M
