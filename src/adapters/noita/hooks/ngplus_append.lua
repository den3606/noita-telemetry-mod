-- NG+ is out of ntel scope: mark the world and abandon any in-progress run without upload.
if do_newgame_plus ~= nil then
  local __telemetry_old_do_newgame_plus = do_newgame_plus
  local safe_call = dofile_once("mods/noita-telemetry/src/core/safe_call.lua")
  function do_newgame_plus(...)
    if TelemetryOnNgPlusEnter ~= nil then
      safe_call.silent(TelemetryOnNgPlusEnter)
    end
    return __telemetry_old_do_newgame_plus(...)
  end
end
