local token = dofile_once("mods/noita-telemetry/lib/telemetry/token.lua")

local M = {}

function M.get_mod_token()
  return token.get()
end

function M.is_linked()
  return token.is_configured()
end

function M.token_file_path()
  return token.token_file_path()
end

return M
