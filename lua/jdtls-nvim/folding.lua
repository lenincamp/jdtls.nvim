--- LSP folding integration for Java buffers attached to jdtls.
local M = {}

local LSP_FOLDEXPR = "v:lua.vim.lsp.foldexpr()"
local LSP_FOLDTEXT = "v:lua.vim.lsp.foldtext()"

local restore_setup = false

local function windows_for_buf(bufnr)
  local wins = {}
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    if vim.api.nvim_win_is_valid(win) then
      wins[#wins + 1] = win
    end
  end
  return wins
end

--- Remember window fold settings before switching to LSP folding.
---@param win integer
local function stash_window_fold_settings(win)
  if vim.w[win].jdtls_nvim_prev_foldexpr == nil then
    vim.w[win].jdtls_nvim_prev_foldexpr = vim.wo[win].foldexpr
  end
  if vim.w[win].jdtls_nvim_prev_foldtext == nil then
    vim.w[win].jdtls_nvim_prev_foldtext = vim.wo[win].foldtext
  end
end

--- Restore stashed fold settings for windows showing {bufnr}.
---@param bufnr integer
function M.restore(bufnr)
  for _, win in ipairs(windows_for_buf(bufnr)) do
    local prev_expr = vim.w[win].jdtls_nvim_prev_foldexpr
    local prev_text = vim.w[win].jdtls_nvim_prev_foldtext
    if prev_expr then
      vim.wo[win].foldexpr = prev_expr
      vim.w[win].jdtls_nvim_prev_foldexpr = nil
    end
    if prev_text then
      vim.wo[win].foldtext = prev_text
      vim.w[win].jdtls_nvim_prev_foldtext = nil
    end
  end
end

--- Enable LSP folding for windows showing {bufnr}.
---@param bufnr integer
---@param client vim.lsp.Client
function M.enable(bufnr, client)
  if not client:supports_method("textDocument/foldingRange", bufnr) then
    return
  end

  for _, win in ipairs(windows_for_buf(bufnr)) do
    stash_window_fold_settings(win)
    vim.wo[win].foldexpr = LSP_FOLDEXPR
    vim.wo[win].foldtext = LSP_FOLDTEXT
  end

  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    if vim.api.nvim_get_current_buf() ~= bufnr then
      return
    end
    pcall(vim.cmd, "normal! zx")
  end)
end

--- Register LspDetach restore hook once.
function M.setup_restore()
  if restore_setup then
    return
  end
  restore_setup = true

  vim.api.nvim_create_autocmd("LspDetach", {
    group = vim.api.nvim_create_augroup("jdtls_nvim_folding", { clear = true }),
    callback = function(args)
      if #vim.lsp.get_clients({ bufnr = args.buf, method = "textDocument/foldingRange" }) > 0 then
        return
      end
      M.restore(args.buf)
    end,
  })
end

return M
