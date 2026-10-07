-- Mutable run-scoped state. Owned here; callers pass the table (or call get()).
-- Formerly events/context.lua M.state.

local M = {}

local function blank()
  return {
    run_start_frame = 0,
    waiting_for_player = false,
    resuming = false,
    player_entity_id = nil,
    current_biome = nil,
    in_holy_mountain = false,
    holy_mountain_enter_gold = 0,
    holy_mountain_spent = 0,
    holy_mountain_stole = false,
    last_gold = 0,
    telemetry_perk_pick_index = 0,
    prev_inventory_ids = {},
    prev_carried = {},
    stevari_seen = false,
    stevari_killed = false,
    player_was_dead = false,
    poll_counter = 0,
    shop_stock = {},
    pending_shop_removals = {},
    emitted_steal_entities = {},
    emitted_shop_buy_entities = {},
    run_started_stamp = nil,
    world_seed = nil,
    run_end_snapshot = nil,
    last_wands_snapshot = nil,
    ending_game_completed_at_start = false,
    next_timeline_at = 0,
  }
end

local current = blank()

function M.get()
  return current
end

function M.copy_wand_stats(stats)
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

function M.copy_wands(wands)
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
      stats = M.copy_wand_stats(wand.stats),
    }
  end
  return copy
end

function M.remember_wands(state, wands)
  if wands ~= nil and #wands > 0 then
    state.last_wands_snapshot = M.copy_wands(wands)
  end
end

function M.apply_wand_fallback(state, snapshot)
  if snapshot == nil then
    return nil
  end
  if snapshot.wands ~= nil and #snapshot.wands > 0 then
    M.remember_wands(state, snapshot.wands)
    return snapshot
  end
  if state.last_wands_snapshot ~= nil and #state.last_wands_snapshot > 0 then
    snapshot.wands = M.copy_wands(state.last_wands_snapshot)
    snapshot.wand_count = #snapshot.wands
  end
  return snapshot
end

return M
