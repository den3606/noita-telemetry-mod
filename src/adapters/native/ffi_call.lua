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
