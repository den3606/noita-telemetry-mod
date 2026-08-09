-- Frame arithmetic for timestamps. Noita runs at a fixed 60 fps, so a frame
-- delta is enough; the frame itself is read through adapters/noita/frame_clock.lua.

local M = {}

local FRAMES_PER_SECOND = 60

--- Whole seconds between start_frame and frame (never negative).
function M.elapsed_sec(frame, start_frame)
  if start_frame == nil then
    return 0
  end
  return math.max(0, math.floor((frame - start_frame) / FRAMES_PER_SECOND))
end

--- Milliseconds between start_frame and frame.
function M.elapsed_ms(frame, start_frame)
  if start_frame == nil then
    return 0
  end
  return math.floor((frame - start_frame) * (1000 / FRAMES_PER_SECOND))
end

return M
