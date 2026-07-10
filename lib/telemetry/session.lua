local config = dofile_once("mods/noita-telemetry/lib/telemetry/config.lua")
local error_phases = dofile_once("mods/noita-telemetry/lib/telemetry/error_phases.lua")
local errors = dofile_once("mods/noita-telemetry/lib/telemetry/errors.lua")
local i18n = dofile_once("mods/noita-telemetry/lib/telemetry/i18n.lua")
local json = dofile_once("mods/noita-telemetry/lib/telemetry/json.lua")
local link = dofile_once("mods/noita-telemetry/lib/telemetry/link.lua")
local native = dofile_once("mods/noita-telemetry/lib/telemetry/native.lua")
local run_diagnostic = dofile_once("mods/noita-telemetry/lib/telemetry/run_diagnostic.lua")

local M = {}

local ingest_token = nil
local active_run_id = nil
local open_context = nil

local OPEN_RETRY_SEC = 3
local MAX_OPEN_ATTEMPTS = 3

local function http_target_label(url)
  if type(url) ~= "string" or url == "" then
    return "?"
  end
  return url:gsub("%?.*", "")
end

local function schedule_open_retry()
  if open_context ~= nil then
    open_context.retry_at_sec = os.time() + OPEN_RETRY_SEC
  end
end

local function begin_open_attempt()
  if open_context == nil then
    return false
  end

  open_context.attempt_count = (open_context.attempt_count or 0) + 1
  return true
end

local INGEST_SUFFIX = "/mod/ingest"
local OPEN_SUFFIX = "/mod/runs/open"

local function runs_open_url(api_url)
  if api_url:sub(-#INGEST_SUFFIX) == INGEST_SUFFIX then
    return api_url:sub(1, #api_url - #INGEST_SUFFIX) .. OPEN_SUFFIX
  end
  return api_url:gsub("/?$", "") .. OPEN_SUFFIX
end

local function clear_open_context()
  open_context = nil
end

local function open_diag_ctx(run_id, phase)
  local ctx = {
    phase = phase,
    run_path = run_diagnostic.path_for_run_id(run_id),
    http_method = "POST",
  }
  if open_context ~= nil then
    ctx.http_target = http_target_label(open_context.url)
    ctx.retry = {
      attempt = open_context.attempt_count,
      max = MAX_OPEN_ATTEMPTS,
    }
  end
  return ctx
end

local function notify_open_failure(run_id, phase, err)
  local diag_ctx = open_diag_ctx(run_id, phase)
  clear_open_context()
  errors.notify_player(err, nil, diag_ctx, "connect_failed")
  return select(1, errors.resolve(err))
end

local function open_attempts_exhausted()
  return open_context ~= nil and open_context.attempt_count >= MAX_OPEN_ATTEMPTS
end

local function handle_retryable_open_failure(err)
  schedule_open_retry()
  i18n.emit("connect_retry", {
    attempt = open_context.attempt_count,
    max = MAX_OPEN_ATTEMPTS,
  })
end

local function record_retryable_open_failure(run_id, phase, err)
  err = err or "http_failed"
  if not errors.is_retryable_api_err(err) then
    notify_open_failure(run_id, phase, err)
    return
  end
  if open_attempts_exhausted() then
    notify_open_failure(run_id, phase, err)
    return
  end

  errors.record_to_run(err, nil, open_diag_ctx(run_id, phase))
  handle_retryable_open_failure(err)
end

local function open_retry_due()
  return open_context ~= nil
    and open_context.retry_at_sec ~= nil
    and os.time() >= open_context.retry_at_sec
end

local function is_retryable_err(err)
  return errors.is_retryable_api_err(err)
end

local function parse_open_error_response(response)
  local wire = errors.parse_error_wire_json(response)
  if wire ~= nil and type(wire.message) == "string" and wire.message ~= "" then
    return wire.message
  end
  return response:match('"message"%s*:%s*"([^"]+)"')
    or response:match('"error"%s*:%s*"([^"]+)"')
end

local function parse_open_response(response)
  if response == nil or response == "" then
    return nil
  end

  if response:find('"ok"%s*:%s*true') then
    local token = response:match('"ingest_token"%s*:%s*"([^"]+)"')
    if token ~= nil then
      return { ok = true, ingest_token = token }
    end
  end

  local error_code = parse_open_error_response(response)
  return { ok = false, error = error_code, response = response }
end

local function apply_open_success(run_id, parsed)
  ingest_token = parsed.ingest_token
  active_run_id = run_id
  i18n.emit("status_connect_ok")
end

local function build_open_body(run_id, started_at, seed, mods_enabled, game_mode, noita_version)
  return json.encode({
    run_id = run_id,
    started_at = started_at,
    seed = seed,
    game_mode = game_mode,
    noita_version = noita_version,
    mods_enabled = mods_enabled or {},
    client_version = config.client_version,
    schema_version = "2",
  })
end

local function start_async_open()
  if not begin_open_attempt() then
    return
  end

  local run_id = open_context.run_id
  local ok, err = native.http_request_async(
    "POST",
    open_context.url,
    open_context.mod_token,
    open_context.body
  )
  if not ok then
    if err == errors.native_export_missing then
      notify_open_failure(run_id, error_phases.sync.open.http_start, err)
      return
    end

    if is_retryable_err(err or "http_failed") then
      record_retryable_open_failure(run_id, error_phases.sync.open.http_start, err or "http_failed")
    else
      notify_open_failure(run_id, error_phases.sync.open.http_start, err or "http_failed")
    end
  end
end

function M.get_ingest_token()
  return ingest_token
end

function M.get_active_run_id()
  return active_run_id
end

function M.clear()
  ingest_token = nil
  active_run_id = nil
  clear_open_context()
end

function M.is_open_pending()
  return open_context ~= nil
end

function M.queue_open_run(run_id, started_at, seed, mods_enabled, game_mode, noita_version)
  M.clear()

  local sync = config.get_sync()
  if sync == nil or sync.enabled ~= true then
    return true
  end

  local mod_token = link.get_mod_token()
  if mod_token == nil then
    return false, notify_open_failure(run_id, error_phases.sync.open.queue, "not_authenticated")
  end

  open_context = {
    run_id = run_id,
    url = runs_open_url(sync.api_url),
    mod_token = mod_token,
    body = build_open_body(run_id, started_at, seed, mods_enabled, game_mode, noita_version),
    retry_at_sec = nil,
    attempt_count = 0,
  }

  local logger = dofile_once("mods/noita-telemetry/lib/telemetry/logger.lua")
  logger.patch_header(run_id, {
    game_mode = game_mode,
    noita_version = noita_version,
    mods_enabled = mods_enabled or {},
  })

  i18n.emit("status_connecting")
  start_async_open()
  return true
end

function M.poll_open()
  if open_context == nil then
    native.http_request_poll()
    return
  end

  if ingest_token ~= nil then
    clear_open_context()
    return
  end

  local run_id = open_context.run_id
  local status, response, err = native.http_request_poll()
  if status == "running" then
    return
  end

  if status == "idle" then
    if open_retry_due() then
      open_context.retry_at_sec = nil
      start_async_open()
    end
    return
  end

  if status == "success" then
    local parsed = parse_open_response(response)
    if type(parsed) == "table" and parsed.ok == true and type(parsed.ingest_token) == "string" then
      apply_open_success(open_context.run_id, parsed)
      clear_open_context()
      return
    end
    err = (type(parsed) == "table" and parsed.error) or "invalid_response"
    if type(parsed) == "table" and type(parsed.response) == "string" then
      err = parsed.response
    end
  elseif status ~= "failed" then
    return
  end

  err = err or "http_failed"
  if not is_retryable_err(err) then
    notify_open_failure(run_id, error_phases.sync.open.http_poll, err)
    return
  end

  record_retryable_open_failure(run_id, error_phases.sync.open.http_poll, err)
end

return M
