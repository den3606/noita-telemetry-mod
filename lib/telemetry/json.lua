local M = {}

local function escape_string(value)
  return string.format("%q", value)
end

local function is_array(value)
  if type(value) ~= "table" then
    return false
  end

  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" then
      return false
    end
    count = count + 1
  end

  for index = 1, count do
    if value[index] == nil then
      return false
    end
  end

  return true
end

function M.encode(value)
  local value_type = type(value)

  if value == nil then
    return "null"
  end

  if value_type == "boolean" then
    return value and "true" or "false"
  end

  if value_type == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      return "null"
    end
    return tostring(value)
  end

  if value_type == "string" then
    return escape_string(value)
  end

  if value_type ~= "table" then
    error("unsupported json type: " .. value_type)
  end

  if is_array(value) then
    local parts = {}
    for index = 1, #value do
      parts[#parts + 1] = M.encode(value[index])
    end
    return "[" .. table.concat(parts, ",") .. "]"
  end

  local parts = {}
  for key, nested in pairs(value) do
    parts[#parts + 1] = escape_string(tostring(key)) .. ":" .. M.encode(nested)
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

return M
