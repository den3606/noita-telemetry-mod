-- Shared "did this network call succeed" lines for log.txt, and the player notice after an
-- upload. Which message to show is an application choice, not transport.

local message = dofile_once("mods/noita-telemetry/src/application/messaging.lua")

local M = {}

--- The URL without its query string, for log lines.
function M.target_label(url)
  if type(url) ~= "string" or url == "" then
    return "?"
  end
  return (url:gsub("%?.*", ""))
end

local function log_line(method, target, ok, err)
  local detail = err
  if err ~= nil and err ~= "" then
    detail = message.resolve_detail(err)
  end
  local KEYS = message.KEYS
  message.print_console(ok and KEYS.MSG_HTTP_REQUEST_OK or KEYS.MSG_HTTP_REQUEST_FAILED, {
    method = method or "?",
    target = target,
    detail = detail or "",
  })
end

--- A request made through adapters/native/http.lua: log.txt only.
function M.request(method, url, ok, err)
  log_line(method, M.target_label(url), ok, err)
end

--- A run file upload through adapters/native/upload.lua; a success also tells the player.
function M.upload(url, ok, err)
  log_line("POST", M.target_label(url) .. " (upload)", ok, err)
  if ok then
    message.print(message.KEYS.MSG_DATA_SEND_OK)
  end
end

return M
