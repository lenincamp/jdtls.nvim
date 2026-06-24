--- Path resolution: Mason, Lombok, workspace dirs, JDK runtimes.
local M = {}

local home = os.getenv("HOME") or ""

--- Resolve Mason packages base directory.
---@return string
function M.mason_base()
  local own = vim.fn.stdpath("data") .. "/mason/packages/"
  local main = home .. "/.local/share/nvim/mason/packages/"
  return vim.fn.isdirectory(own .. "java-debug-adapter") == 1 and own or main
end

--- Derive the Java executable from a JDK home.
---@param java_home string|nil
---@return string
function M.java_exec_from_home(java_home)
  if type(java_home) ~= "string" or java_home == "" then
    return ""
  end
  local java = java_home:gsub("/+$", "") .. "/bin/java"
  return vim.fn.executable(java) == 1 and java or ""
end

--- Resolve the Eclipse launcher JAR from Mason's JDTLS package.
---@return string
function M.jdtls_launcher_jar()
  local candidates = vim.fn.glob(M.mason_base() .. "jdtls/plugins/org.eclipse.equinox.launcher_*.jar", false, true)
  table.sort(candidates)
  return candidates[#candidates] or ""
end

--- Resolve the platform-specific JDTLS configuration directory.
---@return string
function M.jdtls_config_dir()
  local uname = (vim.uv or vim.loop).os_uname()
  local sysname = uname.sysname
  local machine = uname.machine or ""
  local suffix
  if sysname == "Darwin" then
    suffix = (machine == "arm64" or machine == "aarch64") and "mac_arm" or "mac"
  elseif sysname == "Windows_NT" then
    suffix = "win"
  else
    suffix = (machine == "aarch64") and "linux_arm" or "linux"
  end
  local dir = M.mason_base() .. "jdtls/config_" .. suffix
  -- Fallback to non-arm variant if arm-specific dir is missing
  if vim.fn.isdirectory(dir) ~= 1 and suffix == "mac_arm" then
    dir = M.mason_base() .. "jdtls/config_mac"
  elseif vim.fn.isdirectory(dir) ~= 1 and suffix == "linux_arm" then
    dir = M.mason_base() .. "jdtls/config_linux"
  end
  return vim.fn.isdirectory(dir) == 1 and dir or ""
end

--- Resolve Lombok JAR path.
--- Checks Mason jdtls package first, then ~/.m2 repository.
---@param override? string|boolean User-provided path or true for auto-detect
---@return string path Empty string if not found
function M.lombok_jar(override)
  if type(override) == "string" and override ~= "" then
    return vim.fn.filereadable(override) == 1 and override or ""
  end

  -- Mason bundled lombok
  local mason_jar = home .. "/.local/share/nvim/mason/packages/jdtls/lombok.jar"
  if vim.fn.filereadable(mason_jar) == 1 then
    return mason_jar
  end

  -- Maven local repository (pick latest version)
  local candidates = vim.fn.glob(home .. "/.m2/repository/org/projectlombok/lombok/*/lombok-*.jar", false, true)
  return (#candidates > 0) and candidates[#candidates] or ""
end

--- Normalize a root directory path (resolve symlinks, trailing slashes).
---@param root string|nil
---@return string
function M.normalize_root(root)
  if type(root) ~= "string" or root == "" then return "" end
  local resolved = vim.fn.resolve(root)
  return resolved:gsub("/+$", "")
end

--- Compute workspace directory for a given project root.
--- JDTLS needs a unique workspace per project.
---@param root_dir string
---@param custom_resolver? fun(root_dir: string): string
---@return string workspace_dir
---@return string project_name
function M.workspace_for_root(root_dir, custom_resolver)
  if custom_resolver then
    local dir = custom_resolver(root_dir)
    local name = vim.fn.fnamemodify(root_dir, ":t")
    vim.fn.mkdir(dir, "p")
    return dir, name
  end

  root_dir = M.normalize_root(root_dir)
  local project_name = vim.fn.fnamemodify(root_dir, ":t")
  local workspace_id = project_name
  if root_dir ~= "" then
    workspace_id = workspace_id .. "-" .. vim.fn.sha256(root_dir):sub(1, 12)
  end

  local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspaces/" .. workspace_id
  vim.fn.mkdir(workspace_dir, "p")

  return workspace_dir, project_name
end

return M
