dofile_once("mods/noita-telemetry/src/boot.lua")

local streak_patch = dofile_once("mods/noita-telemetry/src/core/streak.lua")
local events = dofile_once("mods/noita-telemetry/src/core/events.lua")
local message = dofile_once("mods/noita-telemetry/src/core/messaging.lua")
local safe_call = dofile_once("mods/noita-telemetry/src/core/safe_call.lua")

local function try_apply_streak_patch()
  if not streak_patch.is_enabled() then
    return
  end

  safe_call.guard(message.KEYS.MSG_ERROR_STREAK_PATCH_SKIPPED, streak_patch.apply)
end

function OnWorldInitialized()
  try_apply_streak_patch()
  safe_call.guard(message.KEYS.MSG_ERROR_EVENT_HANDLER_FAILED, events.world_initialized)
end

function OnPlayerSpawned(player_entity_id)
  safe_call.guard(message.KEYS.MSG_ERROR_EVENT_HANDLER_FAILED, function()
    events.player_spawned(player_entity_id)
  end)
end

function OnPlayerDied(player_entity_id)
  safe_call.guard(message.KEYS.MSG_ERROR_EVENT_HANDLER_FAILED, function()
    events.player_died(player_entity_id)
  end)
end

function OnWorldPostUpdate()
  -- Runs every frame; silent so a failing poll does not spam the player.
  safe_call.silent(events.post_update)
end
