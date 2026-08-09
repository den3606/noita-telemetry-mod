local sync_settings = dofile_once("mods/noita-telemetry/src/core/run/sync_settings.lua")
local error_phases = dofile_once("mods/noita-telemetry/src/core/error_phases.lua")
local message = dofile_once("mods/noita-telemetry/src/core/messaging.lua")
local run_file = dofile_once("mods/noita-telemetry/src/adapters/native/run_file.lua")
local upload = dofile_once("mods/noita-telemetry/src/adapters/native/upload.lua")
local session = dofile_once("mods/noita-telemetry/src/core/run/session.lua")

local M = {}

local pending_upload_path = nil
local pending_upload_target = nil

local function http_target_label(url)
  if type(url) ~= "string" or url == "" then
    return "?"
  end
  return url:gsub("%?.*", "")
end

local function delete_run_file(run_path)
  if type(run_path) ~= "string" or run_path == "" then
    return false, "invalid_path"
  end

  local ok, err = run_file.run_delete(run_path)
  if ok then
    return true
  end

  return false, tostring(err or "delete_failed")
end

local function upload_diag_ctx(phase)
  return {
    phase = phase,
    http_method = "POST",
    http_target = pending_upload_target,
  }
end

local function upload_context()
  local sync = sync_settings.get()
  if sync.enabled ~= true then
    return nil, "disabled"
  end

  local token = session.get_ingest_token()
  if token == nil then
    return nil, "no_ingest_session"
  end

  return {
    ingest_url = sync.ingest_url,
    token = token,
    delete_run_after_upload = sync.delete_run_after_upload == true,
  }
end

function M.start_upload_run(run_path)
  -- One in-flight upload at a time (also enforces one send attempt per finished run).
  if pending_upload_path ~= nil then
    return false, "upload_in_flight", upload_diag_ctx(error_phases.sync.upload.queue)
  end

  local ctx, err = upload_context()
  if ctx == nil then
    return false, err, upload_diag_ctx(error_phases.sync.upload.queue)
  end

  pending_upload_target = http_target_label(ctx.ingest_url)

  local ok, start_err = upload.upload_file_async(ctx.ingest_url, ctx.token, run_path)
  if not ok then
    return false, start_err, upload_diag_ctx(error_phases.sync.upload.http_start)
  end

  pending_upload_path = run_path
  return true
end

function M.poll_upload()
  local status, err = upload.upload_poll()
  if status == "idle" or status == "running" then
    return
  end

  local run_path = pending_upload_path
  pending_upload_path = nil
  pending_upload_target = nil

  if status == "success" then
    message.print_console(message.KEYS.MSG_SYNC_UPLOADED)

    local sync = sync_settings.get()
    if sync.delete_run_after_upload == true and run_path ~= nil then
      local deleted, delete_err = delete_run_file(run_path)
      if not deleted then
        message.error(message.KEYS.MSG_ERROR_LOGGER_RUN_DELETE_FAILED, { path = run_path, err = delete_err or "" }, {
          phase = error_phases.writer.close,
        })
      end
    end
    return
  end

  if err == "disabled" then
    return
  end

  message.notify_player(err, nil, upload_diag_ctx(error_phases.sync.upload.http_poll), message.KEYS.MSG_DATA_SEND_FAILED)
end

return M
