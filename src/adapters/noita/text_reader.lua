-- Vanilla localized UI text (`GameTextGet`). Keys must start with `$`.
-- Used to detect the game language; the language rule lives in
-- core/messaging/locale.lua.

local M = {}

function M.get(key)
  return GameTextGet(key)
end

return M
