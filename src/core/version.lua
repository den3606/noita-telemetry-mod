-- Normalizes the Noita build version. `data/version.txt` holds a commit hash for
-- some builds, so known hashes map back to the release date players recognize.

local text_file_reader = dofile_once("mods/noita-telemetry/src/adapters/noita/text_file_reader.lua")

local M = {}

local value = "Jan-25-2025"

local VERSION_BY_HASH = {
  ["8d7016a611ceb7c6530534c83dc6c74c20ba52c6"] = "Jan-25-2025",
  ["03f5a57aa95889a9959fd26f41233e008bc3924c"] = "Aug-12-2024",
  ["b6204dd7f608e17ec5138007828cab69e0f65dec"] = "Apr-30-2024",
  ["a23e1eda8fccf173633ffc447b0c1ba830d8ba15"] = "Apr-08-2024",
}

local function trim(raw)
  if raw == nil then
    return nil
  end
  return raw:match("^%s*(.-)%s*$")
end

local function normalize(raw)
  if raw == nil or raw == "" then
    return value
  end

  local mapped = VERSION_BY_HASH[raw]
  if mapped ~= nil then
    return mapped
  end

  if VERSION_BY_HASH[raw:lower()] ~= nil then
    return VERSION_BY_HASH[raw:lower()]
  end

  return raw
end

--- Must run inside the mod load window (see src/boot.lua): the game data files
--- are only readable there.
function M.init()
  local raw = text_file_reader.get_content("data/version.txt")
  if raw == nil then
    return
  end
  value = normalize(trim(raw))
end

function M.get()
  return value
end

return M
