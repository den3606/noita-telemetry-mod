-- NG+ is out of ntel scope: mark the world and abandon any in-progress run without upload.
if do_newgame_plus ~= nil then
  local __telemetry_old_do_newgame_plus = do_newgame_plus
  function do_newgame_plus(...)
    if telemetry_on_ng_plus_enter ~= nil then
      telemetry_on_ng_plus_enter()
    end
    return __telemetry_old_do_newgame_plus(...)
  end
end
