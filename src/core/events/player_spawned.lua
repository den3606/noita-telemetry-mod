-- player_spawned: begin or resume a run (emits run_start on new runs).

local run_state = dofile_once("mods/noita-telemetry/src/core/run/run_state.lua")
local emit = dofile_once("mods/noita-telemetry/src/core/events/emit.lua")
local player_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/player_reader.lua")
local world_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/world_reader.lua")
local session_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/session_reader.lua")
local mod_list_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/mod_list_reader.lua")
local frame_clock = dofile_once("mods/noita-telemetry/src/adapters/noita/frame_clock.lua")
local biome_rules = dofile_once("mods/noita-telemetry/src/core/biome.lua")
local game_mode_rules = dofile_once("mods/noita-telemetry/src/core/game_mode.lua")
local timing = dofile_once("mods/noita-telemetry/src/libs/timing.lua")
local version = dofile_once("mods/noita-telemetry/src/core/version.lua")
local inventory_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/inventory_reader.lua")
local writer = dofile_once("mods/noita-telemetry/src/core/run/writer.lua")
local ulid = dofile_once("mods/noita-telemetry/src/core/ulid.lua")
local persistence = dofile_once("mods/noita-telemetry/src/core/run/persistence.lua")
local session = dofile_once("mods/noita-telemetry/src/core/run/session.lua")
local status = dofile_once("mods/noita-telemetry/src/core/run/status.lua")
local loader = dofile_once("mods/noita-telemetry/src/adapters/native/loader.lua")
local holy_mountain_enter = dofile_once("mods/noita-telemetry/src/core/events/polls/holy_mountain_enter.lua")
local inventory_carry_start = dofile_once("mods/noita-telemetry/src/core/events/polls/inventory_carry_start.lua")
local run_skip = dofile_once("mods/noita-telemetry/src/core/events/run_skip.lua")
local message = dofile_once("mods/noita-telemetry/src/core/messaging.lua")

local M = {}

local function init_run_state(state, player, scan)
  state.run_start_frame = frame_clock.get_frame()
  state.player_entity_id = player
  state.current_biome = world_reader.get_biome(player)
  state.in_holy_mountain = biome_rules.is_holy_mountain(state.current_biome)
  state.holy_mountain_enter_gold = player_reader.get_gold(player)
  state.holy_mountain_spent = 0
  state.holy_mountain_stole = false
  state.last_gold = player_reader.get_gold(player)
  state.telemetry_perk_pick_index = 0
  if scan ~= nil then
    state.prev_inventory_ids = scan.inventory_ids
  else
    state.prev_inventory_ids = inventory_reader.get_inventory_entity_ids(player)
  end
  state.prev_carried = {}
  state.stevari_seen = false
  state.stevari_killed = false
  state.player_was_dead = false
  state.poll_counter = 0
  state.shop_stock = {}
  state.pending_shop_removals = {}
  state.emitted_steal_entities = {}
  state.emitted_shop_buy_entities = {}
  state.run_started_stamp = os.date("!%Y%m%d-%H%M%S")
  state.world_seed = session_reader.get_world_seed()
  state.run_end_snapshot = nil
  state.last_wands_snapshot = nil
  state.ending_game_completed_at_start = session_reader.is_ending_completed()

  local playtime_sec = timing.elapsed_sec(frame_clock.get_frame(), state.run_start_frame)
  local interval = loader.get_timeline_interval_sec()
  state.next_timeline_at = math.floor(playtime_sec / interval + 1) * interval
end

local function begin_run(state, player)
  status.announce_startup()

  local scan = inventory_reader.scan_inventory(player)
  init_run_state(state, player, scan)

  run_state.remember_wands(state, scan.wands)
  local id = ulid.generate()
  local started_at = emit.utc_timestamp()
  local world_seed = session_reader.get_world_seed()
  local mods_enabled = mod_list_reader.get_active_ids()
  local game_mode = game_mode_rules.resolve(mod_list_reader.is_enabled(game_mode_rules.NIGHTMARE))
  local noita_version = version.get()

  writer.start_run(id, started_at, {
    seed = world_seed,
    game_mode = game_mode,
    mods_enabled = mods_enabled,
    noita_version = noita_version,
  })
  persistence.save(id, started_at, state.run_start_frame, state.run_started_stamp, state.world_seed)

  session.queue_open_run(id, started_at, world_seed, mods_enabled, game_mode, noita_version)

  emit.emit(state, "run_start", {
    t_ms = 0,
    playtime_sec = 0,
    seed = world_seed,
    ng_plus = session_reader.get_ng_plus(),
    game_mode = game_mode,
    noita_version = noita_version,
    mods_enabled = mods_enabled,
    pos = world_reader.get_position(player),
    hp = player_reader.get_hp(player),
    wands = scan.wands,
    items = scan.items,
  })

  if state.in_holy_mountain then
    holy_mountain_enter.emit(state, player)
  end

  inventory_carry_start.seed_initial_carries(state, scan.carried)
end

local function resume_run(state, player)
  local persisted = persistence.load()
  if persisted == nil then
    begin_run(state, player)
    return
  end

  if not persistence.is_run_file_active(persisted.run_id) then
    persistence.clear()
    begin_run(state, player)
    return
  end

  local resumed = writer.resume_run(persisted.run_id, persisted.started_at)
  if resumed == nil then
    persistence.clear()
    begin_run(state, player)
    return
  end

  local scan = inventory_reader.scan_inventory(player)
  init_run_state(state, player, scan)
  state.prev_carried = scan.carried
  if persisted.run_start_frame ~= nil then
    state.run_start_frame = persisted.run_start_frame
  end
  if persisted.run_started_stamp ~= nil then
    state.run_started_stamp = persisted.run_started_stamp
  end
  if persisted.world_seed ~= nil then
    state.world_seed = persisted.world_seed
  end

  session.queue_open_run(
    persisted.run_id,
    persisted.started_at,
    session_reader.get_world_seed(),
    mod_list_reader.get_active_ids(),
    game_mode_rules.resolve(mod_list_reader.is_enabled(game_mode_rules.NIGHTMARE)),
    version.get()
  )
end

--- Returns an i18n key when this world should not start/resume ntel recording.
local function skip_recording_reason()
  if session_reader.get_ng_plus() > 0 then
    return message.KEYS.MSG_RUN_SKIPPED_NG_PLUS
  end
  if session_reader.is_ending_completed() then
    return message.KEYS.MSG_RUN_SKIPPED_ENDING_COMPLETED
  end
  return nil
end

function M.emit(player_entity_id)
  local state = run_state.get()
  if not writer.is_active() and state.waiting_for_player then
    state.waiting_for_player = false
    -- NG+ and post-clear (ending already completed) worlds are not recorded.
    local skip_key = skip_recording_reason()
    if skip_key ~= nil then
      state.resuming = false
      run_skip.skip_recording(state, skip_key)
      return
    end
    if state.resuming then
      state.resuming = false
      resume_run(state, player_entity_id)
    else
      begin_run(state, player_entity_id)
    end
  end

  if writer.is_active() then
    state.player_entity_id = player_entity_id
    state.player_was_dead = player_reader.is_dead(player_entity_id)
  end
end

return M
