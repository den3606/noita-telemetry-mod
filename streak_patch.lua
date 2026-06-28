--- Re-enable vanilla win streak tracking while mods are active.

--- Based on patches from https://github.com/necauqua/negative-streak (MIT).



local native = dofile_once("mods/noita-telemetry/lib/telemetry/native.lua")



local M = {}



local applied = false



function M.apply()

  if applied then

    return true

  end



  local ok, err = native.apply_streak_patch()

  if not ok then

    error(err or "streak patch failed")

  end



  applied = true

  return true

end



return M

