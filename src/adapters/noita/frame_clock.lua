-- The only read of Noita's frame counter (`GameGetFrameNum`).
-- Frames -> seconds / milliseconds is arithmetic and lives in libs/timing.lua.

local M = {}

function M.get_frame()
  return GameGetFrameNum()
end

return M
