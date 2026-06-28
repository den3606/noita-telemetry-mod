dofile("data/scripts/lib/mod_settings.lua")

local i18n = dofile_once("mods/noita-telemetry/lib/telemetry/i18n.lua")

local mod_id = "noita-telemetry"
mod_settings_version = 7

local function draw_token_setup(mod_id, gui, in_main_menu, _, setting)
  GuiLayoutBeginVertical(gui, mod_setting_group_x_offset, 0)
  GuiText(gui, 0, 0, i18n.t("settings_token_setup"))
  GuiLayoutAddVerticalSpacing(gui, 2)
  for _, line in ipairs(i18n.lines("settings_token_setup")) do
    GuiText(gui, 0, 0, line)
  end
  GuiLayoutEnd(gui)
  mod_setting_tooltip(mod_id, gui, in_main_menu, setting)
end

local function mod_settings_table()
  return {
    {
      id = "force_win_streak",
      ui_name = i18n.t("settings_force_win_streak"),
      ui_description = i18n.t("settings_force_win_streak_desc"),
      value_default = false,
      scope = MOD_SETTING_SCOPE_RUNTIME,
    },
    {
      id = "sync_enabled",
      ui_name = i18n.t("settings_cloud_upload"),
      ui_description = i18n.t("settings_cloud_upload_desc"),
      value_default = true,
      scope = MOD_SETTING_SCOPE_RUNTIME,
    },
    {
      id = "delete_run_after_upload",
      ui_name = i18n.t("settings_delete_run_after_upload"),
      ui_description = i18n.t("settings_delete_run_after_upload_desc"),
      value_default = false,
      scope = MOD_SETTING_SCOPE_RUNTIME,
    },
    {
      id = "token_setup",
      ui_name = i18n.t("settings_token_setup"),
      ui_description = i18n.t("settings_token_setup_desc"),
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

function OnModSettingsChanged()
end
