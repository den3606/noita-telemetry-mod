-- Sole entry point for Noita's user-facing output / abort APIs.
-- telemetry modules must not call `GamePrint` / `print` / `error` directly; go
-- through here so the Noita dependency stays isolated to this one file.

local M = {}

--- Show a message in the in-game HUD/console (`GamePrint`).
function M.game(text)
  GamePrint(text)
end

--- Write a line to Noita's log/console (`print`).
function M.console(text)
  print(text)
end

--- Abort with a Lua/Noita `error` (fail-fast; does not return).
function M.error(text)
  error(text)
end

return M
