-- shop_action: one recorded shop transaction. buy comes from events/shop_item_pickup.lua
-- (shop_effect hook), reroll from events/perk_reroll.lua. Steals are not tracked (#344).

local emit = dofile_once("mods/noita-telemetry/src/application/events/emit.lua")
local world_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/world_reader.lua")

---@class ShopActionEvent : GameplayEventBase
---@field action string
---@field gold_before integer
---@field gold_spent integer
---@field gold_after integer
---@field item_id string
---@field item_type string
---@field wand? WandSnapshot the bought wand; only on a wand buy

local M = {}

function M.emit(state, fields)
  local pos = nil
  if state.run.player_entity_id ~= nil then
    pos = world_reader.get_position(state.run.player_entity_id)
  end

  ---@type ShopActionEvent
  local event = {
    t_ms = emit.timing_fields(state).t_ms,
    playtime_sec = emit.timing_fields(state).playtime_sec,
    pos = pos,
    action = fields.action,
    gold_before = fields.gold_before or state.inventory.last_gold,
    gold_spent = fields.gold_spent,
    gold_after = fields.gold_after,
    item_id = fields.item_id or "",
    item_type = fields.item_type or "other",
    wand = fields.wand,
  }
  emit.emit(state, "shop_action", event)
end

return M
