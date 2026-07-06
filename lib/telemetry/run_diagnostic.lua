local config = dofile_once("mods/noita-telemetry/lib/telemetry/config.lua")
local error_phases = dofile_once("mods/noita-telemetry/lib/telemetry/error_phases.lua")
local errors = dofile_once("mods/noita-telemetry/lib/telemetry/errors.lua")
local native = dofile_once("mods/noita-telemetry/lib/telemetry/native.lua")

local M = {}

local function utc_timestamp()
  if os.date ~= nil then
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
  end
  return ""
end

local function run_id_from_path(run_path)
  if type(run_path) ~= "string" then
    return nil
  end
  return run_path:match("([^/]+)%.run$")
end

local function write_line(run_path, line)
  local run_id = run_id_from_path(run_path)
  if run_id == nil then
    return false
  end

  local file = io.open(run_path, "a")
  if file ~= nil then
    file:write(line)
    file:write("\n")
    file:flush()
    file:close()
    return true
  end

  local logger = dofile_once("mods/noita-telemetry/lib/telemetry/logger.lua")
  if type(logger.append_diagnostic_line) == "function" and logger.append_diagnostic_line(line) then
    return true
  end

  if native.available() and native.run_append_diagnostic ~= nil then
    local ok, err = native.run_append_diagnostic(config.runs_dir, run_id, line)
    if ok then
      return true
    end
    print("[NoitaTelemetry] WARN run diagnostic native append failed: " .. tostring(err or ""))
  end

  return false
end

function M.path_for_run_id(run_id)
  if type(run_id) ~= "string" or run_id == "" then
    return nil
  end
  return config.runs_dir .. "/" .. run_id .. ".run"
end

function M.append_error(run_path, phase, err, ctx)
  if type(run_path) ~= "string" or run_path == "" then
    return false
  end
  if type(phase) ~= "string" or phase == "" then
    return false
  end
  error_phases.warn_if_unknown(phase)
  if err == nil or err == "disabled" then
    return false
  end

  ctx = ctx or {}
  if ctx.at == nil or ctx.at == "" then
    ctx.at = utc_timestamp()
  end

  local line = errors.encode_error_record(errors.build_error_record(phase, err, ctx))
  return write_line(run_path, line)
end

return M
