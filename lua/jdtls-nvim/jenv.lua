--- jenv integration: discovers active JDK and Java runtimes.
local M = {}

local cache = {
  active = nil,
  versions = nil,
  prefixes = {},
  java_versions = {},
}

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function systemlist(cmd)
  local raw_lines = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return {}
  end
  local lines = {}
  for _, line in ipairs(raw_lines) do
    line = trim(line)
    if line ~= "" and not line:match("^Not privileged to set domain environment") then
      lines[#lines + 1] = line
    end
  end
  return lines
end

local function system(cmd)
  local lines = systemlist(cmd)
  if #lines == 0 then
    return ""
  end
  return lines[#lines]
end

local function executable(cmd)
  return vim.fn.executable(cmd) == 1
end

local function java_home_is_valid(path)
  if type(path) ~= "string" or path == "" then
    return false
  end
  return vim.fn.executable(path:gsub("/+$", "") .. "/bin/java") == 1
end

local function normalize(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end
  return vim.fn.resolve(path):gsub("/+$", "")
end

local function jdk_home(path)
  path = normalize(path)
  if not path then return nil end

  local candidates = {
    path .. "/libexec/openjdk.jdk/Contents/Home",
    path .. "/Contents/Home",
    path,
  }

  for _, candidate in ipairs(candidates) do
    if java_home_is_valid(candidate) then
      return candidate:gsub("/+$", "")
    end
  end

  return path
end

local function major_version(value)
  if type(value) ~= "string" and type(value) ~= "number" then
    return nil
  end
  value = tostring(value):gsub("_", ".")

  local version = value:match("%-(%d[%d%.]*)") or value
  if version:match("^1%.8") or version == "8" then
    return "1.8"
  end
  return version:match("(%d+)")
end

local function runtime_name(version)
  local major = major_version(version)
  if major == "1.8" or major == "8" then
    return "JavaSE-1.8"
  end
  if major then
    return "JavaSE-" .. major
  end
  return nil
end

local function java_version(java_home)
  if not java_home_is_valid(java_home) then
    return nil
  end
  local normalized_home = normalize(java_home)
  if not normalized_home then
    return nil
  end
  if not cache.java_versions[normalized_home] then
    cache.java_versions[normalized_home] = vim.fn.system(
      vim.fn.shellescape(normalized_home:gsub("/+$", "") .. "/bin/java") .. " -version 2>&1"
    ):match('version "([^"]+)"') or false
  end
  return cache.java_versions[normalized_home] or nil
end

local function canonicalize_runtimes(runtimes)
  if type(runtimes) ~= "table" then
    return runtimes
  end

  for _, runtime in ipairs(runtimes) do
    if type(runtime) == "table" and type(runtime.path) == "string" then
      runtime.path = jdk_home(runtime.path) or runtime.path
    end
  end

  return runtimes
end

local function jenv_version_name()
  if not cache.active then
    cache.active = system("jenv version-name 2>/dev/null")
  end
  return cache.active
end

local function jenv_prefix(version)
  local suffix = version and version ~= "" and (" " .. vim.fn.shellescape(version)) or ""
  local key = version or "__active__"
  if cache.prefixes[key] == nil then
    cache.prefixes[key] = jdk_home(system("jenv prefix" .. suffix .. " 2>/dev/null")) or false
  end
  return cache.prefixes[key] or nil
end

local function active_java_home(jenv_cfg)
  jenv_cfg = jenv_cfg or {}
  local env_home = jdk_home(vim.env.JAVA_HOME)
  if jenv_cfg.use_java_home ~= false and java_home_is_valid(env_home) then
    return env_home
  end

  if not executable("jenv") then
    return env_home
  end

  local active = jenv_version_name()
  local prefix = jenv_prefix(active)
  if java_home_is_valid(prefix) then
    return prefix
  end

  prefix = jenv_prefix()
  if java_home_is_valid(prefix) then
    return prefix
  end

  return env_home
end

local function jenv_versions()
  if not executable("jenv") then
    return {}
  end
  if cache.versions then
    return cache.versions
  end
  local versions = {}
  for _, line in ipairs(systemlist("jenv versions --bare 2>/dev/null")) do
    line = trim(line)
    if line ~= "" and line ~= "system" then
      versions[#versions + 1] = line
    end
  end
  cache.versions = versions
  return versions
end

local function requested_runtimes(runtimes)
  if type(runtimes) ~= "table" then
    return nil
  end

  local order = {}
  local wanted = {}
  for _, runtime in ipairs(runtimes) do
    local major = major_version(runtime)
    if major and not wanted[major] then
      order[#order + 1] = major
      wanted[major] = true
    end
  end

  return order, wanted
end

local function index_of(values, value)
  for index, item in ipairs(values) do
    if item == value then
      return index
    end
  end
  return math.huge
end

local function selected_versions(jenv_cfg, active)
  local runtimes = jenv_cfg.runtimes
  if runtimes == "active" then
    return { active }
  end
  if runtimes == "all" then
    return jenv_versions()
  end

  local order, wanted = requested_runtimes(runtimes)
  if not order or not wanted then
    return { active }
  end

  local selected = {}
  local selected_by_major = {}

  local function add(version)
    local major = major_version(version)
    if major and wanted[major] and not selected_by_major[major] then
      selected[#selected + 1] = version
      selected_by_major[major] = true
    end
  end

  add(active)
  for _, version in ipairs(jenv_versions() or {}) do
    add(version)
  end

  table.sort(selected, function(left, right)
    local left_major = major_version(left)
    local right_major = major_version(right)
    local left_index = index_of(order, left_major)
    local right_index = index_of(order, right_major)
    return left_index < right_index
  end)

  return selected
end

local function runtime_entries(jenv_cfg, java_home)
  jenv_cfg = jenv_cfg or {}
  local active = jenv_version_name()
  local entries = {}
  local seen = {}

  local versions = selected_versions(jenv_cfg, active) or {}
  for _, version in ipairs(versions) do
    local path = jenv_prefix(version)
    local name = runtime_name(version) or runtime_name(java_version(path))
    if path and name and java_home_is_valid(path) and not seen[path] then
      entries[#entries + 1] = {
        name = name,
        path = path,
        default = normalize(path) == normalize(java_home) or version == active,
      }
      seen[path] = true
    end
  end

  if #entries == 0 and java_home_is_valid(java_home) then
    entries[1] = {
      name = runtime_name(java_version(java_home)) or "JavaSE-Unknown",
      path = java_home,
      default = true,
    }
  end

  return entries
end

function M.clear_cache()
  cache.active = nil
  cache.versions = nil
  cache.prefixes = {}
  cache.java_versions = {}
end

---@param cfg jdtls_nvim.Config
---@return jdtls_nvim.Config
function M.apply(cfg)
  local jenv_cfg = cfg.jenv or {}
  if not jenv_cfg.enabled then
    return cfg
  end

  local java_home = cfg.jdtls_java_home
  if type(java_home) ~= "string" or java_home == "" then
    java_home = active_java_home(jenv_cfg) or ""
    cfg.jdtls_java_home = java_home
  else
    cfg.jdtls_java_home = jdk_home(java_home) or java_home
    java_home = cfg.jdtls_java_home
  end

  if type(cfg.java_runtimes) ~= "table" or #cfg.java_runtimes == 0 then
    cfg.java_runtimes = runtime_entries(jenv_cfg, java_home)
  else
    cfg.java_runtimes = canonicalize_runtimes(cfg.java_runtimes)
  end

  return cfg
end

return M
