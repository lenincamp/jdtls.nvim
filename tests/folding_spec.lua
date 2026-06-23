local folding = require("jdtls-nvim.folding")

describe("jdtls-nvim.folding", function()
  local orig_get_clients
  local orig_capability_enable

  before_each(function()
    vim.o.foldmethod = "expr"
    vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    folding.setup()
    orig_get_clients = vim.lsp.get_clients
    orig_capability_enable = vim.lsp._capability.enable
    vim.lsp._capability.enable = function() end
  end)

  after_each(function()
    vim.lsp.get_clients = orig_get_clients
    vim.lsp._capability.enable = orig_capability_enable
  end)

  it("setup() is a no-op", function()
    assert.equals("v:lua.vim.treesitter.foldexpr()", vim.o.foldexpr)
  end)

  it("enable() skips non-java buffers", function()
    vim.cmd("noautocmd enew")
    vim.cmd("noautocmd setlocal filetype=typescript")
    local called = false
    vim.lsp._capability.enable = function() called = true end
    folding.enable(0, { supports_method = function() return true end })
    assert.is_false(called)
  end)

  it("enable() skips if client does not support foldingRange", function()
    vim.cmd("noautocmd enew")
    vim.cmd("noautocmd setlocal filetype=java")
    local called = false
    vim.lsp._capability.enable = function() called = true end
    folding.enable(0, { supports_method = function() return false end })
    assert.is_false(called)
  end)

  it("enable() enables folding_range capability for java", function()
    vim.cmd("noautocmd enew")
    vim.cmd("noautocmd setlocal filetype=java buftype=")
    local enabled = false
    vim.lsp._capability.enable = function(name, val)
      if name == "folding_range" and val == true then enabled = true end
    end
    folding.enable(0, { id = 1, supports_method = function() return true end })
    assert.is_true(enabled)
  end)

  it("global foldexpr is untouched after enable()", function()
    vim.cmd("noautocmd enew")
    vim.cmd("noautocmd setlocal filetype=java buftype=")
    folding.enable(0, { id = 1, supports_method = function() return true end })
    assert.equals("v:lua.vim.treesitter.foldexpr()", vim.o.foldexpr)
  end)
end)
