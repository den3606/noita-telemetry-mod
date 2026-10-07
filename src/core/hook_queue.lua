-- Messages from ModLuaFileAppend hooks to the init.lua context.
-- Appended scripts (perk.lua, shop_effect.lua, ...) run in a different Lua
-- state, so init.lua globals are invisible there; Globals* storage is shared
-- across states. Hooks only push facts; init.lua drains and emits events.

local mod_globals = dofile_once("mods/noita-telemetry/src/adapters/noita/mod_globals.lua")

local M = {}

local KEY = "noita_telemetry_hook_queue"
local LINE_SEPARATOR = "\n"
local FIELD_SEPARATOR = "|"

local function is_encodable(value)
  return value ~= nil and not tostring(value):find("[|\n]")
end

--- Returns false (and stores nothing) when kind or a field is nil or contains a separator.
function M.push(kind, fields)
  if not is_encodable(kind) then
    return false
  end

  local parts = { tostring(kind) }
  for i = 1, table.maxn(fields) do
    local value = fields[i]
    if not is_encodable(value) then
      return false
    end
    parts[#parts + 1] = tostring(value)
  end

  -- Read-then-append so several pushes in one frame are all kept (Lua runs on one thread).
  local line = table.concat(parts, FIELD_SEPARATOR)
  local current = mod_globals.get(KEY, "")
  mod_globals.set(KEY, current == "" and line or (current .. LINE_SEPARATOR .. line))
  return true
end

function M.drain()
  local raw = mod_globals.get(KEY, "")
  if raw == "" then
    return {}
  end
  mod_globals.set(KEY, "")

  local messages = {}
  for line in raw:gmatch("[^\n]+") do
    local fields = {}
    for part in (line .. FIELD_SEPARATOR):gmatch("([^|]*)|") do
      fields[#fields + 1] = part
    end
    local kind = table.remove(fields, 1)
    messages[#messages + 1] = { kind = kind, fields = fields }
  end
  return messages
end

return M
