--- Java DAP profile configurations for nvim-dap.
--- Provides attach/launch configurations used by dap.configurations.java.
local M = {}

local config = require("jdtls-nvim.config")
local paths = require("jdtls-nvim.paths")
local project = require("jdtls-nvim.project")

local function buffer_path(bufnr)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name ~= "" then return name end
  end
  return nil
end

local function project_root(bufnr)
  local start = buffer_path(bufnr) or vim.fn.getcwd()
  return vim.fs.root(start, { "mvnw", "gradlew", "pom.xml", "build.gradle", ".git" }) or vim.fn.getcwd()
end

local function java_source_paths(bufnr)
  local root = project_root(bufnr)
  local result = {}
  for _, path in ipairs({
    root .. "/src/main/java",
    root .. "/src/test/java",
  }) do
    if vim.fn.isdirectory(path) == 1 then
      result[#result + 1] = path
    end
  end
  return result
end

local function java_step_filters()
  return {
    skipClasses = {},
    skipSynthetics = false,
    skipConstructors = false,
    skipStaticInitializers = false,
  }
end

local function java_executable()
  local configured = paths.java_exec_from_home(config.get().jdtls_java_home)
  if configured ~= "" then
    return configured
  end

  local java = vim.fn.exepath("java")
  return java ~= "" and java or "java"
end

local function java_attach_config(config)
  config.mainClass = ""
  config.modulePaths = {}
  config.classPaths = {}
  config.javaExec = java_executable()
  return config
end

--- Build Java DAP configurations.
---@param bufnr? number Buffer to resolve project context from
---@return table[] configurations
function M.configurations(bufnr)
  local project_name = project.module_name(buffer_path(bufnr))
  local source_paths = java_source_paths(bufnr)
  local step_filters = java_step_filters()

  return {
    java_attach_config({
      type = "java",
      request = "attach",
      name = "Debug (Attach) — Remote 51922",
      hostName = "127.0.0.1",
      port = 51922,
      projectName = project_name,
      sourcePaths = source_paths,
      stepFilters = step_filters,
    }),
    {
      type = "java",
      name = "Current File",
      request = "launch",
      mainClass = "${file}",
      projectName = project_name,
      shortenCommandLine = "argfile",
    },
    java_attach_config({
      type = "java",
      request = "attach",
      name = "Remote Attach 5005",
      hostName = "localhost",
      port = 5005,
      projectName = project_name,
      sourcePaths = source_paths,
      stepFilters = step_filters,
    }),
    java_attach_config({
      type = "java",
      name = "Debug Maven Tests",
      request = "attach",
      hostName = "127.0.0.1",
      port = 5005,
      projectName = project_name,
      sourcePaths = source_paths,
      stepFilters = step_filters,
    }),
  }
end

--- Resolve project name for a DAP session (used by error-recovery hooks).
---@param path_hint? string
---@return string|nil
function M.project_name(path_hint)
  return project.name(path_hint)
end

return M
