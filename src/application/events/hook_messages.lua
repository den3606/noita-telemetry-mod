-- Drains adapters/noita/hook_queue.lua in the init.lua context and routes each message to its event.

local hook_queue = dofile_once("mods/noita-telemetry/src/adapters/noita/hook_queue.lua")
local perk_pick = dofile_once("mods/noita-telemetry/src/application/events/perk_pick.lua")
local shop_item_pickup = dofile_once("mods/noita-telemetry/src/application/events/shop_item_pickup.lua")
local perk_reroll = dofile_once("mods/noita-telemetry/src/application/events/perk_reroll.lua")

local M = {}

local HANDLERS = {
  perk_pick = perk_pick.emit,
  shop_pickup = shop_item_pickup.emit,
  perk_reroll = perk_reroll.emit,
}

function M.discard_pending()
  hook_queue.drain()
end

function M.dispatch_pending()
  for _, message in ipairs(hook_queue.drain()) do
    local handler = HANDLERS[message.kind]
    if handler ~= nil then
      handler(message.fields)
    end
  end
end

return M
