dofile("data/scripts/lib/mod_settings.lua")

local message = dofile_once("mods/noita-telemetry/src/core/messaging.lua")
local KEYS = message.KEYS

local mod_id = "noita-telemetry"
mod_settings_version = 7

local function draw_token_setup(mod_id, gui, in_main_menu, _, setting)
  GuiLayoutBeginVertical(gui, mod_setting_group_x_offset, 0)
  GuiText(gui, 0, 0, message.t(KEYS.SETTINGS_TOKEN_SETUP))
  GuiLayoutAddVerticalSpacing(gui, 2)
  for _, line in ipairs(message.lines(KEYS.SETTINGS_TOKEN_SETUP)) do
    GuiText(gui, 0, 0, line)
  end
  GuiLayoutEnd(gui)
  mod_setting_tooltip(mod_id, gui, in_main_menu, setting)
end

local function mod_settings_table()
  return {
    {
      id = "force_win_streak",
      ui_name = message.t(KEYS.SETTINGS_FORCE_WIN_STREAK),
      ui_description = message.t(KEYS.SETTINGS_FORCE_WIN_STREAK_DESC),
      value_default = false,
      scope = MOD_SETTING_SCOPE_RUNTIME,
    },
    {
      id = "sync_enabled",
      ui_name = message.t(KEYS.SETTINGS_CLOUD_UPLOAD),
      ui_description = message.t(KEYS.SETTINGS_CLOUD_UPLOAD_DESC),
      value_default = true,
      scope = MOD_SETTING_SCOPE_RUNTIME,
    },
    {
      id = "delete_run_after_upload",
      ui_name = message.t(KEYS.SETTINGS_DELETE_RUN_AFTER_UPLOAD),
      ui_description = message.t(KEYS.SETTINGS_DELETE_RUN_AFTER_UPLOAD_DESC),
      value_default = false,
      scope = MOD_SETTING_SCOPE_RUNTIME,
    },
    {
      id = "token_setup",
      ui_name = message.t(KEYS.SETTINGS_TOKEN_SETUP),
      ui_description = message.t(KEYS.SETTINGS_TOKEN_SETUP_DESC),
      value_default = "",
      scope = MOD_SETTING_SCOPE_RUNTIME,
      not_setting = true,
      ui_fn = draw_token_setup,
    },
  }
end

function ModSettingsUpdate(init_scope)
  mod_settings_update(mod_id, mod_settings_table(), init_scope)
end

function ModSettingsGuiCount()
  return mod_settings_gui_count(mod_id, mod_settings_table())
end

function ModSettingsGui(gui, in_main_menu)
  mod_settings_gui(mod_id, mod_settings_table(), gui, in_main_menu)
end

function OnModSettingsChanged() end
