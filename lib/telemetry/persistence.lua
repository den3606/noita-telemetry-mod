local config = dofile_once("mods/noita-telemetry/lib/telemetry/config.lua")

local M = {}

local KEY_RUN_ID = "noita_telemetry_active_run_id"
local KEY_STARTED_AT = "noita_telemetry_active_started_at"
local KEY_RUN_START_FRAME = "noita_telemetry_active_run_start_frame"
local KEY_RUN_STARTED_STAMP = "noita_telemetry_active_run_started_stamp"
local KEY_WORLD_SEED = "noita_telemetry_active_world_seed"

local function globals_available()
  return GlobalsGetValue ~= nil and GlobalsSetValue ~= nil
end

local function join_path(dir, name)
  return dir .. "/" .. name
end

local function run_file_path(run_id)
  return join_path(config.runs_dir, run_id .. ".run")
end

local function read_last_nonempty_line(path)
  local file = io.open(path, "r")
  if file == nil then
    return nil
  end

  local last_line = nil
  for line in file:lines() do
    if line:match("%S") then
      last_line = line
    end
  end
  file:close()
  return last_line
end

local function run_file_has_footer(path)
  local file = io.open(path, "r")
  if file == nil then
    return false
  end

  for line in file:lines() do
    if line:find('"event"%s*:%s*"footer"') then
      file:close()
      return true
    end
  end

  file:close()
  return false
end

function M.is_run_file_active(run_id)
  if run_id == nil or run_id == "" then
    return false
  end

  local path = run_file_path(run_id)
  if run_file_has_footer(path) then
    return false
  end

  local last_line = read_last_nonempty_line(path)
  if last_line == nil then
    return false
  end

  if last_line:find('"event"%s*:%s*"footer"') then
    return false
  end
  if last_line:find('"ended"%s*:%s*true') then
    return false
  end

  return true
end

function M.load()
  if not globals_available() then
    return nil
  end

  local run_id = GlobalsGetValue(KEY_RUN_ID, "")
  local started_at = GlobalsGetValue(KEY_STARTED_AT, "")
  if run_id == "" or started_at == "" then
    return nil
  end

  local run_start_frame = tonumber(GlobalsGetValue(KEY_RUN_START_FRAME, ""))
  local run_started_stamp = GlobalsGetValue(KEY_RUN_STARTED_STAMP, "")
  local world_seed = tonumber(GlobalsGetValue(KEY_WORLD_SEED, ""))
  return {
    run_id = run_id,
    started_at = started_at,
    run_start_frame = run_start_frame,
    run_started_stamp = run_started_stamp ~= "" and run_started_stamp or nil,
    world_seed = world_seed,
  }
end

function M.has_active()
  return M.load() ~= nil
end

function M.save(run_id, started_at, run_start_frame, run_started_stamp, world_seed)
  if not globals_available() then
    return
  end

  GlobalsSetValue(KEY_RUN_ID, run_id)
  GlobalsSetValue(KEY_STARTED_AT, started_at)
  GlobalsSetValue(KEY_RUN_START_FRAME, tostring(run_start_frame or 0))
  GlobalsSetValue(KEY_RUN_STARTED_STAMP, run_started_stamp or "")
  GlobalsSetValue(KEY_WORLD_SEED, world_seed ~= nil and tostring(world_seed) or "")
end

function M.clear()
  if not globals_available() then
    return
  end

  GlobalsSetValue(KEY_RUN_ID, "")
  GlobalsSetValue(KEY_STARTED_AT, "")
  GlobalsSetValue(KEY_RUN_START_FRAME, "")
  GlobalsSetValue(KEY_RUN_STARTED_STAMP, "")
  GlobalsSetValue(KEY_WORLD_SEED, "")
end

return M
