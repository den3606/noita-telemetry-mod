-- Wrap NG+ transitions (mountain altar with enough orbs).
if do_newgame_plus ~= nil then
  local __telemetry_old_do_newgame_plus = do_newgame_plus
  function do_newgame_plus(...)
    if telemetry_on_victory ~= nil then
      telemetry_on_victory()
    end
    return __telemetry_old_do_newgame_plus(...)
  end
end
