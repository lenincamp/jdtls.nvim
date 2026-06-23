--- jdtls.nvim: opinionated JDTLS configuration for Neovim.
--- Provides a single `setup()` + `attach()` API for full Java development.
local M = {}

local config = require("jdtls-nvim.config")

--- Configure jdtls.nvim with user options.
--- Must be called before any `attach()` (typically in plugin config).
---@param opts? jdtls_nvim.UserConfig
function M.setup(opts)
  config.setup(opts)
end

local attaching = {}

--- Attach JDTLS to the current Java buffer.
--- Called automatically from ftplugin/java.lua or manually.
function M.attach()
  -- Guard: skip non-file buffers, diff mode, unnamed buffers
  if vim.wo.diff then return end
  if vim.bo.buftype ~= "" then return end
  if vim.api.nvim_buf_get_name(0) == "" then return end

  local bufnr = vim.api.nvim_get_current_buf()
  if attaching[bufnr] or vim.b[bufnr].jdtls_nvim_attach_started then
    return
  end
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = "jdtls" })) do
    if client.name == "jdtls" then
      return
    end
  end

  attaching[bufnr] = true
  vim.b[bufnr].jdtls_nvim_attach_started = true
  local ok, err = pcall(function()
    require("jdtls-nvim.server").start()
  end)
  attaching[bufnr] = nil

  if not ok then
    vim.notify("[jdtls.nvim] attach failed: " .. tostring(err), vim.log.levels.ERROR)
  end
end

--- Get resolved config (read-only).
---@return jdtls_nvim.Config
function M.get_config()
  return config.get()
end

--- Get Java DAP configurations for nvim-dap.
---@param bufnr? number
---@return table[]
function M.dap_configurations(bufnr)
  return require("jdtls-nvim.dap_profiles").configurations(bufnr)
end

--- Resolve Java project name (for DAP session projectName).
---@param path_hint? string
---@return string|nil
function M.project_name(path_hint)
  return require("jdtls-nvim.project").name(path_hint)
end

--- Get the DAP recovery module (request_with_recovery, normalize_error, is_java_error).
---@return table
function M.dap_recovery()
  return require("jdtls-nvim.dap_recovery")
end

return M
