-- Which game mode a run is recorded as. Noita ships Nightmare as a mod, so the
-- mode is derived from the active mod list (adapters/noita/mod_list_reader.lua).

local M = {}

M.NORMAL = "normal"
M.NIGHTMARE = "nightmare"

function M.resolve(nightmare_enabled)
  if nightmare_enabled then
    return M.NIGHTMARE
  end
  return M.NORMAL
end

return M
