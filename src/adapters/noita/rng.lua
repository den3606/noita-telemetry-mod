-- Noita's run-seeded RNG (`Random`).

local M = {}

function M.random(min, max)
  return Random(min, max)
end

return M
