-- run_lifecycle: every transition of the recorded run lives here; the Noita callbacks
-- in events/ only decide when to call it.

local writer = dofile_once("mods/noita-telemetry/src/application/run/writer.lua")
local session = dofile_once("mods/noita-telemetry/src/application/run/session.lua")
local persistence = dofile_once("mods/noita-telemetry/src/application/run/persistence.lua")
local run_header = dofile_once("mods/noita-telemetry/src/application/run/run_header.lua")
local run_state_open = dofile_once("mods/noita-telemetry/src/application/run/run_state_open.lua")
local message = dofile_once("mods/noita-telemetry/src/application/messaging.lua")
local emit = dofile_once("mods/noita-telemetry/src/application/events/emit.lua")
local finish_snapshot = dofile_once("mods/noita-telemetry/src/application/events/finish_snapshot.lua")
local run_end = dofile_once("mods/noita-telemetry/src/application/events/run_end.lua")
local run_start = dofile_once("mods/noita-telemetry/src/application/events/run_start.lua")
local safe_call = dofile_once("mods/noita-telemetry/src/application/safe_call.lua")
local inventory = dofile_once("mods/noita-telemetry/src/application/run/state/inventory.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
local ulid = dofile_once("mods/noita-telemetry/src/application/ulid.lua")
local status = dofile_once("mods/noita-telemetry/src/application/run/status.lua")

local M = {}

--- Prepares for the next player spawn after a world loads: resume the run whose file is
--- still open (save & quit), otherwise forget any stale marker and wait for a new run.
---@param state RunStateTable
function M.await_player(state)
  if writer.is_active() then
    return
  end

  local persisted = persistence.load()
  if persisted ~= nil and persistence.is_run_file_active(persisted.run_id) then
    state.lifecycle.resuming = true
  else
    persistence.clear()
    state.lifecycle.resuming = false
  end
  state.lifecycle.waiting_for_player = true
end

--- Closes the run file and forgets the run. upload=false is an abandon: the file is
--- closed only if still open and its pending upload is dropped.
---@param state RunStateTable
---@param upload boolean
function M.close(state, upload)
  if upload then
    writer.end_run()
    writer.process_pending_upload()
  elseif writer.is_active() then
    writer.end_run()
    writer.discard_pending_upload()
  end
  session.clear()
  persistence.clear()
  state.lifecycle.waiting_for_player = false
  state.run.end_snapshot = nil
  state.inventory.last_wands = nil
end

--- Stops recording this run without uploading it (NG+, post-clear worlds) and tells the player why.
---@param state RunStateTable
---@param reason_key string message key shown to the player
function M.abandon(state, reason_key)
  M.close(state, false)
  message.print(reason_key)
end

local function complete_finish(state, player, result)
  if not writer.is_active() then
    M.close(state, true)
    return
  end

  -- A failure while writing the closing events must not keep the run open.
  safe_call.silent(function()
    run_end.emit(state, player, result)
  end)

  M.close(state, true)
end

--- Ends the run as a win or a loss: closing events, run_end, then close with upload.
---@param state RunStateTable
---@param player integer|nil
---@param result "win"|"lose"
function M.finish(state, player, result)
  if not writer.is_active() then
    return
  end

  if state.run.end_snapshot == nil and player ~= nil then
    state.run.end_snapshot = finish_snapshot.capture(state, player)
  end

  complete_finish(state, player, result)
end

--- Starts recording a new run: opens the run file and session, then writes run_start.
---@param state RunStateTable
---@param player integer
function M.start(state, player)
  status.announce_startup()

  local scan = inventory_reader.scan_inventory(player)
  run_state_open.reset(state, player, scan)

  inventory.remember_wands(state.inventory, scan.wands)
  local id = ulid.generate()
  local started_at = emit.utc_timestamp()
  local header = run_header.read()

  writer.start_run(id, started_at, {
    seed = header.seed,
    game_mode = header.game_mode,
    mods_enabled = header.mods_enabled,
    noita_version = header.noita_version,
  })
  persistence.save(id, started_at, state.run.start_frame, state.run.started_stamp, state.run.world_seed)

  session.queue_open_run(id, started_at, header.seed, header.mods_enabled, header.game_mode, header.noita_version)

  run_start.emit(state, player, scan, header)
end

--- Continues the run whose file is still open after a save & quit; falls back to a new run
--- when the marker or the file is gone.
---@param state RunStateTable
---@param player integer
function M.resume(state, player)
  local persisted = persistence.load()
  if persisted == nil then
    M.start(state, player)
    return
  end

  if not persistence.is_run_file_active(persisted.run_id) then
    persistence.clear()
    M.start(state, player)
    return
  end

  local resumed = writer.resume_run(persisted.run_id, persisted.started_at)
  if resumed == nil then
    persistence.clear()
    M.start(state, player)
    return
  end

  local scan = inventory_reader.scan_inventory(player)
  run_state_open.reset(state, player, scan)
  state.inventory.prev_carried = scan.carried
  if persisted.run_start_frame ~= nil then
    state.run.start_frame = persisted.run_start_frame
  end
  if persisted.run_started_stamp ~= nil then
    state.run.started_stamp = persisted.run_started_stamp
  end
  if persisted.world_seed ~= nil then
    state.run.world_seed = persisted.world_seed
  end

  local header = run_header.read()
  session.queue_open_run(
    persisted.run_id,
    persisted.started_at,
    header.seed,
    header.mods_enabled,
    header.game_mode,
    header.noita_version
  )
end

return M
