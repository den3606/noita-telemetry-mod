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
  -- Runs every frame; same spam concern as TelemetryOnDamageReceived above.
  safe_call.silent(events.post_update)
end

function TelemetryOnDamageReceived(damage, message, entity_thats_responsible, is_fatal, projectile_thats_responsible)
  safe_call.silent(function()
    events.damage_received(damage, message, entity_thats_responsible, is_fatal, projectile_thats_responsible)
  end)
end

function TelemetryOnKolmiDefeated()
  safe_call.guard(message.KEYS.MSG_ERROR_EVENT_HANDLER_FAILED, events.kolmis_defeated)
end

function TelemetryOnPedestalStart()
  safe_call.guard(message.KEYS.MSG_ERROR_EVENT_HANDLER_FAILED, events.pedestal_start)
end

function TelemetryOnVictory()
  safe_call.guard(message.KEYS.MSG_ERROR_EVENT_HANDLER_FAILED, events.victory)
end

function TelemetryOnNgPlusEnter()
  safe_call.guard(message.KEYS.MSG_ERROR_EVENT_HANDLER_FAILED, events.ng_plus_enter)
end

function TelemetryOnPerkReroll(entity_item, entity_who_picked)
  safe_call.guard(message.KEYS.MSG_ERROR_EVENT_HANDLER_FAILED, function()
    events.perk_reroll(entity_item, entity_who_picked)
  end)
end

function TelemetryOnPerkPick(entity_item, entity_who_picked, item_name)
  safe_call.guard(message.KEYS.MSG_ERROR_EVENT_HANDLER_FAILED, function()
    events.perk_pick(entity_item, entity_who_picked, item_name)
  end)
end

function TelemetryOnShopItemPickup(entity_item, entity_who_picked, item_name, cost_before)
  safe_call.guard(message.KEYS.MSG_ERROR_EVENT_HANDLER_FAILED, function()
    events.shop_item_pickup(entity_item, entity_who_picked, item_name, cost_before)
  end)
end
