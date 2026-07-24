local streak_patch = dofile_once("mods/noita-telemetry/streak_patch.lua")
local version = dofile_once("mods/noita-telemetry/lib/telemetry/version.lua")
local config = dofile_once("mods/noita-telemetry/lib/telemetry/config.lua")

version.init()

ModLuaFileAppend(
  "data/entities/animals/boss_centipede/boss_centipede_update.lua",
  "mods/noita-telemetry/hooks/kolmis_defeated_append.lua"
)

ModLuaFileAppend(
  "data/entities/animals/boss_centipede/ending/sampo_start_ending_sequence.lua",
  "mods/noita-telemetry/hooks/pedestal_start_append.lua"
)

ModLuaFileAppend(
  "data/entities/animals/boss_centipede/ending/sampo_start_ending_sequence.lua",
  "mods/noita-telemetry/hooks/victory_append.lua"
)

ModLuaFileAppend(
  "data/scripts/newgame_plus.lua",
  "mods/noita-telemetry/hooks/ngplus_append.lua"
)

ModLuaFileAppend(
  "data/scripts/perks/perk_reroll.lua",
  "mods/noita-telemetry/hooks/perk_reroll_append.lua"
)

local events = dofile_once("mods/noita-telemetry/lib/telemetry/events.lua")
local errors = dofile_once("mods/noita-telemetry/lib/telemetry/errors.lua")

local function try_apply_streak_patch()
  if not config.force_win_streak_enabled() then
    return
  end

  local ok, err = pcall(streak_patch.apply)
  if not ok then
    errors.print(errors.streak_patch_skipped, { err = tostring(err) })
  end
end

local function announce_boot_failure()
  errors.print(config.boot_error_code or errors.unknown)
end

local function telemetry_ready()
  return config.ready == true
end

function telemetry_on_kolmis_defeated()
  if not telemetry_ready() then
    return
  end
  events.on_kolmis_defeated()
end

function telemetry_on_pedestal_start()
  if not telemetry_ready() then
    return
  end
  events.on_pedestal_start()
end

function telemetry_on_victory()
  if not telemetry_ready() then
    return
  end
  events.on_victory()
end

function telemetry_on_ng_plus_enter()
  if not telemetry_ready() then
    return
  end
  events.on_ng_plus_enter()
end

function telemetry_on_perk_reroll(entity_item, entity_who_picked)
  if not telemetry_ready() then
    return
  end
  events.on_perk_reroll(entity_item, entity_who_picked)
end

function OnWorldInitialized()
  try_apply_streak_patch()
  if not telemetry_ready() then
    announce_boot_failure()
    return
  end
  events.on_world_initialized()
end

function OnPlayerSpawned(player_entity)
  if not telemetry_ready() then
    return
  end
  events.on_player_spawned(player_entity)
end

function OnPlayerDied(player_entity)
  if not telemetry_ready() then
    return
  end
  events.on_player_died(player_entity)
end

function OnWorldPostUpdate()
  if not telemetry_ready() then
    return
  end
  events.on_world_post_update()
end
