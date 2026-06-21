--- Buffer-local keymaps for Java buffers.
local M = {}

--- Attach keymaps to a Java buffer.
---@param bufnr integer
---@param prefix string Keymap prefix (e.g., "<leader>J")
---@param workspace_dir? string JDTLS workspace directory (for clean command)
function M.attach(bufnr, prefix, workspace_dir)
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
  end

  local ok_jdtls, jdtls = pcall(require, "jdtls")
  if not ok_jdtls then return end

  -- Refactoring
  map(prefix .. "I", function()
    vim.lsp.buf.code_action({
      filter = function(a)
        return (a.title or ""):lower():find("invert") ~= nil
      end,
      apply = true,
    })
  end, "Java: Invert condition")

  -- Tools submenu
  map(prefix .. "ti", jdtls.organize_imports, "JDTLS: Organize imports")
  map(prefix .. "tv", jdtls.extract_variable, "JDTLS: Extract variable")
  map(prefix .. "tm", jdtls.extract_method, "JDTLS: Extract method")
  map(prefix .. "tu", "<Cmd>JdtUpdateConfig<CR>", "JDTLS: Update config")

  -- Clean workspace
  if workspace_dir then
    map(prefix .. "tw", function()
      vim.fn.delete(workspace_dir, "rf")
      vim.notify("Cleaned JDTLS workspace — restart Neovim to re-index", vim.log.levels.INFO)
    end, "JDTLS: Clean workspace")
  end
end

return M
