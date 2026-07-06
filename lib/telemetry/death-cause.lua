local M = {}

local function trim(value)
  if value == nil then
    return ""
  end
  return (tostring(value):match("^%s*(.-)%s*$") or "")
end

local function strip_leading_punctuation(value)
  return trim((trim(value):gsub("^[%s|｜、,]+", "")))
end

--- Noita StatsGetValue("killed_by") is "[origin] | [cause]" (wiki).
function M.sanitize_killed_by(raw)
  local trimmed = trim(raw)
  if trimmed == "" then
    return ""
  end

  local origin, cause = trimmed:match("^(.-)%s*[|｜]%s*(.+)$")
  if cause == nil then
    return trimmed
  end

  origin = trim(origin)
  cause = trim(cause)

  if origin ~= "" and cause ~= "" then
    return origin .. "、" .. cause
  end
  if cause ~= "" then
    return cause
  end
  return origin
end

--- Noita StatsGetValue("killed_by_extra") is often a continuation clause prefixed with 「、」.
function M.sanitize_killed_with(raw)
  return strip_leading_punctuation(raw)
end

return M
