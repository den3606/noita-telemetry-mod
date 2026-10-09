local client_version = dofile_once("mods/noita-telemetry/src/resources/client_version.lua")
local sync_settings = dofile_once("mods/noita-telemetry/src/application/run/sync_settings.lua")
local error_phases = dofile_once("mods/noita-telemetry/src/application/error_phases.lua")
local message = dofile_once("mods/noita-telemetry/src/application/messaging.lua")
local json = dofile_once("mods/noita-telemetry/src/libs/json.lua")
local token = dofile_once("mods/noita-telemetry/src/adapters/native/token_file.lua")
local http = dofile_once("mods/noita-telemetry/src/adapters/native/http.lua")
local http_log = dofile_once("mods/noita-telemetry/src/application/run/http_log.lua")
local writer = dofile_once("mods/noita-telemetry/src/application/run/writer.lua")
local streak_align = dofile_once("mods/noita-telemetry/src/application/run/streak_align.lua")
local streak_patch = dofile_once("mods/noita-telemetry/src/application/streak.lua")

local M = {}

---@class OpenRunContext
---@field run_id string
---@field url string
---@field current_streak_url string
---@field mod_token string
---@field game_mode string
---@field noita_version string
---@field body string

local ingest_token = nil
---@type OpenRunContext|nil
local open_context = nil

local function clear_open_context()
  open_context = nil
end

local function open_diag_ctx(phase)
  local ctx = {
    phase = phase,
    http_method = "POST",
  }
  if open_context ~= nil then
    ctx.http_target = http_log.target_label(open_context.url)
  end
  return ctx
end

local function notify_open_failure(phase, err)
  local diag_ctx = open_diag_ctx(phase)
  clear_open_context()
  message.notify_player(err, nil, diag_ctx, message.KEYS.MSG_CONNECT_FAILED)
  return select(1, message.resolve(err))
end

--- Open succeeds with HTTP 2xx and `ingest_token`; any other body is reported by its API message.
---@return string|nil token
---@return string|nil err
local function parse_open_response(response)
  local ok, body = pcall(json.decode, response or "")
  if ok and type(body) == "table" and type(body.ingest_token) == "string" and body.ingest_token ~= "" then
    return body.ingest_token, nil
  end
  local wire = message.parse_error_wire_json(response)
  return nil, wire ~= nil and wire.message or "invalid_response"
end

local function apply_open_success(token, open_ctx)
  ingest_token = token
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
  local ctx = open_context
  if ctx == nil then
    return
  end

  local ok, err = http.http_request_async("POST", ctx.url, ctx.mod_token, ctx.body)
  if not ok then
    http_log.request("POST", ctx.url, false, err)
    notify_open_failure(error_phases.sync.open.http_start, err or "http_failed")
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

  local status, response, failure = http.http_request_poll()
  if status == "success" or status == "failed" then
    http_log.request("POST", open_context.url, status == "success", failure)
  end
  if status == "success" then
    local token, open_err = parse_open_response(response)
    if token ~= nil then
      apply_open_success(token, open_context)
      clear_open_context()
      return
    end
    notify_open_failure(error_phases.sync.open.http_poll, open_err)
  elseif status == "failed" then
    notify_open_failure(error_phases.sync.open.http_poll, failure or "http_failed")
  end
end

return M
