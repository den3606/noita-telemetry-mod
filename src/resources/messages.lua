-- en / ja catalogue. Lookup only: formatting and output live in message.lua,
-- language detection in locale.lua.
--
-- Callers must use KEYS.* constants (not raw strings). Values are the key names
-- themselves; message bodies live in the private `messages` / `line_messages` tables.
-- GamePrint / console MSG_* texts are branded [ntel] in message.lua; settings UI uses SETTINGS_*.

local M = {}

local messages = {
  MSG_STATUS_ENABLED = { en = "Enabled", ja = "有効" },
  MSG_STATUS_TYPE_LOCAL = { en = "Type: Local", ja = "種別: ローカル" },
  MSG_STATUS_TYPE_REMOTE = { en = "Type: Remote", ja = "種別: リモート" },
  MSG_STATUS_CONNECTING = {
    en = "Connecting to server...",
    ja = "サーバーに接続中...",
  },
  MSG_STATUS_CONNECT_OK = {
    en = "Connected to server",
    ja = "サーバーに接続しました",
  },
  MSG_CONNECT_FAILED = {
    en = "Failed to connect to server",
    ja = "サーバーへの接続に失敗しました",
  },
  MSG_HTTP_REQUEST_OK = {
    en = "HTTP {method} {target} OK",
    ja = "HTTP {method} {target} 成功",
  },
  MSG_HTTP_REQUEST_FAILED = {
    en = "HTTP {method} {target} failed: {detail}",
    ja = "HTTP {method} {target} 失敗: {detail}",
  },
  MSG_DATA_SEND_OK = {
    en = "Data sent successfully",
    ja = "データ送信が成功しました",
  },
  MSG_DATA_SEND_FAILED = {
    en = "Data send failed",
    ja = "データ送信に失敗しました",
  },
  MSG_SYNC_UPLOADED = {
    en = "uploaded run",
    ja = "ランをアップロードしました",
  },
  MSG_RUN_SKIPPED_NG_PLUS = {
    en = "NG+ is out of scope — this run will not be recorded or uploaded",
    ja = "NG+ は対象外のため、このランは記録・アップロードしません",
  },
  MSG_RUN_SKIPPED_ENDING_COMPLETED = {
    en = "Ending already completed — post-clear play will not be recorded or uploaded",
    ja = "エンディング済みのため、クリア後のプレイは記録・アップロードしません",
  },
  MSG_ERROR_NATIVE_DLL_MISSING = {
    en = "Could not load telemetry_native.dll",
    ja = "telemetry_native.dll を読み込めませんでした",
  },
  MSG_ERROR_NATIVE_EXPORT_MISSING = {
    en = "Native features unavailable (rebuild telemetry_native.dll)",
    ja = "ネイティブ機能を利用できません（DLL を再ビルドしてください）",
  },
  MSG_ERROR_API_URL_MISSING = {
    en = "Could not read a built-in API URL",
    ja = "組み込み API URL を取得できませんでした",
  },
  MSG_ERROR_POLL_INTERVAL_INVALID = {
    en = "Invalid poll interval (frames) from native DLL",
    ja = "定期ログの取得間隔（フレーム）が不正です",
  },
  MSG_ERROR_TIMELINE_INTERVAL_INVALID = {
    en = "Invalid timeline interval (seconds) from native DLL",
    ja = "タイムライン記録間隔（秒）が不正です",
  },
  MSG_ERROR_UNKNOWN = {
    en = "Could not start NoitaTelemetry",
    ja = "NoitaTelemetry を開始できませんでした",
  },
  MSG_ERROR_LOGGER_RUN_OPEN_FAILED = {
    en = "Could not open run log file: {path} ({err})",
    ja = "ラン記録ファイルを開けませんでした: {path} ({err})",
  },
  MSG_ERROR_LOGGER_RUN_APPEND_FAILED = {
    en = "Could not append run event ({err})",
    ja = "ランイベントの追記に失敗しました ({err})",
  },
  MSG_ERROR_STREAK_PATCH_SKIPPED = {
    en = "Win streak patch was not applied ({err})",
    ja = "連勝パッチを適用できませんでした ({err})",
  },
  MSG_ERROR_ULID_NATIVE_FAILED = {
    en = "Native ULID generation failed ({err})",
    ja = "ネイティブの ULID 生成に失敗しました ({err})",
  },
  MSG_ERROR_LOGGER_RUN_CLOSE_FAILED = {
    en = "Could not finalize run log ({err})",
    ja = "ラン記録の終了処理に失敗しました ({err})",
  },
  MSG_ERROR_LOGGER_RUN_DELETE_FAILED = {
    en = "Uploaded run could not be deleted locally: {path} ({err})",
    ja = "アップロード済みの走行記録をローカルから削除できませんでした: {path} ({err})",
  },
  MSG_ERROR_EVENT_HANDLER_FAILED = {
    en = "Event handler failed ({err})",
    ja = "イベントハンドラでエラーが発生しました ({err})",
  },
  MSG_ERROR_TELEMETRY_NOT_READY = {
    en = "Telemetry is not ready; cloud features unavailable",
    ja = "テレメトリの準備ができていません。クラウド機能は利用できません",
  },
  MSG_ERROR_API_NOT_AUTHENTICATED = {
    en = "API token missing — configure the MOD token file",
    ja = "API トークン未設定 — MOD のトークンファイルを設定してください",
  },
  MSG_ERROR_API_UNAUTHORIZED = {
    en = "API token rejected — recreate in Dashboard Settings and update the token file",
    ja = "API トークンが拒否されました。ダッシュボードで再発行しトークンファイルを更新してください",
  },
  MSG_ERROR_API_HTTP_FAILED = {
    en = "Could not reach API{status_suffix}",
    ja = "API に接続できませんでした{status_suffix}",
  },
  MSG_ERROR_API_NO_INGEST_SESSION = {
    en = "Run session not open; cannot upload",
    ja = "ランセッションが開始されていません。アップロードできません",
  },
  MSG_ERROR_API_SESSION_EXPIRED = {
    en = "Session expired — too long since run start; cannot upload",
    ja = "期間を空けすぎたためセッションが切れており、提出できません",
  },
  MSG_ERROR_API_DISALLOWED_MODS = {
    en = "Cloud upload blocked — disallowed mod(s){mods_detail}",
    ja = "クラウド送信不可 — 許可されていない MOD{mods_detail}",
  },
  MSG_ERROR_API_CLIENT_VERSION_MISMATCH = {
    en = "Cloud upload blocked — MOD version outdated; update from Settings",
    ja = "クラウド送信不可 — MOD のバージョンが古いです。設定画面から更新してください",
  },
  MSG_ERROR_API_STARTED_AT_MISMATCH = {
    en = "Run start time mismatch; cannot upload",
    ja = "開始時刻が一致しません。提出できません",
  },
  MSG_ERROR_API_INVALID_STARTED_AT = {
    en = "Run start time is outside the allowed window",
    ja = "開始時刻が許可された範囲外です",
  },
  MSG_ERROR_API_INVALID_ENDED_AT = {
    en = "Run end time is outside the allowed window",
    ja = "終了時刻が許可された範囲外です",
  },
  MSG_ERROR_API_DAILY_INGEST_LIMIT = {
    en = "Daily upload limit reached",
    ja = "本日のアップロード上限に達しました",
  },
  MSG_ERROR_API_INVALID_RESPONSE = {
    en = "API returned an invalid run session response",
    ja = "ランセッション API の応答が不正です",
  },
  MSG_ERROR_API_OPEN_FAILED = {
    en = "Run session could not be opened ({api_message})",
    ja = "ランセッションを開始できませんでした ({api_message})",
  },
  MSG_ERROR_API_UNKNOWN = {
    en = "API request failed",
    ja = "API リクエストに失敗しました",
  },
  MSG_ERROR_API_GENERIC = {
    en = "API request failed ({detail})",
    ja = "API リクエストに失敗しました ({detail})",
  },
  MSG_STREAK_ALIGN_CORRECTED = {
    en = "Detected a streak mismatch and corrected the in-game value",
    ja = "ストリークのズレを検知したため、数値を修正しました",
  },
  SETTINGS_FORCE_WIN_STREAK = {
    en = "Force win streak with mods",
    ja = "MOD 有効時の連勝を有効化",
  },
  SETTINGS_FORCE_WIN_STREAK_DESC = {
    en = "Patch the game so win streaks count and display while mods are active. After each run open, aligns the in-game streak to the dashboard current streak when scopes match. Requires unsafe mods and may break on game updates.",
    ja = "MOD が有効でも連勝が加算・表示されるようゲームにパッチを当てます。ラン開始（open）成功後、ダッシュボードの current streak と一致する scope があればゲーム内の値を揃えます。Unsafe mods が必要で、ゲーム更新で動かなくなる場合があります。",
  },
  SETTINGS_CLOUD_UPLOAD = {
    en = "Cloud upload",
    ja = "クラウドアップロード",
  },
  SETTINGS_CLOUD_UPLOAD_DESC = {
    en = "Upload runs when they end. Without a token, runs are saved locally only.",
    ja = "ラン終了時にアップロードします。トークン未設定時はローカル保存のみです。",
  },
  SETTINGS_DELETE_RUN_AFTER_UPLOAD = {
    en = "Delete local run after upload",
    ja = "アップロード後にローカル記録を削除",
  },
  SETTINGS_DELETE_RUN_AFTER_UPLOAD_DESC = {
    en = "Remove the local .run file from mods/noita-telemetry/runs after a successful cloud upload. Uploaded runs on the dashboard are kept.",
    ja = "クラウドへのアップロード成功後、この PC 上の mods/noita-telemetry/runs の .run ファイルだけを削除します（ダッシュボードのデータは残ります）。",
  },
  SETTINGS_TOKEN_SETUP = {
    en = "API token setup",
    ja = "API トークン設定",
  },
  SETTINGS_TOKEN_SETUP_DESC = {
    en = "Required for cloud upload.",
    ja = "クラウドアップロードに必要です。",
  },
}

local line_messages = {
  SETTINGS_TOKEN_SETUP = {
    en = {
      "1. Dashboard Settings: create an API token.",
      "2. Paste only the API token (one line) into mods/noita-telemetry/noita-telemetry.token.",
      "3. Restart Noita or start a new run.",
      "4. After starting a run, check the bottom-left for a connection success message.",
    },
    ja = {
      "1. ダッシュボードの設定で API トークンを作成してください。",
      "2. API トークンだけを1行で貼り付け、",
      "   mods/noita-telemetry/noita-telemetry.token として保存してください。",
      "3. Noita を再起動するか、新しいランを開始してください。",
      "4. ラン開始後、左下に接続成功の通知が出ることを確認してください。",
    },
  },
}

--- Key constants for callers (`KEYS.MSG_STATUS_CONNECT_OK` == `"MSG_STATUS_CONNECT_OK"`).
local KEYS = {}
for name in pairs(messages) do
  KEYS[name] = name
end
M.KEYS = KEYS

--- Raw message for a key, falling back to en and then to the key itself.
function M.text(locale, key)
  local entry = messages[key]
  if entry == nil then
    return key
  end
  return entry[locale] or entry.en or key
end

--- Multi-line message (settings UI blocks), falling back to en.
function M.lines(locale, key)
  local entry = line_messages[key]
  if entry == nil then
    return {}
  end
  return entry[locale] or entry.en or {}
end

return M
