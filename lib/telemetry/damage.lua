local M = {}

local DAMAGE_HOOK_SCRIPT = "mods/noita-telemetry/hooks/damage_received.lua"

local function get_lua_components(entity_id)
  local components = EntityGetComponent(entity_id, "LuaComponent")
  if components == nil then
    return {}
  end
  if type(components) == "number" then
    return { components }
  end
  return components
end

function M.has_hook(entity_id)
  if entity_id == nil then
    return false
  end

  for _, component_id in ipairs(get_lua_components(entity_id)) do
    local script = ComponentGetValue2(component_id, "script_damage_received")
    if script == DAMAGE_HOOK_SCRIPT then
      return true
    end
  end

  return false
end

function M.attach_hook(entity_id)
  if entity_id == nil or M.has_hook(entity_id) then
    return
  end

  EntityAddComponent(entity_id, "LuaComponent", {
    script_damage_received = DAMAGE_HOOK_SCRIPT,
    execute_every_n_frame = -1,
  })
end

function M.classify_damage_type(entity_thats_responsible, projectile_thats_responsible, player_entity)
  if player_entity ~= nil and entity_thats_responsible == player_entity then
    return "self"
  end

  if entity_thats_responsible == nil or entity_thats_responsible == 0 then
    return "material"
  end

  if projectile_thats_responsible ~= nil and projectile_thats_responsible > 0 then
    return "projectile"
  end

  return "other"
end

function M.resolve_source(entity_thats_responsible, message)
  if entity_thats_responsible ~= nil and entity_thats_responsible > 0 then
    local name = EntityGetName(entity_thats_responsible)
    if name ~= nil and name ~= "" then
      return name
    end

    local filename = EntityGetFilename(entity_thats_responsible)
    if filename ~= nil and filename ~= "" then
      return filename
    end

    return tostring(entity_thats_responsible)
  end

  if message ~= nil and message ~= "" then
    return message
  end

  return "unknown"
end

return M
