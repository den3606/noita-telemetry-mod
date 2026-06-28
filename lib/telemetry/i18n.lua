local M = {}

local TEXT = {
  en = {
    type_local = "Local",
    type_remote = "Remote",
    status_enabled = "[NoitaTelemetry] Enabled",
    status_type = "[NoitaTelemetry] Type: {type}",
    status_connecting = "[NoitaTelemetry] Connecting to API...",
    status_connect_retry = "[NoitaTelemetry] API unreachable — retrying ({attempt}/{max})",
    status_connect_ok = "[NoitaTelemetry] API connected",
    connect_ok = "[NoitaTelemetry] Connected successfully",
    connect_failed = "[NoitaTelemetry] Connection failed",
    http_request_ok = "[NoitaTelemetry] HTTP {method} {target} OK",
    http_request_failed = "[NoitaTelemetry] HTTP {method} {target} failed: {detail}",
    data_send_ok = "[NoitaTelemetry] Data sent successfully",
    data_send_failed = "[NoitaTelemetry] Data send failed",
    sync_uploaded = "noita-telemetry: uploaded run",
    error_prefix = "[NoitaTelemetry] NTel_ERR_{code}",
    error_native_dll_missing = "Could not load telemetry_native.dll",
    error_native_export_missing = "Native features unavailable (rebuild telemetry_native.dll)",
    error_api_url_missing = "Could not read the built-in API URL",
    error_poll_interval_invalid = "Invalid poll interval (frames) from native DLL",
    error_timeline_interval_invalid = "Invalid timeline interval (seconds) from native DLL",
    error_unknown = "Could not start NoitaTelemetry",
    error_logger_run_open_failed = "Could not open run log file: {path} ({err})",
    error_logger_run_append_failed = "Could not append run event ({err})",
    error_streak_patch_skipped = "Win streak patch was not applied ({err})",
    error_ulid_native_failed = "Native run ID generation failed; using fallback ({err})",
    error_logger_run_close_failed = "Could not finalize run log ({err})",
    error_logger_run_native_open_failed = "Native run log open failed; using file fallback ({err})",
    error_logger_run_native_resume_failed = "Native run log resume failed; using file fallback ({err})",
    error_logger_run_delete_failed = "Uploaded run could not be deleted locally: {path} ({err})",
    error_telemetry_not_ready = "Telemetry is not ready; cloud features unavailable",
    error_api_not_authenticated =
      "API token missing — save one line to {path}",
    error_api_unauthorized =
      "API token rejected — recreate in Dashboard Settings and update {path}",
    error_api_http_failed = "Could not reach API",
    error_api_no_ingest_session = "Run session not open; cannot upload",
    error_api_session_expired = "Session expired — too long since run start; cannot upload",
    error_api_disallowed_mods = "Disallowed mod(s) active; cannot upload",
    error_api_started_at_mismatch = "Run start time mismatch; cannot upload",
    error_api_invalid_started_at = "Run start time is outside the allowed window",
    error_api_invalid_ended_at = "Run end time is outside the allowed window",
    error_api_ingest_cooldown = "Wait before uploading the next run",
    error_api_daily_ingest_limit = "Daily upload limit reached",
    error_api_invalid_response = "API returned an invalid run session response",
    error_api_open_failed = "Run session could not be opened",
    error_api_unknown = "API request failed",
    error_api_generic = "API request failed ({detail})",
    settings_force_win_streak = "Force win streak with mods",
    settings_force_win_streak_desc =
      "Patch the game so win streaks count and display while mods are active. Requires unsafe mods and may break on game updates.",
    settings_cloud_upload = "Cloud upload",
    settings_cloud_upload_desc =
      "Upload runs when they end. Without a token, runs are saved locally only.",
    settings_delete_run_after_upload = "Delete local run after upload",
    settings_delete_run_after_upload_desc =
      "Remove the local .run file from mods/noita-telemetry/runs after a successful cloud upload. Uploaded runs on the dashboard are kept.",
    settings_token_setup = "API token setup",
    settings_token_setup_desc = "Required for cloud upload.",
  },
  ja = {
    type_local = "ローカル",
    type_remote = "リモート",
    status_enabled = "[NoitaTelemetry] 有効",
    status_type = "[NoitaTelemetry] 種別: {type}",
    status_connecting = "[NoitaTelemetry] API に接続中...",
    status_connect_retry = "[NoitaTelemetry] API に接続できません。再試行中 ({attempt}/{max})",
    status_connect_ok = "[NoitaTelemetry] API に接続しました",
    connect_ok = "[NoitaTelemetry] 接続に成功しました",
    connect_failed = "[NoitaTelemetry] 接続に失敗しました",
    http_request_ok = "[NoitaTelemetry] HTTP {method} {target} 成功",
    http_request_failed = "[NoitaTelemetry] HTTP {method} {target} 失敗: {detail}",
    data_send_ok = "[NoitaTelemetry] データ送信が成功しました",
    data_send_failed = "[NoitaTelemetry] データ送信に失敗しました",
    sync_uploaded = "noita-telemetry: ランをアップロードしました",
    error_prefix = "[NoitaTelemetry] NTel_ERR_{code}",
    error_native_dll_missing = "telemetry_native.dll を読み込めませんでした",
    error_native_export_missing = "ネイティブ機能を利用できません（DLL を再ビルドしてください）",
    error_api_url_missing = "組み込み API URL を取得できませんでした",
    error_poll_interval_invalid = "定期ログの取得間隔（フレーム）が不正です",
    error_timeline_interval_invalid = "タイムライン記録間隔（秒）が不正です",
    error_unknown = "NoitaTelemetry を開始できませんでした",
    error_logger_run_open_failed = "ラン記録ファイルを開けませんでした: {path} ({err})",
    error_logger_run_append_failed = "ランイベントの追記に失敗しました ({err})",
    error_streak_patch_skipped = "連勝パッチを適用できませんでした ({err})",
    error_ulid_native_failed = "ネイティブの run ID 生成に失敗しました。代替 ID を使用します ({err})",
    error_logger_run_close_failed = "ラン記録の終了処理に失敗しました ({err})",
    error_logger_run_native_open_failed = "ネイティブのラン記録開始に失敗しました。ファイルにフォールバックします ({err})",
    error_logger_run_native_resume_failed = "ネイティブのラン記録再開に失敗しました。ファイルにフォールバックします ({err})",
    error_logger_run_delete_failed = "アップロード済みの走行記録をローカルから削除できませんでした: {path} ({err})",
    error_telemetry_not_ready = "テレメトリの準備ができていません。クラウド機能は利用できません",
    error_api_not_authenticated =
      "API トークン未設定 — {path} に 1 行で保存してください",
    error_api_unauthorized =
      "API トークンが拒否されました。ダッシュボードで再発行し {path} を更新してください",
    error_api_http_failed = "API に接続できませんでした",
    error_api_no_ingest_session = "ランセッションが開始されていません。アップロードできません",
    error_api_session_expired = "期間を空けすぎたためセッションが切れており、提出できません",
    error_api_disallowed_mods = "許可されていない MOD が有効です。提出できません",
    error_api_started_at_mismatch = "開始時刻が一致しません。提出できません",
    error_api_invalid_started_at = "開始時刻が許可された範囲外です",
    error_api_invalid_ended_at = "終了時刻が許可された範囲外です",
    error_api_ingest_cooldown = "次のランを提出するまでお待ちください",
    error_api_daily_ingest_limit = "本日のアップロード上限に達しました",
    error_api_invalid_response = "ランセッション API の応答が不正です",
    error_api_open_failed = "ランセッションを開始できませんでした",
    error_api_unknown = "API リクエストに失敗しました",
    error_api_generic = "API リクエストに失敗しました ({detail})",
    settings_force_win_streak = "MOD 有効時の連勝を有効化",
    settings_force_win_streak_desc =
      "MOD が有効でも連勝が加算・表示されるようゲームにパッチを当てます。Unsafe mods が必要で、ゲーム更新で動かなくなる場合があります。",
    settings_cloud_upload = "クラウドアップロード",
    settings_cloud_upload_desc =
      "ラン終了時にアップロードします。トークン未設定時はローカル保存のみです。",
    settings_delete_run_after_upload = "アップロード後にローカル記録を削除",
    settings_delete_run_after_upload_desc =
      "クラウドへのアップロード成功後、この PC 上の mods/noita-telemetry/runs の .run ファイルだけを削除します（ダッシュボードのデータは残ります）。",
    settings_token_setup = "API トークン設定",
    settings_token_setup_desc = "クラウドアップロードに必要です。",
  },
}

local LINES = {
  en = {
    settings_token_setup = {
      "1. Dashboard Settings: create an API token.",
      "2. Local: save to mods/noita-telemetry/noita-telemetry.token.local",
      "   Production: save to mods/noita-telemetry/noita-telemetry.token",
      "3. Restart Noita or start a new run.",
    },
  },
  ja = {
    settings_token_setup = {
      "1. ダッシュボードの設定で API トークンを作成します。",
      "2. ローカル: mods/noita-telemetry/noita-telemetry.token.local に 1 行で保存",
      "   本番: mods/noita-telemetry/noita-telemetry.token に 1 行で保存",
      "3. Noita を再起動するか、新しいランを開始します。",
    },
  },
}

local cached_locale = nil

local function detect_locale()
  if GameTextGet == nil then
    return "en"
  end

  -- Keys must start with "$". Compare a vanilla UI label (en: "ON", ja: "オン").
  local on_label = GameTextGet("$option_on")
  if type(on_label) == "string" and on_label == "オン" then
    return "ja"
  end

  return "en"
end

function M.locale()
  if cached_locale == nil then
    cached_locale = detect_locale()
  end
  return cached_locale
end

function M.is_japanese()
  return M.locale() == "ja"
end

function M.t(key, vars, locale)
  local bucket = TEXT[locale or M.locale()] or TEXT.en
  local text = bucket[key] or TEXT.en[key] or key

  if vars ~= nil then
    for name, value in pairs(vars) do
      text = text:gsub("{" .. name .. "}", tostring(value))
    end
  end

  return text
end

function M.t_en(key, vars)
  return M.t(key, vars, "en")
end

--- Write English to log.txt (`print`) only.
function M.emit_console(key, vars)
  print(M.t_en(key, vars))
end

--- Write English to log.txt (`print`) and localized text in-game (`GamePrint`).
function M.emit(key, vars, console_vars)
  print(M.t_en(key, console_vars or vars))
  GamePrint(M.t(key, vars))
end

function M.lines(key)
  local locale = M.locale()
  local bucket = LINES[locale] or LINES.en
  return bucket[key] or LINES.en[key] or {}
end

return M
