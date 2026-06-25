local function with_context(ctx)
  package.loaded["jdtls-nvim.maven"] = nil
  package.loaded["jdtls-nvim.context"] = {
    get = function()
      return ctx
    end,
  }
  return require("jdtls-nvim.maven")
end

describe("jdtls-nvim.maven", function()
  local tmp

  before_each(function()
    tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
  end)

  after_each(function()
    if tmp then
      vim.fn.delete(tmp, "rf")
    end
    package.loaded["jdtls-nvim.maven"] = nil
    package.loaded["jdtls-nvim.context"] = nil
  end)

  it("builds debug-ready test method command by default", function()
    local module_dir = tmp .. "/backoffice-api"
    vim.fn.mkdir(module_dir, "p")
    vim.fn.writefile({
      "<project>",
      "  <artifactId>backoffice-api</artifactId>",
      "</project>",
    }, module_dir .. "/pom.xml")

    local maven = with_context({
      root_dir = tmp,
      java_home = "/jdk/21",
      maven_user_settings = tmp .. "/settings.xml",
      maven_module = "backoffice-api",
      maven_module_dir = module_dir,
    })

    local command = maven.test_method("MyTest", "works", { bufnr = 0 })

    assert.truthy(command:find("JAVA_HOME=", 1, true))
    assert.truthy(command:find("-Dtest=", 1, true))
    assert.truthy(command:find("MyTest#works", 1, true))
    assert.truthy(command:find("-Dmaven.surefire.debug=", 1, true))
    assert.truthy(command:find("suspend=n", 1, true))
    assert.truthy(command:find("address=*:5005", 1, true))
    assert.truthy(command:find("retrying without debug", 1, true))
    assert.truthy(command:find("-pl", 1, true))
    assert.truthy(command:find(":backoffice-api", 1, true))
    assert.truthy(command:find("-am", 1, true))
  end)

  it("supports suspend debug mode", function()
    local maven = with_context({ root_dir = tmp })
    local command = maven.test_class("MyTest", { bufnr = 0, debug_suspend = true })
    assert.truthy(command:find("suspend=y", 1, true))
  end)

  it("supports custom debug port", function()
    local maven = with_context({ root_dir = tmp })
    local command = maven.test_class("MyTest", { bufnr = 0, debug_port = 5010 })
    assert.truthy(command:find("address=*:5010", 1, true))
  end)

  it("uses Java 8 debug address format", function()
    local maven = with_context({
      root_dir = tmp,
      java_runtimes = {
        { name = "JavaSE-1.8", path = "/jdk/8", default = true },
      },
    })
    local command = maven.test_class("MyTest", { bufnr = 0 })
    assert.truthy(command:find("address=5005", 1, true))
    assert.is_nil(command:find("address=*:5005", 1, true))
  end)

  it("can disable debug flag", function()
    local maven = with_context({ root_dir = tmp })
    local command = maven.test_class("MyTest", { bufnr = 0, debug = false })
    assert.is_nil(command:find("-Dmaven.surefire.debug=", 1, true))
    assert.is_nil(command:find("retrying without debug", 1, true))
  end)

  it("does not add user settings when .mvn/maven.config exists", function()
    vim.fn.mkdir(tmp .. "/.mvn", "p")
    vim.fn.writefile({ "-s settings.xml" }, tmp .. "/.mvn/maven.config")

    local maven = with_context({
      root_dir = tmp,
      maven_user_settings = tmp .. "/settings.xml",
    })
    local command = maven.test_class("MyTest", { bufnr = 0 })
    assert.is_nil(command:find("-s ", 1, true))
  end)

  it("uses maven.test.skip for compile commands only when requested", function()
    local maven = with_context({ root_dir = tmp })
    local command = maven.compile({ bufnr = 0 })
    assert.truthy(command:find("mvn compile", 1, true))
    assert.truthy(command:find("-Dmaven.test.skip=true", 1, true))
  end)
end)
