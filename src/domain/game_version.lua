-- Noita build version as players know it. `data/version.txt` holds a commit hash for
-- some builds, so known hashes map back to the release date.

local M = {}

M.LATEST = "Jan-25-2025"

local VERSION_BY_HASH = {
  ["8d7016a611ceb7c6530534c83dc6c74c20ba52c6"] = "Jan-25-2025",
  ["03f5a57aa95889a9959fd26f41233e008bc3924c"] = "Aug-12-2024",
  ["b6204dd7f608e17ec5138007828cab69e0f65dec"] = "Apr-30-2024",
  ["a23e1eda8fccf173633ffc447b0c1ba830d8ba15"] = "Apr-08-2024",
}

--- The release date for a known hash, the trimmed text otherwise, LATEST when nothing was read.
---@param raw string|nil contents of data/version.txt
---@return string
function M.normalize(raw)
  local trimmed = raw ~= nil and raw:match("^%s*(.-)%s*$") or ""
  if trimmed == "" then
    return M.LATEST
  end
  return VERSION_BY_HASH[trimmed] or VERSION_BY_HASH[trimmed:lower()] or trimmed
end

return M
