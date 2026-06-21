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
