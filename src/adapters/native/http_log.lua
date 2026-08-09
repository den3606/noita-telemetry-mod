-- Shared "did this network call succeed" logging for http.lua and upload.lua.
-- Not transport: only label + message.print(_console) helpers.

local message = dofile_once("mods/noita-telemetry/src/core/messaging.lua")

local M = {}

function M.target_label(url)
  if type(url) ~= "string" or url == "" then
    return "?"
  end
  return url:gsub("%?.*", "")
end

function M.emit_log(method, target, ok, err, upload)
  local detail = err
  if type(err) == "string" and err ~= "" then
    detail = message.resolve_detail(err)
  end
  local KEYS = message.KEYS
  message.print_console(ok and KEYS.MSG_HTTP_REQUEST_OK or KEYS.MSG_HTTP_REQUEST_FAILED, {
    method = method or "?",
    target = target or "?",
    detail = detail or "",
  })
  if ok and upload then
    message.print(KEYS.MSG_DATA_SEND_OK)
  end
end

function M.emit_log_for_pending(pending, ok, err)
  if pending == nil then
    return
  end
  if pending.quiet then
    local detail = err
    if type(err) == "string" and err ~= "" then
      detail = message.resolve_detail(err)
    end
    local KEYS = message.KEYS
    message.print_console(ok and KEYS.MSG_HTTP_REQUEST_OK or KEYS.MSG_HTTP_REQUEST_FAILED, {
      method = pending.method or "?",
      target = pending.target or "?",
      detail = detail or "",
    })
    return
  end
  M.emit_log(pending.method, pending.target, ok, err)
end

return M
