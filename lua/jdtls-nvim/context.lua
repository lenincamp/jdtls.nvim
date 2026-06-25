--- Public Java project context for task runners and integrations.
local M = {}

local config = require("jdtls-nvim.config")
local paths = require("jdtls-nvim.paths")

local function normalize(path)
  return paths.normalize_root(path)
end

local function path_has_prefix(path, prefix)
  path = normalize(path)
  prefix = normalize(prefix)
  if path == "" or prefix == "" then return false end
  return path == prefix or path:sub(1, #prefix + 1) == (prefix .. "/")
end

local function start_path(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  return name ~= "" and name or vim.loop.cwd()
end

local function client_root(bufnr)
  local path = start_path(bufnr)
  local best_root = nil
  local best_len = -1
  for _, client in ipairs(vim.lsp.get_clients({ name = "jdtls" })) do
    local root = normalize(client.config and client.config.root_dir)
    if root ~= "" and path_has_prefix(path, root) and #root > best_len then
      best_root = root
      best_len = #root
    end
  end
  return best_root
end

local function marker_root(markers, path)
  local found = vim.fs.find(markers, { path = path, upward = true })[1]
  if not found then
    return nil
  end
  return vim.fn.fnamemodify(found, ":p:h")
end

local function resolve_root(bufnr, cfg)
  local root = client_root(bufnr)
  if root then
    return root
  end

  if type(cfg.root_resolver) == "function" then
    root = cfg.root_resolver(bufnr or vim.api.nvim_get_current_buf(), cfg)
    if root and root ~= "" then
      return normalize(root)
    end
  end

  return normalize(marker_root(cfg.root_markers, start_path(bufnr)) or vim.loop.cwd())
end

local function resolve_path(value, root_dir)
  if type(value) == "function" then
    return value(root_dir)
  end
  if type(value) == "string" and value ~= "" then
    return value
  end
  return nil
end

local function module_from_path(root_dir, path)
  local pom = vim.fs.find("pom.xml", { path = path, upward = true })[1]
  if not pom then
    return nil
  end
  local module_dir = normalize(vim.fn.fnamemodify(pom, ":h"))
  root_dir = normalize(root_dir)
  if module_dir == "" or root_dir == "" or module_dir == root_dir then
    return nil
  end
  return {
    name = vim.fn.fnamemodify(module_dir, ":t"),
    dir = module_dir,
  }
end

---@param bufnr? integer
---@return table
function M.get(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local base_cfg = config.get()
  local root_dir = resolve_root(bufnr, base_cfg)
  local cfg = config.resolve(root_dir, bufnr)
  root_dir = resolve_root(bufnr, cfg)

  local module = module_from_path(root_dir, start_path(bufnr))

  return {
    root_dir = root_dir,
    java_home = cfg.jdtls_java_home ~= "" and cfg.jdtls_java_home or nil,
    java_runtimes = cfg.java_runtimes,
    maven_user_settings = resolve_path(cfg.maven_user_settings, root_dir),
    maven_lifecycle_mappings = resolve_path(cfg.maven_lifecycle_mappings, root_dir),
    maven_module = module and module.name or nil,
    maven_module_dir = module and module.dir or nil,
    config = cfg,
  }
end

return M
