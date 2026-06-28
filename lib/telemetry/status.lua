local config = dofile_once("mods/noita-telemetry/lib/telemetry/config.lua")
local i18n = dofile_once("mods/noita-telemetry/lib/telemetry/i18n.lua")
local link = dofile_once("mods/noita-telemetry/lib/telemetry/link.lua")

local M = {}

function M.is_remote()
  if not config.ready then
    return false
  end

  local sync = config.get_sync()
  if sync == nil or sync.enabled ~= true then
    return false
  end
  return link.is_linked()
end

function M.get_type_label(locale)
  if M.is_remote() then
    return i18n.t("type_remote", nil, locale)
  end
  return i18n.t("type_local", nil, locale)
end

function M.announce_startup()
  i18n.emit("status_enabled")
  local remote = M.is_remote()
  local type_label = remote and i18n.t("type_remote") or i18n.t("type_local")
  local type_label_en = remote and i18n.t("type_remote", nil, "en") or i18n.t("type_local", nil, "en")
  i18n.emit("status_type", { type = type_label }, { type = type_label_en })
end

return M
