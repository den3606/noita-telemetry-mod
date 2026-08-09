-- Writes the .run file for one run: header, events, and footer, plus the
-- header patch applied on close. All file access goes through the native
-- writer  Ethe MOD refuses to record without the DLL, so there is no Lua io
-- fallback to keep in sync (and mixing the two reordered lines).

local client_version = dofile_once("mods/noita-telemetry/src/core/client_version.lua")
local message = dofile_once("mods/noita-telemetry/src/core/messaging.lua")

local json = dofile_once("mods/noita-telemetry/src/libs/json.lua")
local run_file = dofile_once("mods/noita-telemetry/src/adapters/native/run_file.lua")
local append_events = dofile_once("mods/noita-telemetry/src/adapters/native/append_events.lua")
local snapshot_encode = dofile_once("mods/noita-telemetry/src/core/snapshot_encode.lua")

local RUNS_DIR = "mods/noita-telemetry/runs"

local M = {}

local current_run = nil
local pending_upload_path = nil
local append_error_reported = false
local pending_header_patch = nil

local function reset_run_errors()
  append_error_reported = false
  pending_header_patch = nil
end

local function join_path(dir, name)
  return dir .. "/" .. name
end

function M.get_runs_dir()
  return RUNS_DIR
end

local function run_file_path(id)
  return join_path(M.get_runs_dir(), id .. ".run")
end

local function utc_timestamp()
  if os.date ~= nil then
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
  end
  return ""
end

local function write_header(meta)
  meta = meta or {}
  local payload = {
    event = "header",
    version = "2",
    at = meta.at,
    run_id = meta.run_id,
    client_version = meta.client_version or client_version.client_version,
    noita_version = meta.noita_version,
    seed = meta.seed,
    game_mode = meta.game_mode or "normal",
    mods_enabled = meta.mods_enabled or {},
  }
  if meta.is_win == true or meta.is_win == false then
    payload.is_win = meta.is_win
  end
  return json.encode(payload)
end

--- The header can only be rewritten once the writer released the file, so a
--- patch for the run in progress is held until end_run().
function M.patch_header(run_id, fields)
  if type(run_id) ~= "string" or run_id == "" or type(fields) ~= "table" then
    return false
  end
  if current_run ~= nil and current_run.ended ~= true and current_run.id == run_id then
    pending_header_patch = pending_header_patch or {}
    for key, value in pairs(fields) do
      pending_header_patch[key] = value
    end
    return true
  end

  local ok = run_file.run_patch_header(M.get_runs_dir(), run_id, json.encode(fields))
  return ok == true
end

local function finalize_header_for_upload(run_id, is_win)
  local fields = {}
  if pending_header_patch ~= nil then
    for key, value in pairs(pending_header_patch) do
      fields[key] = value
    end
    pending_header_patch = nil
  end
  if is_win == true or is_win == false then
    fields.is_win = is_win
  end
  if next(fields) == nil then
    return
  end
  run_file.run_patch_header(M.get_runs_dir(), run_id, json.encode(fields))
end

local function write_footer(is_win)
  local payload = {
    event = "footer",
    at = utc_timestamp(),
  }
  if is_win == true or is_win == false then
    payload.is_win = is_win
  end
  return json.encode(payload)
end

local function pos_xy(pos)
  pos = pos or {}
  return pos.x or 0, pos.y or 0
end

local function hp_values(hp)
  if type(hp) == "table" then
    return hp.current or 0, hp.max or 0
  end
  if type(hp) == "number" then
    return hp, hp
  end
  return 0, 0
end

function M.start_run(id, started_at, header_meta)
  reset_run_errors()

  current_run = {
    id = id,
    started_at = started_at,
    ended = false,
    is_win = nil,
  }

  header_meta = header_meta or {}
  local header_json = write_header({
    at = started_at,
    run_id = id,
    client_version = client_version.client_version,
    noita_version = header_meta.noita_version,
    seed = header_meta.seed,
    game_mode = header_meta.game_mode,
    mods_enabled = header_meta.mods_enabled,
  })

  local ok, err = run_file.run_open(M.get_runs_dir(), id, header_json)
  if not ok then
    message.error(message.KEYS.MSG_ERROR_LOGGER_RUN_OPEN_FAILED, { path = run_file_path(id), err = tostring(err or "") })
    current_run = nil
    return nil
  end

  return current_run
end

function M.resume_run(id, started_at)
  reset_run_errors()
  current_run = {
    id = id,
    started_at = started_at,
    ended = false,
    is_win = nil,
  }

  local ok, err = run_file.run_resume(M.get_runs_dir(), id)
  if not ok then
    message.error(message.KEYS.MSG_ERROR_LOGGER_RUN_OPEN_FAILED, { path = run_file_path(id), err = tostring(err or "") })
    current_run = nil
    return nil
  end

  return current_run
end

function M.is_active()
  return current_run ~= nil and current_run.ended ~= true
end

function M.append_typed(event_type, fields)
  if current_run == nil then
    return false
  end

  fields = fields or {}
  local t_ms = fields.t_ms or 0
  local playtime_sec = fields.playtime_sec or 0
  local x, y = pos_xy(fields.pos)
  local hp_current, hp_max = hp_values(fields.hp)

  local function dispatch(ok, err)
    if not ok and err ~= nil and not append_error_reported then
      append_error_reported = true
      message.error(message.KEYS.MSG_ERROR_LOGGER_RUN_APPEND_FAILED, { err = tostring(err) })
    end
    return ok == true
  end

  local function call_native(fn, ...)
    local ok, err = fn(...)
    return dispatch(ok, err)
  end

  if event_type == "timeline_tick" then
    return call_native(
      append_events.append_timeline_tick,
      t_ms,
      playtime_sec,
      fields.biome or "",
      x,
      y,
      hp_current,
      hp_max,
      fields.gold or 0
    )
  end

  if event_type == "biome_enter" then
    return call_native(append_events.append_biome_enter, t_ms, playtime_sec, fields.biome or "", fields.from_biome or "", x, y)
  end

  if event_type == "inventory_carry_start" then
    return call_native(
      append_events.append_inventory_carry_start,
      t_ms,
      playtime_sec,
      fields.biome or "",
      fields.entity_id or 0,
      fields.item_id or "",
      fields.item_type or "",
      fields.container or "",
      fields.wand_entity_id
    )
  end

  if event_type == "inventory_carry_end" then
    return call_native(
      append_events.append_inventory_carry_end,
      t_ms,
      playtime_sec,
      fields.biome or "",
      fields.entity_id or 0,
      fields.item_id or "",
      fields.item_type or "",
      fields.reason or ""
    )
  end

  if event_type == "shop_action" then
    return call_native(
      append_events.append_shop_action,
      t_ms,
      playtime_sec,
      fields.biome or "",
      x,
      y,
      fields.pos ~= nil,
      fields.action or "",
      fields.gold_before or 0,
      fields.gold_spent or 0,
      fields.gold_after or 0,
      fields.item_id or "",
      fields.item_type or "",
      fields.stole == true
    )
  end

  if event_type == "perk_pick" then
    return call_native(
      append_events.append_perk_pick,
      t_ms,
      playtime_sec,
      x,
      y,
      fields.perk_id or "",
      fields.perk_index or 0,
      fields.biome or ""
    )
  end

  if event_type == "god_event" then
    return call_native(
      append_events.append_god_event,
      t_ms,
      playtime_sec,
      x,
      y,
      fields.angered == true,
      fields.killed == true,
      fields.biome or ""
    )
  end

  if event_type == "death" then
    return call_native(
      append_events.append_death,
      t_ms,
      playtime_sec,
      fields.biome or "",
      x,
      y,
      fields.killed_by or "",
      fields.killed_with or "",
      hp_current,
      hp_max
    )
  end

  if event_type == "run_start" then
    return call_native(
      append_events.append_run_start,
      t_ms,
      playtime_sec,
      fields.seed or 0,
      fields.ng_plus or 0,
      fields.game_mode or "",
      fields.noita_version or "",
      snapshot_encode.encode_mods(fields.mods_enabled),
      x,
      y,
      hp_current,
      hp_max,
      snapshot_encode.encode_wands(fields.wands),
      snapshot_encode.encode_items(fields.items)
    )
  end

  if event_type == "run_end" then
    if fields.result == "win" then
      current_run.is_win = true
    elseif fields.result == "lose" then
      current_run.is_win = false
    end
    return call_native(
      append_events.append_run_end,
      t_ms,
      playtime_sec,
      fields.result or "",
      x,
      y,
      hp_current,
      hp_max,
      fields.gold or 0,
      fields.enemies_killed or 0,
      fields.places_visited or 0,
      fields.projectiles_shot or 0,
      snapshot_encode.encode_wands(fields.wands),
      snapshot_encode.encode_items(fields.items),
      snapshot_encode.encode_perks(fields.perks)
    )
  end

  if event_type == "holy_mountain_enter" then
    return call_native(
      append_events.append_holy_mountain_enter,
      t_ms,
      playtime_sec,
      fields.biome or "",
      x,
      y,
      fields.gold or 0,
      hp_current,
      hp_max,
      fields.wand_count or 0,
      fields.item_count or 0,
      snapshot_encode.encode_wands(fields.wands),
      snapshot_encode.encode_items(fields.items),
      snapshot_encode.encode_perks(fields.perks)
    )
  end

  if event_type == "holy_mountain_exit" then
    return call_native(
      append_events.append_holy_mountain_exit,
      t_ms,
      playtime_sec,
      fields.biome or "",
      x,
      y,
      fields.gold or 0,
      fields.gold_spent_total or 0,
      hp_current,
      hp_max,
      snapshot_encode.encode_wands(fields.wands),
      snapshot_encode.encode_items(fields.items),
      snapshot_encode.encode_perks(fields.perks)
    )
  end

  return false
end

function M.append_event(event)
  if current_run == nil then
    return false
  end

  if event.event == "run_end" then
    if event.result == "win" then
      current_run.is_win = true
    elseif event.result == "lose" then
      current_run.is_win = false
    end
  end

  if M.append_typed(event.event, event) then
    return true
  end

  local ok, err = run_file.run_append(json.encode(event))
  if not ok then
    message.error(message.KEYS.MSG_ERROR_LOGGER_RUN_APPEND_FAILED, { err = tostring(err) })
    return false
  end
  return true
end

function M.end_run()
  if current_run == nil then
    return
  end

  current_run.ended = true
  local footer_json = write_footer(current_run.is_win)
  local path = run_file_path(current_run.id)

  local ok, err = run_file.run_close(M.get_runs_dir(), current_run.id, footer_json)
  if not ok then
    message.error(message.KEYS.MSG_ERROR_LOGGER_RUN_CLOSE_FAILED, { err = tostring(err or "") })
  end

  finalize_header_for_upload(current_run.id, current_run.is_win)
  -- Queue at most one upload per finished run.
  pending_upload_path = path
  current_run = nil
end

function M.discard_pending_upload()
  pending_upload_path = nil
end

function M.process_pending_upload()
  local path = pending_upload_path
  if path == nil then
    return
  end

  pending_upload_path = nil
  -- Lazy: sync ↁEsession ↁElogger would cycle if sync were required at load.
  local sync = dofile_once("mods/noita-telemetry/src/core/run/sync.lua")
  pcall(sync.start_upload_run, path)
end

function M.poll_upload()
  local sync = dofile_once("mods/noita-telemetry/src/core/run/sync.lua")
  pcall(sync.poll_upload)
end

return M
