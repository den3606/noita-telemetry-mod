-- Pure biome-change judgement. Noita reads and state writes stay in events/polls/.

local biome_rules = dofile_once("mods/noita-telemetry/src/domain/biome.lua")

local M = {}

--- Compare previous/current biome names and whether we already think we are
--- inside a Holy Mountain shop. Returns nil when nothing should be emitted.
---
--- kind:
---   "init"   — first observation this run (no biome_enter yet)
---   "change" — biome name changed; always emit biome_enter
--- hm (only for "change"):
---   "enter"   — enter Holy Mountain from outside
---   "exit"    — leave Holy Mountain
---   "reenter" — dungeon -> HM while in_holy_mountain was stale (exit then enter)
---   "none"    — no HM enter/exit side effects
function M.diff(previous, current, in_holy_mountain)
  if previous == nil then
    return { kind = "init", biome = current }
  end

  if current == previous then
    return nil
  end

  local entering = biome_rules.is_holy_mountain(current)
  local hm = "none"
  if entering and not in_holy_mountain then
    hm = "enter"
  elseif entering and in_holy_mountain then
    if not biome_rules.is_holy_mountain(previous) then
      hm = "reenter"
    end
  elseif in_holy_mountain and not entering then
    hm = "exit"
  end

  return {
    kind = "change",
    from = previous,
    to = current,
    hm = hm,
  }
end

return M
