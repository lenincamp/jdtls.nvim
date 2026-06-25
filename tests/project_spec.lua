local function fresh()
  package.loaded["jdtls-nvim.project"] = nil
  return require("jdtls-nvim.project")
end

describe("jdtls-nvim.project.module_name", function()
  local tmp

  before_each(function()
    tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
  end)

  after_each(function()
    if tmp then
      vim.fn.delete(tmp, "rf")
    end
    package.loaded["jdtls-nvim.project"] = nil
  end)

  local function write_pom(dir, lines)
    vim.fn.mkdir(dir, "p")
    vim.fn.writefile(lines, dir .. "/pom.xml")
  end

  it("resolves module artifactId, ignoring <parent>", function()
    local mod = tmp .. "/api"
    write_pom(mod, {
      "<project>",
      "  <parent><artifactId>cdp</artifactId></parent>",
      "  <artifactId>api</artifactId>",
      "  <dependencies>",
      "    <dependency><artifactId>junit</artifactId></dependency>",
      "  </dependencies>",
      "</project>",
    })
    assert.equals("api", fresh().module_name(mod .. "/Foo.java"))
  end)

  it("does not match a dependency artifactId", function()
    local mod = tmp .. "/svc"
    write_pom(mod, {
      "<project>",
      "  <artifactId>svc</artifactId>",
      "  <dependencies>",
      "    <dependency><artifactId>guava</artifactId></dependency>",
      "  </dependencies>",
      "</project>",
    })
    assert.equals("svc", fresh().module_name(mod .. "/Foo.java"))
  end)

  it("resolves aggregator pom without matching <modules>", function()
    write_pom(tmp, {
      "<project>",
      "  <artifactId>root</artifactId>",
      "  <modules>",
      "    <module>api</module>",
      "  </modules>",
      "</project>",
    })
    assert.equals("root", fresh().module_name(tmp .. "/pom.xml"))
  end)

  it("picks the nearest (deepest) module pom", function()
    write_pom(tmp, { "<project><artifactId>root</artifactId></project>" })
    local mod = tmp .. "/api"
    write_pom(mod, { "<project><artifactId>api</artifactId></project>" })
    assert.equals("api", fresh().module_name(mod .. "/src/Foo.java"))
  end)

  it("falls back to dir basename when pom has no artifactId", function()
    local mod = tmp .. "/weird"
    write_pom(mod, { "<project></project>" })
    assert.equals("weird", fresh().module_name(mod .. "/Foo.java"))
  end)
end)
