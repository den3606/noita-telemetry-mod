local config = dofile_once("mods/noita-telemetry/lib/telemetry/config.lua")
local errors = dofile_once("mods/noita-telemetry/lib/telemetry/errors.lua")

local json = dofile_once("mods/noita-telemetry/lib/telemetry/json.lua")
local sync = dofile_once("mods/noita-telemetry/lib/telemetry/sync.lua")
local native = dofile_once("mods/noita-telemetry/lib/telemetry/native.lua")
local snapshot_encode = dofile_once("mods/noita-telemetry/lib/telemetry/snapshot_encode.lua")
local version = dofile_once("mods/noita-telemetry/lib/telemetry/version.lua")

local M = {}

local current_run = nil
local pending_upload_path = nil
local append_error_reported = false

local function reset_run_errors()
  append_error_reported = false
end

local function join_path(dir, name)
  return dir .. "/" .. name
end

function M.get_runs_dir()
  return config.runs_dir
end

function M.get_diagnostic_run_path()
  if current_run ~= nil and current_run.id ~= nil then
    return run_file_path(current_run.id)
  end
  if pending_upload_path ~= nil then
    return pending_upload_path
  end
  return nil
end

local function run_file_path(id)
  return join_path(M.get_runs_dir(), id .. ".run")
end

local function append_jsonl_line(file, line)
  file:write(line)
  file:write("\n")
  file:flush()
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
    client_version = meta.client_version or config.client_version,
    noita_version = meta.noita_version or version.get(),
    seed = meta.seed,
    game_mode = meta.game_mode or "normal",
    mods_enabled = meta.mods_enabled or {},
  }
  if meta.is_win == true or meta.is_win == false then
    payload.is_win = meta.is_win
  end
  return json.encode(payload)
end

local function patch_header_line(path, fields)
  if type(path) ~= "string" or path == "" or type(fields) ~= "table" then
    return false
  end

  local lines = {}
  local file = io.open(path, "r")
  if file == nil then
    return false
  end
  for line in file:lines() do
    lines[#lines + 1] = line
  end
  file:close()

  if #lines == 0 then
    return false
  end

  local header = json.decode(lines[1])
  if type(header) ~= "table" or header.event ~= "header" then
    return false
  end

  for key, value in pairs(fields) do
    header[key] = value
  end
  lines[1] = json.encode(header)

  file = io.open(path, "w")
  if file == nil then
    return false
  end
  for index, line in ipairs(lines) do
    file:write(line)
    if index < #lines then
      file:write("\n")
    end
  end
  file:close()
  return true
end

local function finalize_header_for_upload(path, is_win)
  if is_win ~= true and is_win ~= false then
    return
  end
  patch_header_line(path, { is_win = is_win })
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
    use_native = false,
    file = nil,
    is_win = nil,
  }

  header_meta = header_meta or {}
  local header_json = write_header({
    at = started_at,
    run_id = id,
    client_version = config.client_version,
    noita_version = header_meta.noita_version,
    seed = header_meta.seed,
    game_mode = header_meta.game_mode,
    mods_enabled = header_meta.mods_enabled,
  })

  if native.available() then
    local ok, err = native.run_open(M.get_runs_dir(), id, header_json)
    if ok then
      current_run.use_native = true
      return current_run
    end
    errors.print(errors.logger_run_native_open_failed, { err = tostring(err or "") })
  end

  local path = run_file_path(id)
  local file, err = io.open(path, "w")
  if file == nil then
    errors.print(errors.logger_run_open_failed, { path = tostring(path), err = tostring(err) })
    current_run = nil
    return nil
  end

  append_jsonl_line(file, header_json)
  current_run.file = file
  return current_run
end

function M.resume_run(id, started_at)
  reset_run_errors()
  current_run = {
    id = id,
    started_at = started_at,
    ended = false,
    use_native = false,
    file = nil,
    is_win = nil,
  }

  if native.available() then
    local ok, err = native.run_resume(M.get_runs_dir(), id)
    if ok then
      current_run.use_native = true
      return current_run
    end
    errors.print(errors.logger_run_native_resume_failed, { err = tostring(err or "") })
  end

  local path = run_file_path(id)
  local file, err = io.open(path, "a")
  if file == nil then
    errors.print(errors.logger_run_open_failed, { path = tostring(path), err = tostring(err) })
    current_run = nil
    return nil
  end

  current_run.file = file
  return current_run
end

function M.get_run()
  return current_run
end

function M.is_active()
  return current_run ~= nil and current_run.ended ~= true
end

function M.append_diagnostic_line(line)
  if type(line) ~= "string" or line == "" then
    return false
  end
  if current_run == nil or current_run.ended == true then
    return false
  end

  if current_run.use_native then
    local ok = native.run_append_diagnostic(M.get_runs_dir(), current_run.id, line)
    return ok == true
  end

  if current_run.file ~= nil then
    append_jsonl_line(current_run.file, line)
    return true
  end

  return false
end

function M.append_typed(event_type, fields)
  if current_run == nil or not current_run.use_native then
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
      errors.print(errors.logger_run_append_failed, { err = tostring(err) })
    end
    return ok == true
  end

  local function call_native(fn, ...)
    local ok, err = fn(...)
    return dispatch(ok, err)
  end

  if event_type == "timeline_tick" then
    return call_native(
      native.append_timeline_tick,
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
    return call_native(
      native.append_biome_enter,
      t_ms,
      playtime_sec,
      fields.biome or "",
      fields.from_biome or "",
      x,
      y
    )
  end

  if event_type == "inventory_carry_start" then
    return call_native(
      native.append_inventory_carry_start,
      t_ms,
      playtime_sec,
      fields.entity_id or 0,
      fields.item_id or "",
      fields.item_type or "",
      fields.container or "",
      fields.wand_entity_id
    )
  end

  if event_type == "inventory_carry_end" then
    return call_native(
      native.append_inventory_carry_end,
      t_ms,
      playtime_sec,
      fields.entity_id or 0,
      fields.item_id or "",
      fields.item_type or "",
      fields.reason or ""
    )
  end

  if event_type == "shop_action" then
    return call_native(
      native.append_shop_action,
      t_ms,
      playtime_sec,
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
      native.append_perk_pick,
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
      native.append_god_event,
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
      native.append_death,
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
      native.append_run_start,
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
      native.append_run_end,
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
      native.append_holy_mountain_enter,
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
      native.append_holy_mountain_exit,
      t_ms,
      playtime_sec,
      x,
      y,
      fields.gold or 0,
      fields.gold_spent_total or 0,
      hp_current,
      hp_max,
      fields.stole_any == true,
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

  local event_json = json.encode(event)

  if current_run.use_native then
    local ok, err = native.run_append(event_json)
    if not ok then
      errors.print(errors.logger_run_append_failed, { err = tostring(err) })
      return false
    end
    return true
  end

  if current_run.file == nil then
    return false
  end

  append_jsonl_line(current_run.file, event_json)
  return true
end

function M.end_run()
  if current_run == nil then
    return
  end

  current_run.ended = true
  local footer_json = write_footer(current_run.is_win)
  local path = run_file_path(current_run.id)

  if current_run.use_native then
    local ok, err = native.run_close(M.get_runs_dir(), current_run.id, footer_json)
    if not ok then
      errors.print(errors.logger_run_close_failed, { err = tostring(err or "") })
    end
  elseif current_run.file ~= nil then
    append_jsonl_line(current_run.file, footer_json)
    current_run.file:close()
    current_run.file = nil
  end

  finalize_header_for_upload(path, current_run.is_win)
  pending_upload_path = path
  current_run = nil
end

function M.process_pending_upload()
  local path = pending_upload_path
  if path == nil then
    return
  end

  pending_upload_path = nil
  pcall(sync.start_upload_run, path)
end

function M.poll_upload()
  pcall(sync.poll_upload)
end

return M
