-- Facade for init.lua: the Noita callbacks (OnWorldInitialized / OnPlayerSpawned /
-- OnPlayerDied / OnWorldPostUpdate) land here and dispatch to events/*.lua.
-- Appended-script hooks cannot call init.lua; they reach events/ through
-- core/hook_queue.lua, drained by post_update → hook_messages.
-- Public names match events/*.lua file stems (no on_ prefix).

local world_initialized = dofile_once("mods/noita-telemetry/src/core/events/world_initialized.lua")
local player_spawned = dofile_once("mods/noita-telemetry/src/core/events/player_spawned.lua")
local player_died = dofile_once("mods/noita-telemetry/src/core/events/player_died.lua")
local post_update = dofile_once("mods/noita-telemetry/src/core/events/post_update.lua")

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

return M
