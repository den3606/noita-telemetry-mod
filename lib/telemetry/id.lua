local native = dofile_once("mods/noita-telemetry/lib/telemetry/native.lua")
local errors = dofile_once("mods/noita-telemetry/lib/telemetry/errors.lua")

local M = {}

local ENCODING = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

local function encode_fixed(value, length)
  local chars = {}
  for _ = 1, length do
    local index = (value % 32) + 1
    chars[#chars + 1] = ENCODING:sub(index, index)
    value = math.floor(value / 32)
  end
  return table.concat(chars):reverse()
end

local function generate_fallback()
  local ms = 0
  if os and os.time then
    ms = os.time() * 1000
  end
  if GameGetFrameNum ~= nil then
    ms = ms + (GameGetFrameNum() % 1000)
  end

  local time_part = encode_fixed(ms, 10)
  local random_part = ""
  for _ = 1, 16 do
    local roll = 0
    if Random ~= nil then
      roll = Random(0, 31)
    else
      roll = math.random(0, 31)
    end
    random_part = random_part .. ENCODING:sub(roll + 1, roll + 1)
  end

  return time_part .. random_part
end

function M.generate()
  if native.available() then
    local id, err = native.generate_id()
    if id ~= nil then
      return id
    end
    errors.print(errors.ulid_native_failed, { err = tostring(err) })
  end

  return generate_fallback()
end

return M
