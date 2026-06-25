--- Project name resolution for Java DAP sessions.
--- Resolves project name from JDTLS client roots, global vars, or filesystem markers.
local M = {}

local paths = require("jdtls-nvim.paths")

local project_name_cache = {}

local function normalize_path(path)
  if type(path) ~= "string" or path == "" then return nil end
  return paths.normalize_root(path)
end

local function path_has_prefix(path, prefix)
  path = normalize_path(path)
  prefix = normalize_path(prefix)
  if not path or not prefix then return false end
  if path == prefix then return true end
  return path:sub(1, #prefix + 1) == (prefix .. "/")
end

local function best_jdtls_root(path_hint)
  local ok_clients, clients = pcall(vim.lsp.get_clients, { name = "jdtls" })
  if not ok_clients or type(clients) ~= "table" then return nil end

  local normalized_hint = normalize_path(path_hint)
  local best_root = nil
  local best_len = -1

  for _, client in ipairs(clients) do
    local root = normalize_path(client and client.config and client.config.root_dir)
    if root then
      if not normalized_hint then
        if #root > best_len then
          best_root = root
          best_len = #root
        end
      elseif path_has_prefix(normalized_hint, root) and #root > best_len then
        best_root = root
        best_len = #root
      end
    end
  end

  return best_root
end

local function nearest_java_root(path)
  local marker = vim.fs.find({ "mvnw", "pom.xml", "settings.gradle", "build.gradle", ".git" }, {
    path = path or vim.fn.getcwd(),
    upward = true,
  })[1]
  return marker and vim.fs.dirname(marker) or nil
end

local function cached_basename(root)
  local cached = project_name_cache[root]
  if cached then return cached end
  local resolved = vim.fn.fnamemodify(root, ":t")
  project_name_cache[root] = resolved
  return resolved
end

local function nearest_pom(path_hint)
  local start = normalize_path(path_hint)
  if not start then start = normalize_path(vim.fn.expand("%:p:h")) end
  if not start then start = normalize_path(vim.fn.getcwd()) end
  if not start then return nil end
  return vim.fs.find("pom.xml", { path = start, upward = true })[1]
end

--- Extract the module's own artifactId from a pom.xml (ignoring <parent>).
---@param pom_path string
---@return string|nil artifact_id
local function pom_artifact_id(pom_path)
  local ok, lines = pcall(vim.fn.readfile, pom_path)
  if not ok or type(lines) ~= "table" then return nil end
  local content = table.concat(lines, "\n")
  -- Drop the <parent>...</parent> block so we read the project's own artifactId.
  content = content:gsub("<parent>.-</parent>", "")
  -- Keep only the project header (coordinates live before deps/build/modules),
  -- so we never match an artifactId from a dependency or plugin.
  content = content:match("^(.-)<dependencies")
    or content:match("^(.-)<dependencyManagement")
    or content:match("^(.-)<build")
    or content:match("^(.-)<profiles")
    or content:match("^(.-)<modules")
    or content
  local artifact = content:match("<artifactId>%s*([^<%s][^<]-)%s*</artifactId>")
  if artifact and artifact ~= "" then return artifact end
  return nil
end

--- Resolve the JDTLS/eclipse project name for the Maven module owning a path.
--- Falls back to M.name when no pom artifactId can be resolved.
---@param path_hint? string File or directory path to resolve from
---@return string|nil project_name
function M.module_name(path_hint)
  local pom = nearest_pom(path_hint)
  if pom then
    local artifact = pom_artifact_id(pom)
    if artifact then return artifact end
    local module_root = normalize_path(vim.fs.dirname(pom))
    if module_root then return cached_basename(module_root) end
  end
  return M.name(path_hint)
end

--- Resolve the Java project name for a given path hint.
---@param path_hint? string File or directory path to resolve from
---@return string|nil project_name
function M.name(path_hint)
  local root = best_jdtls_root(path_hint)
  if root then
    return cached_basename(root)
  end

  local global_name = vim.g.jdtls_nvim_project_name
  if type(global_name) == "string" and global_name ~= "" then
    return global_name
  end

  local normalized_hint = normalize_path(path_hint)
  if not normalized_hint then normalized_hint = normalize_path(vim.fn.expand("%:p:h")) end
  if not normalized_hint then normalized_hint = normalize_path(vim.fn.getcwd()) end
  local guessed_root = nearest_java_root(normalized_hint) or nearest_java_root(vim.fn.getcwd())
  guessed_root = normalize_path(guessed_root)
  if guessed_root then
    return cached_basename(guessed_root)
  end

  return nil
end

return M
