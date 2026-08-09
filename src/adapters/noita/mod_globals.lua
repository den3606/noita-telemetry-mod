-- Generic Noita cross-save persistent storage reader/writer (`GlobalsGetValue` /
-- `GlobalsSetValue`). No telemetry knowledge; callers own key names and values.

local M = {}

function M.get(key, default)
  return GlobalsGetValue(key, default)
end

function M.set(key, value)
  GlobalsSetValue(key, value)
end

return M
