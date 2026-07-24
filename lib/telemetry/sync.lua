local config = dofile_once("mods/noita-telemetry/lib/telemetry/config.lua")
local error_phases = dofile_once("mods/noita-telemetry/lib/telemetry/error_phases.lua")
local errors = dofile_once("mods/noita-telemetry/lib/telemetry/errors.lua")
local i18n = dofile_once("mods/noita-telemetry/lib/telemetry/i18n.lua")
local native = dofile_once("mods/noita-telemetry/lib/telemetry/native.lua")
local session = dofile_once("mods/noita-telemetry/lib/telemetry/session.lua")

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

  if os.remove == nil then
    return false, "io_unavailable"
  end

  local ok, err = os.remove(run_path)
  if ok then
    return true
  end

  return false, tostring(err or "delete_failed")
end

local function upload_diag_ctx(run_path, phase)
  return {
    phase = phase,
    run_path = run_path,
    http_method = "POST",
    http_target = pending_upload_target,
  }
end

local function upload_context()
  local sync, err_code = config.get_sync()
  if sync == nil then
    return nil, err_code or errors.telemetry_not_ready
  end
  if sync.enabled ~= true then
    return nil, "disabled"
  end

  local token = session.get_ingest_token()
  if token == nil then
    return nil, "no_ingest_session"
  end

  return {
    api_url = sync.api_url,
    token = token,
    delete_run_after_upload = sync.delete_run_after_upload == true,
  }
end

function M.upload_run(run_path)
  local ctx, err = upload_context()
  if ctx == nil then
    return false, err
  end

  return native.upload_file(ctx.api_url, ctx.token, run_path)
end

function M.start_upload_run(run_path)
  -- One in-flight upload at a time (also enforces one send attempt per finished run).
  if pending_upload_path ~= nil then
    return false, "upload_in_flight", upload_diag_ctx(run_path, error_phases.sync.upload.queue)
  end

  local ctx, err = upload_context()
  if ctx == nil then
    return false, err, upload_diag_ctx(run_path, error_phases.sync.upload.queue)
  end

  pending_upload_target = http_target_label(ctx.api_url)

  local ok, start_err = native.upload_file_async(ctx.api_url, ctx.token, run_path)
  if not ok then
    return false, start_err, upload_diag_ctx(run_path, error_phases.sync.upload.http_start)
  end

  pending_upload_path = run_path
  return true
end

function M.poll_upload()
  local status, err = native.upload_poll()
  if status == "idle" or status == "running" then
    return
  end

  local run_path = pending_upload_path
  pending_upload_path = nil
  pending_upload_target = nil

  if status == "success" then
    i18n.emit_console("sync_uploaded")

    local sync = config.get_sync()
    if sync ~= nil and sync.delete_run_after_upload == true and run_path ~= nil then
      local deleted, delete_err = delete_run_file(run_path)
      if not deleted then
        errors.print(errors.logger_run_delete_failed, { path = run_path, err = delete_err or "" }, {
          phase = error_phases.logger.close,
          run_path = run_path,
        })
      end
    end
    return
  end

  if err == "disabled" then
    return
  end

  errors.notify_player(err, nil, upload_diag_ctx(run_path, error_phases.sync.upload.http_poll), "data_send_failed")
end

function M.try_upload_run(run_path)
  local ok, err, diag_ctx = M.start_upload_run(run_path)
  if ok then
    return true
  end

  if err == "disabled" or err == "upload_in_flight" then
    return false
  end

  errors.notify_player(err, nil, diag_ctx, "data_send_failed")
  return false
end

return M
