local config = dofile_once("mods/noita-telemetry/lib/telemetry/config.lua")
local collector = dofile_once("mods/noita-telemetry/lib/telemetry/collector.lua")
local damage = dofile_once("mods/noita-telemetry/lib/telemetry/damage.lua")
local snapshots = dofile_once("mods/noita-telemetry/lib/telemetry/snapshots.lua")
local logger = dofile_once("mods/noita-telemetry/lib/telemetry/logger.lua")
local run_id = dofile_once("mods/noita-telemetry/lib/telemetry/id.lua")
local persistence = dofile_once("mods/noita-telemetry/lib/telemetry/persistence.lua")
local session = dofile_once("mods/noita-telemetry/lib/telemetry/session.lua")
local status = dofile_once("mods/noita-telemetry/lib/telemetry/status.lua")

local M = {}

local state = {
  run_start_frame = 0,
  waiting_for_player = false,
  resuming = false,
  player_entity = nil,
  current_biome = nil,
  in_holy_mountain = false,
  holy_mountain_enter_gold = 0,
  holy_mountain_spent = 0,
  holy_mountain_stole = false,
  last_gold = 0,
  last_perk_counts = {},
  prev_inventory_ids = {},
  prev_carried = {},
  stevari_seen = false,
  stevari_killed = false,
  player_was_dead = false,
  poll_counter = 0,
  shop_stock = {},
  run_started_stamp = nil,
  world_seed = nil,
  run_end_snapshot = nil,
  last_wands_snapshot = nil,
  kolmis_snapshot_cached = false,
  pedestal_snapshot_cached = false,
  ending_game_completed_at_start = false,
}

local function copy_wand_stats(stats)
  if stats == nil then
    return nil
  end
  return {
    capacity = stats.capacity,
    recharge_time = stats.recharge_time,
    mana_max = stats.mana_max,
    mana_charge_speed = stats.mana_charge_speed,
    spread = stats.spread,
    speed_multiplier = stats.speed_multiplier,
  }
end

local function copy_wands(wands)
  if wands == nil then
    return nil
  end

  local copy = {}
  for i, wand in ipairs(wands) do
    local spells = {}
    for j, spell in ipairs(wand.spells or {}) do
      spells[j] = spell
    end
    copy[i] = {
      entity_id = wand.entity_id,
      name = wand.name,
      spells = spells,
      spell_count = wand.spell_count or #spells,
      stats = copy_wand_stats(wand.stats),
    }
  end
  return copy
end

local function remember_wands(wands)
  if wands ~= nil and #wands > 0 then
    state.last_wands_snapshot = copy_wands(wands)
  end
end

local function apply_wand_fallback(snapshot)
  if snapshot == nil then
    return nil
  end
  if snapshot.wands ~= nil and #snapshot.wands > 0 then
    remember_wands(snapshot.wands)
    return snapshot
  end
  if state.last_wands_snapshot ~= nil and #state.last_wands_snapshot > 0 then
    snapshot.wands = copy_wands(state.last_wands_snapshot)
    snapshot.wand_count = #snapshot.wands
  end
  return snapshot
end

local function capture_finish_snapshot(player)
  if player == nil then
    return nil
  end
  return apply_wand_fallback(snapshots.get_player_snapshot(player))
end

local function cache_milestone_snapshot(player)
  if player == nil or not logger.is_active() then
    return
  end
  state.run_end_snapshot = capture_finish_snapshot(player)
end

local function utc_timestamp()
  if os and os.date then
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
  end
  return "unknown"
end

local function timing_fields()
  return {
    t_ms = collector.get_t_ms(state.run_start_frame),
    playtime_sec = math.floor(collector.get_playtime_sec()),
  }
end

local function enrich_event_fields(fields)
  if state.player_entity ~= nil then
    if fields.position == nil then
      fields.position = collector.get_position(state.player_entity)
    end
    if fields.biome == nil then
      fields.biome = collector.get_biome(state.player_entity)
    end
  end
  return fields
end

local function emit(event_type, fields)
  local event = { type = event_type }
  for key, value in pairs(enrich_event_fields(fields or {})) do
    event[key] = value
  end
  logger.append_event(event)
end

local function copy_perk_counts(counts)
  local copy = {}
  for perk_id, count in pairs(counts) do
    copy[perk_id] = count
  end
  return copy
end

local function emit_holy_mountain_enter(player)
  local snapshot = snapshots.get_player_snapshot(player)
  remember_wands(snapshot.wands)
  state.in_holy_mountain = true
  state.holy_mountain_enter_gold = snapshot.gold
  state.holy_mountain_spent = 0
  state.holy_mountain_stole = false
  state.stevari_seen = false
  state.stevari_killed = false
  state.last_gold = snapshot.gold
  state.prev_inventory_ids = snapshots.get_inventory_entity_ids(player)
  state.shop_stock = snapshots.scan_shop_stock(player)

  emit("holy_mountain_enter", {
    t_ms = timing_fields().t_ms,
    playtime_sec = timing_fields().playtime_sec,
    biome = snapshot.biome,
    position = snapshot.position,
    gold = snapshot.gold,
    hp = snapshot.hp,
    wands = snapshot.wands,
    wand_count = snapshot.wand_count,
    items = snapshot.items,
    item_count = snapshot.item_count,
    perks = snapshot.perks,
  })
end

local function emit_holy_mountain_exit(player, cached_snapshot)
  if not state.in_holy_mountain then
    return
  end

  local snapshot = cached_snapshot or snapshots.get_player_snapshot(player)
  emit("holy_mountain_exit", {
    t_ms = timing_fields().t_ms,
    playtime_sec = timing_fields().playtime_sec,
    position = snapshot.position,
    gold = snapshot.gold,
    gold_spent_total = state.holy_mountain_spent,
    hp = snapshot.hp,
    wands = snapshot.wands,
    items = snapshot.items,
    perks = snapshot.perks,
    stole_any = state.holy_mountain_stole,
  })

  state.in_holy_mountain = false
  state.shop_stock = {}
end

local function emit_inventory_carry_start(info, playtime_sec, t_ms)
  local event = {
    t_ms = t_ms,
    playtime_sec = playtime_sec,
    entity_id = info.entity_id,
    item_id = info.item_id,
    item_type = info.item_type,
    container = info.container,
  }
  if info.wand_entity_id ~= nil then
    event.wand_entity_id = info.wand_entity_id
  end
  emit("inventory_carry_start", event)
end

local function emit_inventory_carry_end(info, reason, playtime_sec, t_ms)
  emit("inventory_carry_end", {
    t_ms = t_ms,
    playtime_sec = playtime_sec,
    entity_id = info.entity_id,
    item_id = info.item_id,
    item_type = info.item_type,
    reason = reason,
  })
end

local function seed_initial_carries(carried)
  state.prev_carried = carried or {}
  for _, info in pairs(state.prev_carried) do
    emit_inventory_carry_start(info, 0, 0)
  end
end

local function init_run_state(player, scan, options)
  options = options or {}
  state.run_start_frame = collector.get_frame()
  state.player_entity = player
  state.current_biome = collector.get_biome(player)
  state.in_holy_mountain = collector.is_holy_mountain_biome(state.current_biome)
  state.holy_mountain_enter_gold = collector.get_gold(player)
  state.holy_mountain_spent = 0
  state.holy_mountain_stole = false
  state.last_gold = collector.get_gold(player)
  if options.capture_perk_counts then
    state.last_perk_counts = copy_perk_counts(snapshots.get_perk_counts())
  else
    state.last_perk_counts = {}
  end
  if scan ~= nil then
    state.prev_inventory_ids = scan.inventory_ids
  else
    state.prev_inventory_ids = snapshots.get_inventory_entity_ids(player)
  end
  state.prev_carried = {}
  state.stevari_seen = false
  state.stevari_killed = false
  state.player_was_dead = false
  state.poll_counter = 0
  state.run_started_stamp = os.date("!%Y%m%d-%H%M%S")
  state.world_seed = collector.get_world_seed()
  state.run_end_snapshot = nil
  state.last_wands_snapshot = nil
  state.kolmis_snapshot_cached = false
  state.pedestal_snapshot_cached = false
  state.ending_game_completed_at_start = GameHasFlagRun("ending_game_completed")

  local playtime_sec = math.floor(collector.get_playtime_sec())
  local interval = config.timeline_interval_sec
  state.next_timeline_at = math.floor(playtime_sec / interval + 1) * interval
end

function M.begin_run(player)
  status.announce_startup()

  local scan = snapshots.scan_inventory(player)
  init_run_state(player, scan)

  remember_wands(scan.wands)
  local id = run_id.generate()
  local started_at = utc_timestamp()
  local world_seed = collector.get_world_seed()
  local mods_enabled = collector.get_mods_enabled()
  local game_mode = collector.get_game_mode()
  local noita_version = collector.get_noita_version()

  logger.start_run(id, started_at)
  persistence.save(id, started_at, state.run_start_frame, state.run_started_stamp, state.world_seed)

  session.queue_open_run(id, started_at, world_seed, mods_enabled, game_mode, noita_version)

  emit("run_start", {
    t_ms = 0,
    playtime_sec = 0,
    seed = world_seed,
    ng_plus = collector.get_ng_plus(),
    game_mode = game_mode,
    noita_version = noita_version,
    mods_enabled = mods_enabled,
    position = collector.get_position(player),
    hp = collector.get_hp(player),
    wands = scan.wands,
    items = scan.items,
  })

  if state.in_holy_mountain then
    emit_holy_mountain_enter(player)
  end

  seed_initial_carries(scan.carried)
end

function M.resume_run(player)
  local persisted = persistence.load()
  if persisted == nil then
    M.begin_run(player)
    return
  end

  if not persistence.is_run_file_active(persisted.run_id) then
    persistence.clear()
    M.begin_run(player)
    return
  end

  local resumed = logger.resume_run(persisted.run_id, persisted.started_at)
  if resumed == nil then
    persistence.clear()
    M.begin_run(player)
    return
  end

  local scan = snapshots.scan_inventory(player)
  init_run_state(player, scan, { capture_perk_counts = true })
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
    collector.get_world_seed(),
    collector.get_mods_enabled(),
    collector.get_game_mode(),
    collector.get_noita_version()
  )
end

function M.on_world_initialized()
  if logger.is_active() then
    return
  end

  local persisted = persistence.load()
  if persisted ~= nil and persistence.is_run_file_active(persisted.run_id) then
    state.resuming = true
  else
    persistence.clear()
    state.resuming = false
  end

  state.waiting_for_player = true
end

function M.on_player_spawned(player_entity)
  if not logger.is_active() and state.waiting_for_player then
    state.waiting_for_player = false
    if state.resuming then
      state.resuming = false
      M.resume_run(player_entity)
    else
      M.begin_run(player_entity)
    end
  end

  if logger.is_active() then
    state.player_entity = player_entity
    state.player_was_dead = collector.is_player_dead(player_entity)
    damage.attach_hook(player_entity)
  end
end

function M.on_damage_received(
  damage_amount,
  message,
  entity_thats_responsible,
  _is_fatal,
  projectile_thats_responsible
)
  if not logger.is_active() then
    return
  end

  local amount = tonumber(damage_amount)
  if amount == nil or amount <= 0 then
    return
  end

  local player = state.player_entity or collector.get_player_entity()
  if player == nil then
    return
  end

  local position = collector.get_position(player)
  local hp = collector.get_hp(player)
  local timing = timing_fields()

  emit("damage_taken", {
    t_ms = timing.t_ms,
    playtime_sec = timing.playtime_sec,
    amount = amount,
    source = damage.resolve_source(entity_thats_responsible, message),
    damage_type = damage.classify_damage_type(
      entity_thats_responsible,
      projectile_thats_responsible,
      player
    ),
    biome = collector.get_biome(player),
    position = position,
    hp_after = hp ~= nil and hp.current or nil,
  })
end

local function maybe_emit_biome_enter(player, biome)
  if state.current_biome == nil then
    state.current_biome = biome
    return
  end

  if biome == state.current_biome then
    return
  end

  local from_biome = state.current_biome
  state.current_biome = biome

  emit("biome_enter", {
    t_ms = timing_fields().t_ms,
    playtime_sec = timing_fields().playtime_sec,
    biome = biome,
    from_biome = from_biome,
    position = collector.get_position(player),
  })

  local entering_holy_mountain = collector.is_holy_mountain_biome(biome)
  if entering_holy_mountain and not state.in_holy_mountain then
    emit_holy_mountain_enter(player)
  elseif entering_holy_mountain and state.in_holy_mountain then
    -- Dungeon -> HM without a recorded exit (stale in_holy_mountain after crypt/HM edge cases).
    if from_biome ~= nil and not collector.is_holy_mountain_biome(from_biome) then
      emit_holy_mountain_exit(player)
      emit_holy_mountain_enter(player)
    end
  elseif state.in_holy_mountain and not entering_holy_mountain then
    emit_holy_mountain_exit(player)
  end
end

local function close_open_carries()
  local timing = timing_fields()
  for _, info in pairs(state.prev_carried or {}) do
    emit_inventory_carry_end(info, "run_end", timing.playtime_sec, timing.t_ms)
  end
  state.prev_carried = {}
end

local function maybe_emit_carry_changes(player)
  local current = snapshots.get_carried_entities(player)
  local previous = state.prev_carried or {}
  local timing = timing_fields()

  for entity_id, info in pairs(current) do
    if previous[entity_id] == nil then
      emit_inventory_carry_start(info, timing.playtime_sec, timing.t_ms)
    end
  end

  for entity_id, info in pairs(previous) do
    if current[entity_id] == nil then
      emit_inventory_carry_end(info, "removed", timing.playtime_sec, timing.t_ms)
    end
  end

  state.prev_carried = current
  remember_wands(snapshots.get_wands(player))
end

local function find_new_inventory_ids(current_ids, previous_ids)
  local new_ids = {}
  for entity_id in pairs(current_ids) do
    if previous_ids[entity_id] ~= true then
      new_ids[#new_ids + 1] = entity_id
    end
  end
  return new_ids
end

local function emit_shop_action(fields)
  local position = nil
  if state.player_entity ~= nil then
    position = collector.get_position(state.player_entity)
  end

  emit("shop_action", {
    t_ms = timing_fields().t_ms,
    playtime_sec = timing_fields().playtime_sec,
    position = position,
    action = fields.action,
    gold_before = state.last_gold,
    gold_spent = fields.gold_spent,
    gold_after = fields.gold_after,
    item_id = fields.item_id or "",
    item_type = fields.item_type or "other",
    stole = fields.stole or false,
  })
end

local function emit_shop_steals(player, gold, new_items, current_inventory_ids)
  local current_stock = snapshots.scan_shop_stock(player)
  local removed_shop = snapshots.find_removed_shop_stock(
    state.shop_stock,
    current_stock,
    current_inventory_ids
  )
  state.shop_stock = current_stock

  local steals = snapshots.match_shop_steals(removed_shop, new_items)
  for _, item_entity_id in ipairs(new_items) do
    if snapshots.has_shop_cost(item_entity_id) then
      local description = snapshots.describe_item(item_entity_id)
      local already_matched = false
      for _, matched_id in ipairs(steals) do
        if matched_id == item_entity_id then
          already_matched = true
          break
        end
      end
      if not already_matched then
        steals[#steals + 1] = item_entity_id
      end
    end
  end

  if #steals == 0 then
    return
  end

  state.holy_mountain_stole = true
  for _, item_entity_id in ipairs(steals) do
    local description = snapshots.describe_item(item_entity_id)
    emit_shop_action({
      action = "steal",
      gold_spent = 0,
      gold_after = gold,
      item_id = description.item_id,
      item_type = description.item_type,
      stole = true,
    })
  end
end

local function maybe_emit_shop_actions(player, gold, current_inventory_ids)
  if not state.in_holy_mountain then
    return
  end

  local new_items = find_new_inventory_ids(current_inventory_ids, state.prev_inventory_ids)
  local gold_spent = math.max(0, state.last_gold - gold)

  if gold_spent > 0 then
    state.holy_mountain_spent = state.holy_mountain_spent + gold_spent

    if #new_items > 0 then
      local remaining_spent = gold_spent
      for index, item_entity_id in ipairs(new_items) do
        local description = snapshots.describe_item(item_entity_id)
        local item_spent = remaining_spent
        if index < #new_items then
          local cost = snapshots.get_item_shop_cost(item_entity_id)
          if cost ~= nil then
            item_spent = cost
          end
          remaining_spent = math.max(0, remaining_spent - item_spent)
        end

        emit_shop_action({
          action = "buy",
          gold_spent = item_spent,
          gold_after = gold,
          item_id = description.item_id,
          item_type = description.item_type,
          stole = false,
        })
      end
    else
      emit_shop_action({
        action = "reroll",
        gold_spent = gold_spent,
        gold_after = gold,
        item_id = "",
        item_type = "other",
        stole = false,
      })
    end

    state.shop_stock = snapshots.scan_shop_stock(player)
  elseif #new_items > 0 then
    emit_shop_steals(player, gold, new_items, current_inventory_ids)
  else
    state.shop_stock = snapshots.scan_shop_stock(player)
  end
end

local function maybe_emit_perk_pick(player)
  local perk_counts = snapshots.get_perk_counts()
  local total_before = 0
  for _, count in pairs(state.last_perk_counts) do
    total_before = total_before + count
  end

  local new_picks = {}
  for perk_id, count in pairs(perk_counts) do
    local previous = state.last_perk_counts[perk_id] or 0
    for _ = previous + 1, count do
      new_picks[#new_picks + 1] = perk_id
    end
  end

  for index, perk_id in ipairs(new_picks) do
    emit("perk_pick", {
      t_ms = timing_fields().t_ms,
      playtime_sec = timing_fields().playtime_sec,
      position = collector.get_position(player),
      perk_id = perk_id,
      perk_index = total_before + index,
      options_offered = {},
      biome = collector.get_biome(player),
    })
  end

  state.last_perk_counts = copy_perk_counts(perk_counts)
end

local function maybe_emit_god_event(player)
  local stevari_id = collector.find_stevari_near(player)

  if stevari_id ~= nil and not state.stevari_seen then
    state.stevari_seen = true
    emit("god_event", {
      t_ms = timing_fields().t_ms,
      playtime_sec = timing_fields().playtime_sec,
      position = collector.get_position(player),
      angered = true,
      killed = false,
      biome = collector.get_biome(player),
    })
  end

  if state.stevari_seen and not state.stevari_killed then
    local alive = stevari_id ~= nil and collector.is_stevari_alive(stevari_id)
    if not alive then
      state.stevari_killed = true
      emit("god_event", {
        t_ms = timing_fields().t_ms,
        playtime_sec = timing_fields().playtime_sec,
        position = collector.get_position(player),
        angered = true,
        killed = true,
        biome = collector.get_biome(player),
      })
    end
  end
end

local function maybe_emit_timeline(player)
  local playtime_sec = math.floor(collector.get_playtime_sec())
  if playtime_sec < state.next_timeline_at then
    return
  end

  local snapshot = snapshots.get_player_snapshot(player)
  emit("timeline_tick", {
    t_ms = timing_fields().t_ms,
    playtime_sec = playtime_sec,
    biome = snapshot.biome,
    position = snapshot.position,
    hp = snapshot.hp,
    gold = snapshot.gold,
  })

  state.next_timeline_at = state.next_timeline_at + config.timeline_interval_sec
end

local function finalize_run()
  logger.end_run()
  logger.process_pending_upload()
  session.clear()
  persistence.clear()
  state.waiting_for_player = false
  state.run_end_snapshot = nil
  state.last_wands_snapshot = nil
end

local function finish_snapshot(player)
  if state.run_end_snapshot ~= nil then
    return state.run_end_snapshot
  end
  return capture_finish_snapshot(player)
end

local function empty_finish_snapshot()
  return {
    position = { x = 0, y = 0 },
    hp = { current = 0, max = 0 },
    wands = {},
    items = {},
    perks = {},
    gold = 0,
  }
end

local function complete_finish_run(player, result)
  if not logger.is_active() then
    finalize_run()
    return
  end

  local snapshot = finish_snapshot(player) or empty_finish_snapshot()

  pcall(function()
    if state.in_holy_mountain then
      emit_holy_mountain_exit(player, snapshot)
    end

    local finish_biome = snapshot.biome or state.current_biome
    maybe_emit_biome_enter(player, finish_biome)

    close_open_carries()

    emit("run_end", {
      t_ms = timing_fields().t_ms,
      playtime_sec = timing_fields().playtime_sec,
      result = result,
      position = snapshot.position,
      hp = snapshot.hp,
      wands = snapshot.wands,
      items = snapshot.items,
      perks = snapshot.perks,
      gold = snapshot.gold,
      enemies_killed = collector.get_session_stat("enemies_killed"),
      places_visited = collector.get_session_stat("places_visited"),
      projectiles_shot = collector.get_session_stat("projectiles_shot"),
    })
  end)

  finalize_run()
end

local function finish_run(player, result)
  if not logger.is_active() then
    return
  end

  if state.run_end_snapshot == nil and player ~= nil then
    state.run_end_snapshot = capture_finish_snapshot(player)
  end

  complete_finish_run(player, result)
end

function M.on_player_died(player_entity)
  if not logger.is_active() or not collector.is_player_dead(player_entity) then
    return
  end

  if state.player_was_dead then
    return
  end

  state.player_was_dead = true
  local position = collector.get_position(player_entity)

  emit("death", {
    t_ms = timing_fields().t_ms,
    playtime_sec = timing_fields().playtime_sec,
    biome = collector.get_biome(player_entity),
    position = position,
    killed_by = StatsGetValue("killed_by") or "",
    killed_with = StatsGetValue("killed_by_extra") or "",
    hp = collector.get_hp(player_entity) or { current = 0, max = 0 },
  })

  local result = collector.is_victory_death(player_entity) and "win" or "lose"
  finish_run(player_entity, result)
end

local function maybe_finish_on_ending_flag()
  if not logger.is_active() then
    return
  end
  if state.ending_game_completed_at_start then
    return
  end
  if not GameHasFlagRun("ending_game_completed") then
    return
  end

  M.on_victory()
end

function M.on_world_post_update()
  session.poll_open()
  logger.poll_upload()
  maybe_finish_on_ending_flag()

  if not logger.is_active() then
    return
  end

  local player = collector.get_player_entity()
  if player == nil then
    return
  end

  state.player_entity = player
  state.poll_counter = state.poll_counter + 1
  if state.poll_counter < config.poll_interval_frames then
    return
  end
  state.poll_counter = 0

  local biome = collector.get_biome(player)
  local gold = collector.get_gold(player)
  local current_inventory_ids = snapshots.get_inventory_entity_ids(player)

  maybe_emit_biome_enter(player, biome)
  maybe_emit_shop_actions(player, gold, current_inventory_ids)
  maybe_emit_perk_pick(player)
  maybe_emit_god_event(player)
  maybe_emit_timeline(player)
  maybe_emit_carry_changes(player)

  state.prev_inventory_ids = current_inventory_ids
  state.last_gold = gold
end

function M.on_kolmis_defeated()
  if not logger.is_active() or state.kolmis_snapshot_cached then
    return
  end

  state.kolmis_snapshot_cached = true
  local player = collector.get_player_entity() or state.player_entity
  cache_milestone_snapshot(player)
end

function M.on_pedestal_start()
  if not logger.is_active() or state.pedestal_snapshot_cached then
    return
  end

  state.pedestal_snapshot_cached = true
  local player = collector.get_player_entity() or state.player_entity
  cache_milestone_snapshot(player)
end

function M.on_victory()
  local player = collector.get_player_entity() or state.player_entity
  if player == nil or not logger.is_active() then
    return
  end

  -- Pedestal / kolmis hooks usually cache first; refresh here if the ending path skipped them.
  if state.run_end_snapshot == nil then
    cache_milestone_snapshot(player)
  end

  -- Finish synchronously: mountain altar endings (NG+/Pure/Peaceful) can reload the world
  -- before the next OnWorldPostUpdate. Also poll ending_game_completed for altar paths where
  -- the player survives (Pure, Toxic Immunity) and sampo_start_ending_sequence never returns.
  finish_run(player, "win")
end

return M
