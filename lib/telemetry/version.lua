local M = {
  value = "Jan-25-2025",
}

local VERSION_BY_HASH = {
  ["8d7016a611ceb7c6530534c83dc6c74c20ba52c6"] = "Jan-25-2025",
  ["03f5a57aa95889a9959fd26f41233e008bc3924c"] = "Aug-12-2024",
  ["b6204dd7f608e17ec5138007828cab69e0f65dec"] = "Apr-30-2024",
  ["a23e1eda8fccf173633ffc447b0c1ba830d8ba15"] = "Apr-08-2024",
}

local function trim(value)
  if value == nil then
    return nil
  end
  return value:match("^%s*(.-)%s*$")
end

local function normalize(raw)
  if raw == nil or raw == "" then
    return M.value
  end

  local mapped = VERSION_BY_HASH[raw]
  if mapped ~= nil then
    return mapped
  end

  if VERSION_BY_HASH[raw:lower()] ~= nil then
    return VERSION_BY_HASH[raw:lower()]
  end

  return raw
end

function M.init()
  if ModTextFileGetContent == nil then
    return
  end

  local raw = ModTextFileGetContent("data/version.txt")
  M.value = normalize(trim(raw))
end

function M.get()
  return M.value
end

return M
