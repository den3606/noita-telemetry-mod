local M = {}

local function escape_string(value)
  local escaped = value:gsub("\\", "\\\\")
  escaped = escaped:gsub("\"", "\\\"")
  escaped = escaped:gsub("\r", "\\r")
  escaped = escaped:gsub("\n", "\\n")
  escaped = escaped:gsub("\t", "\\t")
  return '"' .. escaped .. '"'
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

function M.encode_keys(value, keys)
  if type(value) ~= "table" then
    return M.encode(value)
  end
  if type(keys) ~= "table" then
    return M.encode(value)
  end

  local parts = {}
  local seen = {}
  for index = 1, #keys do
    local key = keys[index]
    seen[key] = true
    if value[key] ~= nil then
      parts[#parts + 1] = escape_string(tostring(key)) .. ":" .. M.encode(value[key])
    end
  end

  for key, nested in pairs(value) do
    if not seen[key] then
      parts[#parts + 1] = escape_string(tostring(key)) .. ":" .. M.encode(nested)
    end
  end

  return "{" .. table.concat(parts, ",") .. "}"
end

local function decode_error(message)
  error("json decode: " .. message, 3)
end

function M.decode(input)
  if type(input) ~= "string" then
    decode_error("input must be a string")
  end

  local index = 1
  local length = #input

  local parse_value

  local function peek()
    return input:sub(index, index)
  end

  local function consume(char)
    if peek() ~= char then
      decode_error("expected '" .. char .. "'")
    end
    index = index + 1
  end

  local function skip_whitespace()
    while index <= length do
      local char = peek()
      if char == " " or char == "\t" or char == "\n" or char == "\r" then
        index = index + 1
      else
        break
      end
    end
  end

  local function parse_string()
    consume('"')
    local parts = {}
    while index <= length do
      local char = peek()
      if char == '"' then
        index = index + 1
        return table.concat(parts)
      end
      if char == "\\" then
        index = index + 1
        if index > length then
          decode_error("unterminated escape")
        end
        local escaped = peek()
        if escaped == '"' or escaped == "\\" or escaped == "/" then
          parts[#parts + 1] = escaped
        elseif escaped == "b" then
          parts[#parts + 1] = "\b"
        elseif escaped == "f" then
          parts[#parts + 1] = "\f"
        elseif escaped == "n" then
          parts[#parts + 1] = "\n"
        elseif escaped == "r" then
          parts[#parts + 1] = "\r"
        elseif escaped == "t" then
          parts[#parts + 1] = "\t"
        elseif escaped == "u" then
          local hex = input:sub(index + 1, index + 4)
          if #hex < 4 or not hex:match("^%x%x%x%x$") then
            decode_error("invalid unicode escape")
          end
          parts[#parts + 1] = string.char(tonumber(hex, 16))
          index = index + 4
        else
          decode_error("invalid escape")
        end
        index = index + 1
      else
        parts[#parts + 1] = char
        index = index + 1
      end
    end
    decode_error("unterminated string")
  end

  local function parse_number()
    local start = index
    if peek() == "-" then
      index = index + 1
    end
    while index <= length and peek():match("%d") do
      index = index + 1
    end
    if peek() == "." then
      index = index + 1
      while index <= length and peek():match("%d") do
        index = index + 1
      end
    end
    if peek() == "e" or peek() == "E" then
      index = index + 1
      if peek() == "+" or peek() == "-" then
        index = index + 1
      end
      while index <= length and peek():match("%d") do
        index = index + 1
      end
    end
    return tonumber(input:sub(start, index - 1))
  end

  local function parse_literal(literal, value)
    if input:sub(index, index + #literal - 1) ~= literal then
      decode_error("expected " .. literal)
    end
    index = index + #literal
    return value
  end

  function parse_value()
    skip_whitespace()
    local char = peek()
    if char == '"' then
      return parse_string()
    end
    if char == "{" then
      consume("{")
      skip_whitespace()
      local object = {}
      if peek() == "}" then
        index = index + 1
        return object
      end
      while true do
        skip_whitespace()
        local key = parse_string()
        skip_whitespace()
        consume(":")
        object[key] = parse_value()
        skip_whitespace()
        if peek() == "}" then
          index = index + 1
          return object
        end
        consume(",")
      end
    end
    if char == "[" then
      consume("[")
      skip_whitespace()
      local array = {}
      if peek() == "]" then
        index = index + 1
        return array
      end
      local position = 1
      while true do
        array[position] = parse_value()
        position = position + 1
        skip_whitespace()
        if peek() == "]" then
          index = index + 1
          return array
        end
        consume(",")
        skip_whitespace()
      end
    end
    if char == "-" or char:match("%d") then
      return parse_number()
    end
    if input:sub(index, index + 3) == "true" then
      return parse_literal("true", true)
    end
    if input:sub(index, index + 4) == "false" then
      return parse_literal("false", false)
    end
    if input:sub(index, index + 3) == "null" then
      return parse_literal("null", nil)
    end
    decode_error("unexpected token")
  end

  local value = parse_value()
  skip_whitespace()
  if index <= length then
    decode_error("trailing characters")
  end
  return value
end

return M
