-- Per-run-event append_* calls (timeline tick, biome/inventory/shop/perk/god
-- events, death, run start/end, holy mountain enter/exit). All funnel through
-- call_append, which packs the trailing (error_buf, error_buf_len) pair that
-- every telemetry_append_* export expects.

local ffi = require("ffi")
local loader = dofile_once("mods/noita-telemetry/src/adapters/native/loader.lua")
local ffi_call = dofile_once("mods/noita-telemetry/src/adapters/native/ffi_call.lua")

local lib = loader.lib

local M = {}

local function bool_flag(value)
  return value and 1 or 0
end

local function as_i32(value)
  return math.floor(tonumber(value) or 0)
end

local function as_u32(value)
  local number = tonumber(value) or 0
  if number < 0 then
    number = number + 4294967296
  end
  return number
end

local function call_append(fn, ...)
  if lib == nil then
    return false, "telemetry_native.dll not found (run npm run build:native)"
  end
  if fn == nil then
    return false, "native export missing (run npm run build:native)"
  end

  local error_buf = ffi.new("char[?]", 256)
  local argc = select("#", ...)
  local args = { ... }
  args[argc + 1] = error_buf
  args[argc + 2] = 256

  local ok, result = pcall(function()
    return fn(unpack(args, 1, argc + 2))
  end)
  if not ok then
    return false, result
  end
  if result == 0 then
    return true
  end

  return false, ffi_call.read_error(error_buf)
end

function M.append_timeline_tick(t_ms, playtime_sec, biome, x, y, hp_current, hp_max, gold)
  return call_append(
    lib.telemetry_append_timeline_tick,
    as_i32(t_ms),
    as_i32(playtime_sec),
    biome,
    x,
    y,
    hp_current,
    hp_max,
    as_i32(gold)
  )
end

function M.append_biome_enter(t_ms, playtime_sec, biome, from_biome, x, y)
  return call_append(
    lib.telemetry_append_biome_enter,
    as_i32(t_ms),
    as_i32(playtime_sec),
    biome,
    from_biome,
    x,
    y
  )
end

function M.append_inventory_carry_start(
  t_ms,
  playtime_sec,
  biome,
  entity_id,
  item_id,
  item_type,
  container,
  wand_entity_id
)
  return call_append(
    lib.telemetry_append_inventory_carry_start,
    as_i32(t_ms),
    as_i32(playtime_sec),
    biome,
    as_u32(entity_id),
    item_id,
    item_type,
    container,
    as_i32(wand_entity_id == nil and -1 or wand_entity_id)
  )
end

function M.append_inventory_carry_end(t_ms, playtime_sec, biome, entity_id, item_id, item_type, reason)
  return call_append(
    lib.telemetry_append_inventory_carry_end,
    as_i32(t_ms),
    as_i32(playtime_sec),
    biome,
    as_u32(entity_id),
    item_id,
    item_type,
    reason
  )
end

function M.append_shop_action(
  t_ms,
  playtime_sec,
  biome,
  x,
  y,
  has_position,
  action,
  gold_before,
  gold_spent,
  gold_after,
  item_id,
  item_type,
  stole
)
  return call_append(
    lib.telemetry_append_shop_action,
    as_i32(t_ms),
    as_i32(playtime_sec),
    biome,
    x,
    y,
    as_i32(bool_flag(has_position)),
    action,
    as_i32(gold_before),
    as_i32(gold_spent),
    as_i32(gold_after),
    item_id,
    item_type,
    as_i32(bool_flag(stole))
  )
end

function M.append_perk_pick(t_ms, playtime_sec, x, y, perk_id, perk_index, biome)
  return call_append(
    lib.telemetry_append_perk_pick,
    as_i32(t_ms),
    as_i32(playtime_sec),
    x,
    y,
    perk_id,
    as_i32(perk_index),
    biome
  )
end

function M.append_god_event(t_ms, playtime_sec, x, y, angered, killed, biome)
  return call_append(
    lib.telemetry_append_god_event,
    as_i32(t_ms),
    as_i32(playtime_sec),
    x,
    y,
    as_i32(bool_flag(angered)),
    as_i32(bool_flag(killed)),
    biome
  )
end

function M.append_death(t_ms, playtime_sec, biome, x, y, killed_by, killed_with, hp_current, hp_max)
  return call_append(
    lib.telemetry_append_death,
    as_i32(t_ms),
    as_i32(playtime_sec),
    biome,
    x,
    y,
    killed_by,
    killed_with,
    hp_current,
    hp_max
  )
end

function M.append_run_start(
  t_ms,
  playtime_sec,
  seed,
  ng_plus,
  game_mode,
  noita_version,
  mods_json,
  x,
  y,
  hp_current,
  hp_max,
  wands_json,
  items_json
)
  return call_append(
    lib.telemetry_append_run_start,
    as_i32(t_ms),
    as_i32(playtime_sec),
    as_i32(seed),
    as_i32(ng_plus),
    game_mode,
    noita_version,
    mods_json,
    x,
    y,
    hp_current,
    hp_max,
    wands_json,
    items_json
  )
end

function M.append_run_end(
  t_ms,
  playtime_sec,
  result,
  x,
  y,
  hp_current,
  hp_max,
  gold,
  enemies_killed,
  places_visited,
  projectiles_shot,
  wands_json,
  items_json,
  perks_json
)
  return call_append(
    lib.telemetry_append_run_end,
    as_i32(t_ms),
    as_i32(playtime_sec),
    result,
    x,
    y,
    hp_current,
    hp_max,
    as_i32(gold),
    as_i32(enemies_killed),
    as_i32(places_visited),
    as_i32(projectiles_shot),
    wands_json,
    items_json,
    perks_json
  )
end

function M.append_holy_mountain_enter(
  t_ms,
  playtime_sec,
  biome,
  x,
  y,
  gold,
  hp_current,
  hp_max,
  wand_count,
  item_count,
  wands_json,
  items_json,
  perks_json
)
  return call_append(
    lib.telemetry_append_holy_mountain_enter,
    as_i32(t_ms),
    as_i32(playtime_sec),
    biome,
    x,
    y,
    as_i32(gold),
    hp_current,
    hp_max,
    as_i32(wand_count),
    as_i32(item_count),
    wands_json,
    items_json,
    perks_json
  )
end

function M.append_holy_mountain_exit(
  t_ms,
  playtime_sec,
  biome,
  x,
  y,
  gold,
  gold_spent_total,
  hp_current,
  hp_max,
  wands_json,
  items_json,
  perks_json
)
  return call_append(
    lib.telemetry_append_holy_mountain_exit,
    as_i32(t_ms),
    as_i32(playtime_sec),
    biome,
    x,
    y,
    as_i32(gold),
    as_i32(gold_spent_total),
    hp_current,
    hp_max,
    wands_json,
    items_json,
    perks_json
  )
end

return M
