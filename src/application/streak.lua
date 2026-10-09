--- Re-enable vanilla win streak tracking while mods are active.

--- Based on patches from https://github.com/necauqua/negative-streak (MIT).

local streak_native = dofile_once("mods/noita-telemetry/src/adapters/native/streak.lua")
local mod_settings = dofile_once("mods/noita-telemetry/src/adapters/noita/mod_settings.lua")

local M = {}
local applied = false

--- Whether Settings has "Force win streak with mods" enabled. Owns the
--- `force_win_streak` setting id: callers (init.lua, application/run/session.lua)
--- only ask this, they never read the raw MOD setting themselves.
function M.is_enabled()
  return mod_settings.get_bool("force_win_streak", false)
end

function M.apply()
  if applied then
    return true
  end
  local ok, err = streak_native.apply_streak_patch()
  if not ok then
    error(err or "streak patch failed")
  end

  applied = true
  return true
end

return M
