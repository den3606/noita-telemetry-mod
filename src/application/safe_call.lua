-- Shared pcall wrappers so call sites don't hand-roll `if not ok then ... end`.
-- Use `guard` for rare/boot-level calls where the player should see a
-- localized error via message.error. Use `silent` for per-frame/per-event
-- hook calls where failures should only reach log.txt.
--
-- Prefer a zero-arg thunk at call sites so the body reads like a normal
-- function call: `guard(key, function() real_fn(a, b) end)`.
-- `guard(key, fn, ...)` / `silent(fn, ...)` also work (args forwarded to
-- pcall) when a bare function reference is enough.
--
-- On success: returns exactly what `fn` returned. On failure: reports via
-- message.error / noita_message.console and returns nothing (nil).
--
-- Neither takes a caller-supplied label: Lua's runtime errors already carry a
-- "file:line: message" prefix at the actual failure site, which pinpoints the
-- bug better than a hand-written call-site name would.

local message = dofile_once("mods/noita-telemetry/src/application/messaging.lua")
local noita_message = dofile_once("mods/noita-telemetry/src/adapters/noita/message.lua")

local M = {}

local function pack_n(...)
  return { n = select("#", ...), ... }
end

--- Player-visible failure: pcall(fn, ...); on error, message.error(key, {err}).
function M.guard(key, fn, ...)
  local results = pack_n(pcall(fn, ...))
  if not results[1] then
    message.error(key, { err = tostring(results[2]) })
    return
  end
  return unpack(results, 2, results.n)
end

--- Silent failure: pcall(fn, ...); on error, noita_message.console(...) only (log.txt).
function M.silent(fn, ...)
  local results = pack_n(pcall(fn, ...))
  if not results[1] then
    noita_message.console("[ntel] WARN " .. tostring(results[2]))
    return
  end
  return unpack(results, 2, results.n)
end

return M
