local folding = require("jdtls-nvim.folding")

describe("jdtls-nvim.folding", function()
  local saved_foldexpr
  local saved_foldtext

  before_each(function()
    saved_foldexpr = vim.o.foldexpr
    saved_foldtext = vim.o.foldtext
    vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    vim.o.foldtext = "v:lua.FoldText()"
  end)

  after_each(function()
    vim.o.foldexpr = saved_foldexpr
    vim.o.foldtext = saved_foldtext
  end)

  it("enables LSP foldexpr for windows showing the buffer", function()
    vim.cmd("noautocmd enew")
    local bufnr = vim.api.nvim_get_current_buf()
    vim.cmd("noautocmd setlocal filetype=java")

    local client = {
      supports_method = function(_, method)
        return method == "textDocument/foldingRange"
      end,
    }

    folding.enable(bufnr, client)

    assert.equals("v:lua.vim.lsp.foldexpr()", vim.wo[0].foldexpr)
    assert.equals("v:lua.vim.lsp.foldtext()", vim.wo[0].foldtext)
  end)

  it("skips enable when foldingRange is unsupported", function()
    vim.cmd("noautocmd enew")
    local bufnr = vim.api.nvim_get_current_buf()

    folding.enable(bufnr, {
      supports_method = function()
        return false
      end,
    })

    assert.equals("v:lua.vim.treesitter.foldexpr()", vim.wo[0].foldexpr)
  end)

  it("restores previous fold settings on detach", function()
    vim.cmd("noautocmd enew")
    local bufnr = vim.api.nvim_get_current_buf()

    folding.enable(bufnr, {
      supports_method = function(_, method)
        return method == "textDocument/foldingRange"
      end,
    })
    folding.restore(bufnr)

    assert.equals("v:lua.vim.treesitter.foldexpr()", vim.wo[0].foldexpr)
    assert.equals("v:lua.FoldText()", vim.wo[0].foldtext)
  end)
end)
