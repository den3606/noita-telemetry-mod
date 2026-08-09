-- Facade for init.lua: every Noita hook / TelemetryOn* entry lands here, then
-- dispatches to events/*.lua (1:1 hooks) or events/post_update.lua (polls).
-- hooks → init.lua → events.lua → emit (polls go via post_update → polls/*).
-- Public names match events/*.lua file stems (no on_ prefix).

local world_initialized = dofile_once("mods/noita-telemetry/src/core/events/world_initialized.lua")
local player_spawned = dofile_once("mods/noita-telemetry/src/core/events/player_spawned.lua")
local ng_plus_enter = dofile_once("mods/noita-telemetry/src/core/events/ng_plus_enter.lua")
local damage_received = dofile_once("mods/noita-telemetry/src/core/events/damage_received.lua")
local kolmis_defeated = dofile_once("mods/noita-telemetry/src/core/events/kolmis_defeated.lua")
local pedestal_start = dofile_once("mods/noita-telemetry/src/core/events/pedestal_start.lua")
local player_died = dofile_once("mods/noita-telemetry/src/core/events/player_died.lua")
local victory = dofile_once("mods/noita-telemetry/src/core/events/victory.lua")
local post_update = dofile_once("mods/noita-telemetry/src/core/events/post_update.lua")
local perk_reroll = dofile_once("mods/noita-telemetry/src/core/events/perk_reroll.lua")
local perk_pick = dofile_once("mods/noita-telemetry/src/core/events/perk_pick.lua")
local shop_item_pickup = dofile_once("mods/noita-telemetry/src/core/events/shop_item_pickup.lua")

local M = {}

function M.world_initialized()
  world_initialized.emit()
end

function M.player_spawned(player_entity_id)
  player_spawned.emit(player_entity_id)
end

function M.player_died(player_entity_id)
  player_died.emit(player_entity_id)
end

function M.post_update()
  post_update.run()
end

function M.damage_received(damage, message, entity_thats_responsible, is_fatal, projectile_thats_responsible)
  damage_received.emit(damage, message, entity_thats_responsible, is_fatal, projectile_thats_responsible)
end

function M.kolmis_defeated()
  kolmis_defeated.emit()
end

function M.pedestal_start()
  pedestal_start.emit()
end

function M.victory()
  victory.emit()
end

function M.ng_plus_enter()
  ng_plus_enter.emit()
end

function M.perk_reroll(entity_item, entity_who_picked)
  perk_reroll.emit(entity_item, entity_who_picked)
end

function M.perk_pick(entity_item, entity_who_picked, item_name)
  perk_pick.emit(entity_item, entity_who_picked, item_name)
end

function M.shop_item_pickup(entity_item, entity_who_picked, item_name, cost_before)
  shop_item_pickup.emit(entity_item, entity_who_picked, item_name, cost_before)
end

return M
