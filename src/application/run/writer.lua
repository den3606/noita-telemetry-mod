-- Writes the .run file for one run: header, events, and footer, plus the
-- header patch applied on close. All file access goes through the native
-- writer  Ethe MOD refuses to record without the DLL, so there is no Lua io
-- fallback to keep in sync (and mixing the two reordered lines).

local client_version = dofile_once("mods/noita-telemetry/src/resources/client_version.lua")
local message = dofile_once("mods/noita-telemetry/src/application/messaging.lua")

local json = dofile_once("mods/noita-telemetry/src/libs/json.lua")
local run_file = dofile_once("mods/noita-telemetry/src/adapters/native/run_file.lua")

local RUNS_DIR = "mods/noita-telemetry/runs"

local M = {}

local current_run = nil
local pending_upload_path = nil
local append_error_reported = false
local pending_header_patch = nil

local function reset_run_errors()
  append_error_reported = false
  pending_header_patch = nil
end

local function join_path(dir, name)
  return dir .. "/" .. name
end

function M.get_runs_dir()
  return RUNS_DIR
end

local function run_file_path(id)
  return join_path(M.get_runs_dir(), id .. ".run")
end

local function utc_timestamp()
  if os.date ~= nil then
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
  end
  return ""
end

local function write_header(meta)
  meta = meta or {}
  local payload = {
    event = "header",
    version = "2",
    at = meta.at,
    run_id = meta.run_id,
    client_version = meta.client_version or client_version.client_version,
    noita_version = meta.noita_version,
    seed = meta.seed,
    game_mode = meta.game_mode or "normal",
    mods_enabled = meta.mods_enabled or {},
  }
  if meta.is_win == true or meta.is_win == false then
    payload.is_win = meta.is_win
  end
  return json.encode(payload)
end

--- The header can only be rewritten once the writer released the file, so a
--- patch for the run in progress is held until end_run().
function M.patch_header(run_id, fields)
  if type(run_id) ~= "string" or run_id == "" or type(fields) ~= "table" then
    return false
  end
  if current_run ~= nil and current_run.ended ~= true and current_run.id == run_id then
    pending_header_patch = pending_header_patch or {}
    for key, value in pairs(fields) do
      pending_header_patch[key] = value
    end
    return true
  end

  local ok = run_file.run_patch_header(M.get_runs_dir(), run_id, json.encode(fields))
  return ok == true
end

local function finalize_header_for_upload(run_id, is_win)
  local fields = {}
  if pending_header_patch ~= nil then
    for key, value in pairs(pending_header_patch) do
      fields[key] = value
    end
    pending_header_patch = nil
  end
  if is_win == true or is_win == false then
    fields.is_win = is_win
  end
  if next(fields) == nil then
    return
  end
  run_file.run_patch_header(M.get_runs_dir(), run_id, json.encode(fields))
end

local function write_footer(is_win)
  local payload = {
    event = "footer",
    at = utc_timestamp(),
  }
  if is_win == true or is_win == false then
    payload.is_win = is_win
  end
  return json.encode(payload)
end

function M.start_run(id, started_at, header_meta)
  reset_run_errors()

  current_run = {
    id = id,
    started_at = started_at,
    ended = false,
    is_win = nil,
  }

  header_meta = header_meta or {}
  local header_json = write_header({
    at = started_at,
    run_id = id,
    client_version = client_version.client_version,
    noita_version = header_meta.noita_version,
    seed = header_meta.seed,
    game_mode = header_meta.game_mode,
    mods_enabled = header_meta.mods_enabled,
  })

  local ok, err = run_file.run_open(M.get_runs_dir(), id, header_json)
  if not ok then
    message.error(
      message.KEYS.MSG_ERROR_LOGGER_RUN_OPEN_FAILED,
      { path = run_file_path(id), err = tostring(err or "") }
    )
    current_run = nil
    return nil
  end

  return current_run
end

function M.resume_run(id, started_at)
  reset_run_errors()
  current_run = {
    id = id,
    started_at = started_at,
    ended = false,
    is_win = nil,
  }

  local ok, err = run_file.run_resume(M.get_runs_dir(), id)
  if not ok then
    message.error(
      message.KEYS.MSG_ERROR_LOGGER_RUN_OPEN_FAILED,
      { path = run_file_path(id), err = tostring(err or "") }
    )
    current_run = nil
    return nil
  end

  return current_run
end

function M.is_active()
  return current_run ~= nil and current_run.ended ~= true
end

function M.append_event(event)
  if current_run == nil then
    return false
  end

  if event.event == "run_end" then
    if event.result == "win" then
      current_run.is_win = true
    elseif event.result == "lose" then
      current_run.is_win = false
    end
  end

  local ok, err = run_file.run_append(json.encode(event))
  if not ok then
    if not append_error_reported then
      append_error_reported = true
      message.error(message.KEYS.MSG_ERROR_LOGGER_RUN_APPEND_FAILED, { err = tostring(err) })
    end
    return false
  end
  return true
end

function M.end_run()
  if current_run == nil then
    return
  end

  current_run.ended = true
  local footer_json = write_footer(current_run.is_win)
  local path = run_file_path(current_run.id)

  local ok, err = run_file.run_close(M.get_runs_dir(), current_run.id, footer_json)
  if not ok then
    message.error(message.KEYS.MSG_ERROR_LOGGER_RUN_CLOSE_FAILED, { err = tostring(err or "") })
  end

  finalize_header_for_upload(current_run.id, current_run.is_win)
  -- Queue at most one upload per finished run.
  pending_upload_path = path
  current_run = nil
end

function M.discard_pending_upload()
  pending_upload_path = nil
end

function M.process_pending_upload()
  local path = pending_upload_path
  if path == nil then
    return
  end

  pending_upload_path = nil
  -- Lazy: sync ↁEsession ↁElogger would cycle if sync were required at load.
  local sync = dofile_once("mods/noita-telemetry/src/application/run/sync.lua")
  pcall(sync.start_upload_run, path)
end

function M.poll_upload()
  local sync = dofile_once("mods/noita-telemetry/src/application/run/sync.lua")
  pcall(sync.poll_upload)
end

return M
