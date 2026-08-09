-- Which language the player is running Noita in. Detected once and cached: the
-- language cannot change mid-session.

local text_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/text_reader.lua")

local M = {}

local cached = nil

local function detect()
  -- Keys must start with "$". Compare a vanilla UI label (en: "ON", ja: "オン").
  local on_label = text_reader.get("$option_on")
  if type(on_label) == "string" and on_label == "オン" then
    return "ja"
  end

  return "en"
end

function M.current()
  if cached == nil then
    cached = detect()
  end
  return cached
end

return M
