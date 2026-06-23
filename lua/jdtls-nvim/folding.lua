--- LSP folding for Java buffers attached to jdtls.
---
--- Sets foldexpr buffer-locally (vim.wo[win][0]) so only Java windows
--- use LSP folding. Other buffers fall back to the global foldexpr
--- (treesitter) set by the user's config — no dispatcher needed.
local M = {}

local config = require("jdtls-nvim.config")

function M.setup() end

function M.enable(bufnr, client)
  if not config.get().lsp_folding then
    return
  end
  if vim.bo[bufnr].filetype ~= "java" or vim.bo[bufnr].buftype ~= "" then
    return
  end
  if not client:supports_method("textDocument/foldingRange", bufnr) then
    return
  end

  vim.lsp._capability.enable("folding_range", true, { client_id = client.id })

  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
      vim.wo[winid][0].foldmethod = "expr"
      vim.wo[winid][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
      vim._foldupdate(winid, 0, vim.api.nvim_buf_line_count(bufnr))
    end
    if vim.api.nvim_get_current_buf() == bufnr then
      pcall(vim.cmd, "normal! zx")
    end
  end)
end

return M
