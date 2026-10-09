-- Generic FFI calling-convention helpers shared by every native/*.lua file:
-- decoding the trailing (error_buf, error_buf_len) pair every telemetry_*
-- export writes on failure, and safely checking whether a named export
-- exists on a given lib handle (older DLL builds may be missing newer
-- exports). Pure functions -- no DLL-loading state of its own, so this file
-- has no dependency on loader.lua.

local ffi = require("ffi")

local M = {}

function M.read_error(error_buf)
  return ffi.string(error_buf)
end

---@class NativeHttpFailure
---@field detail string
---@field http_status integer|nil
---@field api_code string|nil
---@field disallowed_mods string|nil comma-separated mod ids

local function non_empty(value)
  if value == "" then
    return nil
  end
  return value
end

--- Copy a telemetry_http_failure_t out of FFI memory.
---@return NativeHttpFailure
function M.read_http_failure(failure)
  local status = tonumber(failure.http_status)
  return {
    detail = ffi.string(failure.detail),
    http_status = status ~= 0 and status or nil,
    api_code = non_empty(ffi.string(failure.api_code)),
    disallowed_mods = non_empty(ffi.string(failure.disallowed_mods)),
  }
end

function M.native_export(lib, name)
  if lib == nil then
    return nil
  end
  local ok, export = pcall(function()
    return lib[name]
  end)
  if not ok then
    return nil
  end
  return export
end

return M
