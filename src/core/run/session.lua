local client_version = dofile_once("mods/noita-telemetry/src/core/client_version.lua")
local sync_settings = dofile_once("mods/noita-telemetry/src/core/run/sync_settings.lua")
local error_phases = dofile_once("mods/noita-telemetry/src/core/error_phases.lua")
local message = dofile_once("mods/noita-telemetry/src/core/messaging.lua")
local json = dofile_once("mods/noita-telemetry/src/libs/json.lua")
local token = dofile_once("mods/noita-telemetry/src/core/token.lua")
local http = dofile_once("mods/noita-telemetry/src/adapters/native/http.lua")
local writer = dofile_once("mods/noita-telemetry/src/core/run/writer.lua")
local streak_align = dofile_once("mods/noita-telemetry/src/core/run/streak_align.lua")
local streak_patch = dofile_once("mods/noita-telemetry/src/core/streak.lua")

local M = {}

local ingest_token = nil
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

local function clear_open_context()
  open_context = nil
end

local function open_diag_ctx(phase)
  local ctx = {
    phase = phase,
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

local function notify_open_failure(phase, err)
  local diag_ctx = open_diag_ctx(phase)
  clear_open_context()
  message.notify_player(err, nil, diag_ctx, message.KEYS.MSG_CONNECT_FAILED)
  return select(1, message.resolve(err))
end

local function open_attempts_exhausted()
  return open_context ~= nil and open_context.attempt_count >= MAX_OPEN_ATTEMPTS
end

local function handle_retryable_open_failure(err)
  schedule_open_retry()
  message.print(message.KEYS.MSG_CONNECT_RETRY, {
    attempt = open_context.attempt_count,
    max = MAX_OPEN_ATTEMPTS,
  })
end

local function record_retryable_open_failure(phase, err)
  err = err or "http_failed"
  if not message.is_retryable_api_err(err) then
    notify_open_failure(phase, err)
    return
  end
  if open_attempts_exhausted() then
    notify_open_failure(phase, err)
    return
  end

  handle_retryable_open_failure(err)
end

local function open_retry_due()
  return open_context ~= nil
    and open_context.retry_at_sec ~= nil
    and os.time() >= open_context.retry_at_sec
end

local function is_retryable_err(err)
  return message.is_retryable_api_err(err)
end

local function parse_open_error_response(response)
  local wire = message.parse_error_wire_json(response)
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

  -- Success is HTTP 2xx from native; body carries ingest_token (no ok wrapper).
  local token = response:match('"ingest_token"%s*:%s*"([^"]+)"')
  if token ~= nil then
    return { ok = true, ingest_token = token }
  end

  local error_code = parse_open_error_response(response)
  return { ok = false, error = error_code, response = response }
end

local function apply_open_success(run_id, parsed, open_ctx)
  ingest_token = parsed.ingest_token
  message.print(message.KEYS.MSG_STATUS_CONNECT_OK)
  if open_ctx == nil or not streak_patch.is_enabled() then
    return
  end
  streak_align.queue_after_open(
    open_ctx.current_streak_url,
    open_ctx.mod_token,
    open_ctx.game_mode,
    open_ctx.noita_version
  )
end

local function build_open_body(run_id, started_at, seed, mods_enabled, game_mode, noita_version)
  return json.encode({
    run_id = run_id,
    started_at = started_at,
    seed = seed,
    game_mode = game_mode,
    noita_version = noita_version,
    mods_enabled = mods_enabled or {},
    client_version = client_version.client_version,
    schema_version = "2",
  })
end

local function start_async_open()
  if not begin_open_attempt() then
    return
  end

  local run_id = open_context.run_id
  -- quiet: player-facing status is MSG_STATUS_CONNECTING / MSG_STATUS_CONNECT_OK only.
  local ok, err = http.http_request_async(
    "POST",
    open_context.url,
    open_context.mod_token,
    open_context.body,
    { quiet = true }
  )
  if not ok then
    if err == message.KEYS.MSG_ERROR_NATIVE_EXPORT_MISSING then
      notify_open_failure(error_phases.sync.open.http_start, err)
      return
    end

    if is_retryable_err(err or "http_failed") then
      record_retryable_open_failure(error_phases.sync.open.http_start, err or "http_failed")
    else
      notify_open_failure(error_phases.sync.open.http_start, err or "http_failed")
    end
  end
end

function M.get_ingest_token()
  return ingest_token
end

function M.clear()
  ingest_token = nil
  clear_open_context()
  streak_align.clear()
end

function M.queue_open_run(run_id, started_at, seed, mods_enabled, game_mode, noita_version)
  M.clear()

  local sync = sync_settings.get()
  if sync.enabled ~= true then
    return true
  end

  local mod_token = token.get()
  if mod_token == nil then
    return false, notify_open_failure(error_phases.sync.open.queue, "not_authenticated")
  end

  open_context = {
    run_id = run_id,
    url = sync.runs_open_url,
    current_streak_url = sync.current_streak_url,
    mod_token = mod_token,
    game_mode = game_mode,
    noita_version = noita_version,
    body = build_open_body(run_id, started_at, seed, mods_enabled, game_mode, noita_version),
    retry_at_sec = nil,
    attempt_count = 0,
  }

  writer.patch_header(run_id, {
    game_mode = game_mode,
    noita_version = noita_version,
    mods_enabled = mods_enabled or {},
  })

  message.print(message.KEYS.MSG_STATUS_CONNECTING)
  start_async_open()
  return true
end

function M.poll_open()
  if open_context == nil then
    if streak_align.is_pending() then
      streak_align.poll()
    end
    return
  end

  if ingest_token ~= nil then
    clear_open_context()
    if streak_align.is_pending() then
      streak_align.poll()
    end
    return
  end

  local run_id = open_context.run_id
  local status, response, err = http.http_request_poll()
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
      local open_ctx = open_context
      apply_open_success(open_ctx.run_id, parsed, open_ctx)
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
    notify_open_failure(error_phases.sync.open.http_poll, err)
    return
  end

  record_retryable_open_failure(error_phases.sync.open.http_poll, err)
end

return M
