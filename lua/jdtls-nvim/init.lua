--- jdtls.nvim: opinionated JDTLS configuration for Neovim.
--- Provides a single `setup()` + `attach()` API for full Java development.
local M = {}

local config = require("jdtls-nvim.config")

--- Configure jdtls.nvim with user options.
--- Must be called before any `attach()` (typically in plugin config).
---@param opts? jdtls_nvim.UserConfig
function M.setup(opts)
  config.setup(opts)
  if vim.g._jdtls_nvim_attach_autocmd then
    return
  end
  vim.g._jdtls_nvim_attach_autocmd = true
  vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
    group = vim.api.nvim_create_augroup("JdtlsNvimAttach", { clear = true }),
    pattern = "java",
    callback = function()
      M.attach()
    end,
  })
end

local attaching = {}

-- Clear the per-buffer start flag when jdtls detaches (crash, :LspStop, etc.)
-- so that the next FileType/ftplugin trigger can reconnect.
vim.api.nvim_create_autocmd("LspDetach", {
  group = vim.api.nvim_create_augroup("JdtlsNvimDetach", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client.name == "jdtls" then
      vim.b[ev.buf].jdtls_nvim_attach_started = nil
    end
  end,
})

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
  local ok, started = pcall(function()
    return require("jdtls-nvim.server").start()
  end)
  attaching[bufnr] = nil

  if not ok then
    vim.notify("[jdtls.nvim] attach failed: " .. tostring(started), vim.log.levels.ERROR)
    return
  end
  if started then
    vim.b[bufnr].jdtls_nvim_attach_started = true
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

--- Resolve Java context for the current buffer/project.
---@param bufnr? integer
---@return table
function M.context(bufnr)
  return require("jdtls-nvim.context").get(bufnr)
end

--- Get the Maven command builder module.
---@return table
function M.maven()
  return require("jdtls-nvim.maven")
end

--- Get the DAP recovery module (request_with_recovery, normalize_error, is_java_error).
---@return table
function M.dap_recovery()
  return require("jdtls-nvim.dap_recovery")
end

return M
