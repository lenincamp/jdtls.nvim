local config = require("jdtls-nvim.config")

describe("jdtls-nvim.config", function()
  before_each(function()
    -- Reset to defaults before each test
    config.setup({})
  end)

  it("returns defaults when no opts provided", function()
    local cfg = config.get()
    assert.equals(true, cfg.lombok)
    assert.equals(true, cfg.keymaps)
    assert.equals(false, cfg.semantic_tokens)
    assert.equals(false, cfg.inlay_hints)
    assert.equals(true, cfg.organize_imports_on_save)
    assert.equals(true, cfg.treesitter_indent)
    assert.equals("<leader>J", cfg.keymap_prefix)
    assert.equals("", cfg.jdtls_java_home)
    assert.equals(false, cfg.jdtls_log_protocol)
    assert.equals("WARN", cfg.jdtls_log_level)
    assert.equals("maven", cfg.test.runner)
    assert.equals(true, cfg.dap.enabled)
    assert.equals("auto", cfg.dap.hotcodereplace)
    assert.equals(false, cfg.jenv.enabled)
    assert.equals(true, cfg.jenv.use_java_home)
    assert.equals("active", cfg.jenv.runtimes)
    assert.equals(true, cfg.maven.debug)
    assert.equals(5005, cfg.maven.debug_port)
    assert.equals(false, cfg.maven.debug_suspend)
    assert.equals(true, cfg.maven.retry_without_debug_on_port_busy)
  end)

  it("merges user opts with defaults", function()
    config.setup({
      lombok = "/custom/lombok.jar",
      jdtls_java_home = "/opt/jdk-21",
      semantic_tokens = true,
      jvm_args = { "-Xmx4G" },
      dap = { hotcodereplace = "manual" },
    })

    local cfg = config.get()
    assert.equals("/custom/lombok.jar", cfg.lombok)
    assert.equals("/opt/jdk-21", cfg.jdtls_java_home)
    assert.equals(true, cfg.semantic_tokens)
    assert.same({ "-Xmx4G" }, cfg.jvm_args)
    assert.equals("manual", cfg.dap.hotcodereplace)
    -- Preserved defaults
    assert.equals(true, cfg.dap.enabled)
    assert.equals(true, cfg.keymaps)
  end)

  it("does not mutate defaults when user changes config", function()
    config.setup({ keymaps = false })
    local cfg = config.get()
    assert.equals(false, cfg.keymaps)

    local defs = config.defaults()
    assert.equals(true, defs.keymaps)
  end)

  it("provides root_markers with sane defaults", function()
    local cfg = config.get()
    assert.truthy(vim.tbl_contains(cfg.root_markers, ".git"))
    assert.truthy(vim.tbl_contains(cfg.root_markers, "gradlew"))
    assert.truthy(vim.tbl_contains(cfg.root_markers, "pom.xml"))
  end)

  it("accepts root_resolver as a function", function()
    local resolver = function()
      return "/tmp/project"
    end
    config.setup({ root_resolver = resolver })
    local cfg = config.get()
    assert.equals(resolver, cfg.root_resolver)
  end)

  it("accepts project_overrides as a function", function()
    local overrides = function()
      return { update_build_configuration = "automatic" }
    end
    config.setup({ project_overrides = overrides })
    local cfg = config.get()
    assert.equals(overrides, cfg.project_overrides)
  end)

  it("resolves project overrides without mutating base config", function()
    config.setup({
      update_build_configuration = "interactive",
      project_overrides = function()
        return { update_build_configuration = "automatic" }
      end,
    })
    assert.equals("interactive", config.get().update_build_configuration)
    assert.equals("automatic", config.resolve("/tmp/project").update_build_configuration)
  end)

  it("accepts on_attach as a function", function()
    local called = false
    config.setup({ on_attach = function() called = true end })
    local cfg = config.get()
    assert.is_function(cfg.on_attach)
    cfg.on_attach({}, 0)
    assert.is_true(called)
  end)

  it("accepts explicit jenv runtime majors", function()
    config.setup({ jenv = { enabled = true, runtimes = { 17, 21 } } })
    local cfg = config.get()
    assert.same({ 17, 21 }, cfg.jenv.runtimes)
  end)
end)
