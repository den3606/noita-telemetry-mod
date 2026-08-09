--- Phase identifiers for error context (open/upload/writer/events).
--- Values are opaque strings used as `phase` on diagnostic payloads.

local M = {}

-- MOD boot (native DLL validation).
M.boot = "boot"

-- Cloud sync: POST /mod/runs/open (ingest session).
M.sync = {
  open = {
    --- Before HTTP: token missing, sync disabled, etc. (session.queue_open_run)
    queue = "sync.open.queue",
    --- Immediate failure queueing async open. (adapters/native/http.http_request_async)
    http_start = "sync.open.http_start",
    --- Open HTTP finished with error. (session.poll_open, status failed)
    http_poll = "sync.open.http_poll",
  },
  upload = {
    --- Before HTTP: no ingest token, sync disabled, etc. (sync.start_upload_run)
    queue = "sync.upload.queue",
    --- Immediate failure queueing async upload. (adapters/native/upload.upload_file_async)
    http_start = "sync.upload.http_start",
    --- Upload HTTP finished with error. (sync.poll_upload, status failed)
    http_poll = "sync.upload.http_poll",
  },
}

-- Local .run file I/O (writer.lua). Not cloud API.
M.writer = {
  open = "writer.open",
  append = "writer.append",
  close = "writer.close",
}

-- init.lua dispatch to core/events.lua (safe_call.guard).
M.events = "events.dispatch"

return M
