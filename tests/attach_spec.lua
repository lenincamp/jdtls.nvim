local attach_calls = 0

package.preload["jdtls-nvim.server"] = function()
  return {
    start = function()
      attach_calls = attach_calls + 1
    end,
  }
end

describe("jdtls-nvim.attach guard", function()
  local saved_eventignore

  local function reset_jdtls_modules()
    attach_calls = 0
    for mod, _ in pairs(package.loaded) do
      if type(mod) == "string" and mod:match("^jdtls%-nvim") then
        package.loaded[mod] = nil
      end
    end
    package.preload["jdtls-nvim.server"] = function()
      return {
        start = function()
          attach_calls = attach_calls + 1
        end,
      }
    end
  end

  local function java_buffer(path)
    vim.cmd("noautocmd enew")
    vim.api.nvim_buf_set_name(0, path)
    vim.cmd("noautocmd setlocal filetype=java")
  end

  before_each(function()
    saved_eventignore = vim.o.eventignore
    vim.o.eventignore = "FileType"
    reset_jdtls_modules()
  end)

  after_each(function()
    vim.o.eventignore = saved_eventignore
  end)

  it("calls server.start only once when attach is invoked repeatedly", function()
    java_buffer("/tmp/JdtlsAttachGuardTest.java")

    local jdtls_nvim = require("jdtls-nvim")
    jdtls_nvim.attach()
    jdtls_nvim.attach()
    jdtls_nvim.attach()

    assert.equals(1, attach_calls)
  end)

  it("skips attach when jdtls client already exists on buffer", function()
    java_buffer("/tmp/JdtlsAttachGuardExisting.java")
    local bufnr = vim.api.nvim_get_current_buf()

    local fake_client = { name = "jdtls", id = 999001 }
    local orig_get_clients = vim.lsp.get_clients
    vim.lsp.get_clients = function(opts)
      if opts and opts.bufnr == bufnr and opts.name == "jdtls" then
        return { fake_client }
      end
      return orig_get_clients(opts)
    end

    local jdtls_nvim = require("jdtls-nvim")
    jdtls_nvim.attach()
    jdtls_nvim.attach()

    vim.lsp.get_clients = orig_get_clients
    assert.equals(0, attach_calls)
  end)
end)
