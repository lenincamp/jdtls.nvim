local config = require("jdtls-nvim.config")
local settings = require("jdtls-nvim.settings")

describe("jdtls-nvim.settings", function()
  before_each(function()
    config.setup({})
  end)

  it("returns nested java table", function()
    local s = settings.build(config.get())
    assert.is_table(s.java)
    assert.is_table(s.java.completion)
    assert.is_table(s.java.format)
    assert.is_table(s.java.codeGeneration)
  end)

  it("sets organize imports based on config", function()
    config.setup({ organize_imports_on_save = false })
    local s = settings.build(config.get())
    assert.equals(false, s.java.saveActions.organizeImports)
  end)

  it("includes style file when provided", function()
    config.setup({ style_file = "/path/to/style.xml" })
    local s = settings.build(config.get())
    assert.equals("/path/to/style.xml", s.java.format.settings.url)
  end)

  it("omits style file when empty", function()
    config.setup({ style_file = "" })
    local s = settings.build(config.get())
    assert.is_nil(s.java.format.settings.url)
    assert.is_nil(s.java.format.settings.profile)
  end)

  it("passes maven userSettings when configured", function()
    config.setup({
      maven_user_settings = function(root_dir)
        return root_dir .. "/ci-settings-tech-proyecto.xml"
      end,
    })
    local s = settings.build(config.get(), "/tmp/ar-patagonia-cdp")
    assert.equals("/tmp/ar-patagonia-cdp/ci-settings-tech-proyecto.xml", s.java.configuration.maven.userSettings)
  end)

  it("passes maven lifecycleMappings when configured", function()
    config.setup({
      maven_lifecycle_mappings = function(root_dir)
        return root_dir .. "/.mvn/m2e-lifecycle.xml"
      end,
    })
    local s = settings.build(config.get(), "/tmp/project")
    assert.equals("/tmp/project/.mvn/m2e-lifecycle.xml", s.java.configuration.maven.lifecycleMappings)
  end)

  it("passes updateBuildConfiguration and nullAnalysis from config", function()
    config.setup({
      update_build_configuration = "automatic",
      null_analysis_mode = "disabled",
    })
    local s = settings.build(config.get(), "/tmp/project")
    assert.equals("automatic", s.java.configuration.updateBuildConfiguration)
    assert.equals("disabled", s.java.compile.nullAnalysis.mode)
  end)

  it("passes java_runtimes to configuration.runtimes", function()
    local runtimes = {
      { name = "JavaSE-17", path = "/opt/jdk-17" },
      { name = "JavaSE-21", path = "/opt/jdk-21", default = true },
    }
    config.setup({ java_runtimes = runtimes })
    local s = settings.build(config.get())
    assert.same(runtimes, s.java.configuration.runtimes)
  end)

  it("has sane default import exclusions", function()
    local s = settings.build(config.get())
    assert.truthy(vim.tbl_contains(s.java.import.exclusions, "**/node_modules/**"))
    assert.truthy(vim.tbl_contains(s.java.import.exclusions, "**/target/**"))
  end)

  it("has sane default completion config", function()
    local s = settings.build(config.get())
    assert.equals(true, s.java.completion.enabled)
    assert.equals(false, s.java.completion.guessMethodArguments)
    assert.equals(9999, s.java.sources.organizeImports.starThreshold)
  end)
end)
