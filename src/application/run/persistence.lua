local mod_globals = dofile_once("mods/noita-telemetry/src/adapters/noita/mod_globals.lua")
local run_file = dofile_once("mods/noita-telemetry/src/adapters/native/run_file.lua")
local writer = dofile_once("mods/noita-telemetry/src/application/run/writer.lua")

local M = {}

local KEY_RUN_ID = "noita_telemetry_active_run_id"
local KEY_STARTED_AT = "noita_telemetry_active_started_at"
local KEY_RUN_START_FRAME = "noita_telemetry_active_run_start_frame"
local KEY_RUN_STARTED_STAMP = "noita_telemetry_active_run_started_stamp"
local KEY_WORLD_SEED = "noita_telemetry_active_world_seed"

--- A resume is only worth attempting while the .run file has no footer yet.
function M.is_run_file_active(run_id)
  if run_id == nil or run_id == "" then
    return false
  end

  return run_file.run_is_active(writer.get_runs_dir(), run_id) == true
end

function M.load()
  local run_id = mod_globals.get(KEY_RUN_ID, "")
  local started_at = mod_globals.get(KEY_STARTED_AT, "")
  if run_id == "" or started_at == "" then
    return nil
  end

  local run_start_frame = tonumber(mod_globals.get(KEY_RUN_START_FRAME, ""))
  local run_started_stamp = mod_globals.get(KEY_RUN_STARTED_STAMP, "")
  local world_seed = tonumber(mod_globals.get(KEY_WORLD_SEED, ""))
  return {
    run_id = run_id,
    started_at = started_at,
    run_start_frame = run_start_frame,
    run_started_stamp = run_started_stamp ~= "" and run_started_stamp or nil,
    world_seed = world_seed,
  }
end

function M.save(run_id, started_at, run_start_frame, run_started_stamp, world_seed)
  mod_globals.set(KEY_RUN_ID, run_id)
  mod_globals.set(KEY_STARTED_AT, started_at)
  mod_globals.set(KEY_RUN_START_FRAME, tostring(run_start_frame or 0))
  mod_globals.set(KEY_RUN_STARTED_STAMP, run_started_stamp or "")
  mod_globals.set(KEY_WORLD_SEED, world_seed ~= nil and tostring(world_seed) or "")
end

function M.clear()
  mod_globals.set(KEY_RUN_ID, "")
  mod_globals.set(KEY_STARTED_AT, "")
  mod_globals.set(KEY_RUN_START_FRAME, "")
  mod_globals.set(KEY_RUN_STARTED_STAMP, "")
  mod_globals.set(KEY_WORLD_SEED, "")
end

return M
