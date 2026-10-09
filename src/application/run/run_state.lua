-- Mutable run-scoped state, one sub-table per concern (see run/state/). Owned here;
-- callers pass the table (or call get()). A new run replaces every sub-table except lifecycle.

local lifecycle = dofile_once("mods/noita-telemetry/src/application/run/state/lifecycle.lua")
local location = dofile_once("mods/noita-telemetry/src/application/run/state/location.lua")
local holy_mountain = dofile_once("mods/noita-telemetry/src/application/run/state/holy_mountain.lua")
local inventory = dofile_once("mods/noita-telemetry/src/application/run/state/inventory.lua")
local run = dofile_once("mods/noita-telemetry/src/application/run/state/run.lua")

local M = {}

---@class RunStateTable
---@field lifecycle LifecycleState
---@field run RunState
---@field location LocationState
---@field holy_mountain HolyMountainState
---@field inventory InventoryState

---@return RunStateTable
local function blank()
  return {
    lifecycle = lifecycle.new(),
    run = run.new(),
    location = location.new(),
    holy_mountain = holy_mountain.new(),
    inventory = inventory.new(),
  }
end

local current = blank()

---@return RunStateTable
function M.get()
  return current
end

return M
