--- Run diagnostic `record: "error"` phase identifiers.
--- Each value is written to the `phase` field in JSONL error records.
local M = {}

-- MOD boot (config.lua / native DLL validation).
M.boot = "boot"

-- Cloud sync: POST /mod/runs/open (ingest session).
M.sync = {
  open = {
    --- Before HTTP: token missing, sync disabled, etc. (session.queue_open_run)
    queue = "sync.open.queue",
    --- Immediate failure queueing async open. (native.http_request_async)
    http_start = "sync.open.http_start",
    --- Open HTTP finished with error. (session.poll_open, status failed)
    http_poll = "sync.open.http_poll",
  },
  upload = {
    --- Before HTTP: no ingest token, sync disabled, etc. (sync.start_upload_run)
    queue = "sync.upload.queue",
    --- Immediate failure queueing async upload. (native.upload_file_async)
    http_start = "sync.upload.http_start",
    --- Upload HTTP finished with error. (sync.poll_upload, status failed)
    http_poll = "sync.upload.http_poll",
  },
}

-- Local .run file I/O (logger.lua). Not cloud API.
M.logger = {
  open = "logger.open",
  append = "logger.append",
  close = "logger.close",
}

--- @type table<string, {summary_en: string, summary_ja: string, when_en: string, when_ja: string}>
local REGISTRY = {
  [M.boot] = {
    summary_en = "Telemetry boot validation failed",
    summary_ja = "テレメトリの起動チェックに失敗",
    when_en = "MOD load; before any run (DLL, API URL, poll interval)",
    when_ja = "MOD 読み込み時。ラン開始前（DLL・API URL・ポール間隔）",
  },
  [M.sync.open.queue] = {
    summary_en = "Run session open blocked before HTTP",
    summary_ja = "ランセッション開始の HTTP 前チェックで失敗",
    when_en = "Right after begin_run; session.queue_open_run",
    when_ja = "begin_run 直後。session.queue_open_run",
  },
  [M.sync.open.http_start] = {
    summary_en = "Failed to start async POST /mod/runs/open",
    summary_ja = "非同期 POST /mod/runs/open の開始に失敗",
    when_en = "begin_run; native.http_request_async returns immediately",
    when_ja = "begin_run 時。http_request_async が即失敗",
  },
  [M.sync.open.http_poll] = {
    summary_en = "POST /mod/runs/open failed or bad response",
    summary_ja = "POST /mod/runs/open の応答が失敗または不正",
    when_en = "During play; session.poll_open on each world tick",
    when_ja = "プレイ中。毎フレーム session.poll_open",
  },
  [M.sync.upload.queue] = {
    summary_en = "Run upload blocked before HTTP",
    summary_ja = "ランアップロードの HTTP 前チェックで失敗",
    when_en = "After run_end footer; sync.start_upload_run",
    when_ja = "footer 書き込み後。sync.start_upload_run",
  },
  [M.sync.upload.http_start] = {
    summary_en = "Failed to start async POST /mod/ingest",
    summary_ja = "非同期 POST /mod/ingest の開始に失敗",
    when_en = "After finalize_run; native.upload_file_async returns immediately",
    when_ja = "finalize_run 後。upload_file_async が即失敗",
  },
  [M.sync.upload.http_poll] = {
    summary_en = "POST /mod/ingest failed",
    summary_ja = "POST /mod/ingest の応答が失敗",
    when_en = "After run end; sync.poll_upload on each world tick",
    when_ja = "ラン終了後。毎フレーム sync.poll_upload",
  },
  [M.logger.open] = {
    summary_en = "Failed to open local .run file",
    summary_ja = "ローカル .run ファイルを開けない",
    when_en = "begin_run; logger.start_run",
    when_ja = "begin_run。logger.start_run",
  },
  [M.logger.append] = {
    summary_en = "Failed to append event to .run",
    summary_ja = ".run へのイベント追記に失敗",
    when_en = "During play; logger.append_event",
    when_ja = "プレイ中。logger.append_event",
  },
  [M.logger.close] = {
    summary_en = "Failed to write footer / close .run",
    summary_ja = ".run の footer 書き込み・終了に失敗",
    when_en = "Run end; logger.end_run",
    when_ja = "ラン終了。logger.end_run",
  },
}

local KNOWN = {}
for phase in pairs(REGISTRY) do
  KNOWN[phase] = true
end

function M.is_known(phase)
  return type(phase) == "string" and KNOWN[phase] == true
end

--- Log a warning to log.txt when `phase` is not registered in this module.
function M.warn_if_unknown(phase)
  if M.is_known(phase) then
    return false
  end
  local label = type(phase) == "string" and phase or tostring(phase)
  print("[NoitaTelemetry] WARN unknown diagnostic phase: " .. label)
  return true
end

function M.describe(phase, locale)
  local info = REGISTRY[phase]
  if info == nil then
    return nil
  end
  if locale == "ja" then
    return info.summary_ja, info.when_ja
  end
  return info.summary_en, info.when_en
end

function M.all()
  local phases = {}
  for phase in pairs(REGISTRY) do
    phases[#phases + 1] = phase
  end
  table.sort(phases)
  return phases
end

return M
