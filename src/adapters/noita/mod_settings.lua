-- Generic Noita MOD settings reader (`ModSettingGet`). No telemetry knowledge;
-- callers decide what a given setting id/default means.

local MOD_ID = "noita-telemetry"

local M = {}

function M.get(id, default)
  local value = ModSettingGet(MOD_ID .. "." .. id)
  if value == nil then
    return default
  end

  return value
end

function M.get_bool(id, default)
  local value = M.get(id, default)
  if type(value) == "boolean" then
    return value
  end
  if type(value) == "number" then
    return value ~= 0
  end
  return default
end

return M
