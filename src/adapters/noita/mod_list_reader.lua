-- Reads the active mod list (`ModGetActiveModIDs` / `ModIsEnabled`).
-- What a given mod means for a run (e.g. nightmare) is decided in
-- domain/game_mode.lua.

local M = {}

function M.get_active_ids()
  local mod_ids = ModGetActiveModIDs()
  if mod_ids == nil then
    return {}
  end
  if type(mod_ids) == "string" then
    return { mod_ids }
  end
  return mod_ids
end

function M.is_enabled(mod_id)
  return ModIsEnabled(mod_id) == true
end

return M
