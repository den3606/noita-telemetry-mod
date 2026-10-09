-- What describes a run, read once when it opens: the .run header, the ingest session
-- and run_start all carry the same values.

local session_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/session_reader.lua")
local mod_list_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/mod_list_reader.lua")
local game_mode_rules = dofile_once("mods/noita-telemetry/src/domain/game_mode.lua")
local version = dofile_once("mods/noita-telemetry/src/application/version.lua")

---@class RunHeader
---@field seed? integer nil when Noita reports no world seed
---@field game_mode string
---@field mods_enabled string[]
---@field noita_version string

local M = {}

---@return RunHeader
function M.read()
  return {
    seed = session_reader.get_world_seed(),
    game_mode = game_mode_rules.resolve(mod_list_reader.is_enabled(game_mode_rules.NIGHTMARE)),
    mods_enabled = mod_list_reader.get_active_ids(),
    noita_version = version.get(),
  }
end

return M
