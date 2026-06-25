local server = require("jdtls-nvim.server")

describe("jdtls-nvim.server", function()
  describe("build_cmd", function()
    it("starts with jdtls executable", function()
      local cmd = server.build_cmd("/tmp/ws", "", {})
      assert.equals("jdtls", cmd[1])
    end)

    it("uses jdtls fallback when custom java is incomplete", function()
      local cmd = server.build_cmd("/tmp/ws", "", {}, false, "WARN", "/jdk/bin/java", "", "/config")
      assert.equals("jdtls", cmd[1])
    end)

    it("uses custom java launcher when fully configured", function()
      local cmd = server.build_cmd(
        "/tmp/ws",
        "",
        { "-Xmx2G" },
        false,
        "WARN",
        "/jdk/bin/java",
        "/jdtls/launcher.jar",
        "/jdtls/config_mac"
      )
      assert.equals("/jdk/bin/java", cmd[1])
      assert.truthy(vim.tbl_contains(cmd, "-jar"))
      assert.truthy(vim.tbl_contains(cmd, "/jdtls/launcher.jar"))
      assert.truthy(vim.tbl_contains(cmd, "-configuration"))
      assert.truthy(vim.tbl_contains(cmd, "/jdtls/config_mac"))
      assert.truthy(vim.tbl_contains(cmd, "-Xmx2G"))
      assert.truthy(vim.tbl_contains(cmd, "-Dlog.protocol=false"))
      assert.truthy(vim.tbl_contains(cmd, "-Dlog.level=WARN"))
    end)

    it("allows verbose JDTLS logging when configured", function()
      local cmd = server.build_cmd(
        "/tmp/ws",
        "",
        {},
        true,
        "ALL",
        "/jdk/bin/java",
        "/jdtls/launcher.jar",
        "/jdtls/config_mac"
      )
      assert.truthy(vim.tbl_contains(cmd, "-Dlog.protocol=true"))
      assert.truthy(vim.tbl_contains(cmd, "-Dlog.level=ALL"))
    end)

    it("includes workspace data dir at end", function()
      local cmd = server.build_cmd("/tmp/ws", "", { "-Xmx2G" })
      assert.equals("-data", cmd[#cmd - 1])
      assert.equals("/tmp/ws", cmd[#cmd])
    end)

    it("includes JVM args", function()
      local cmd = server.build_cmd("/tmp/ws", "", { "-Xmx2G", "-XX:+UseG1GC" })
      assert.truthy(vim.tbl_contains(cmd, "-Xmx2G"))
      assert.truthy(vim.tbl_contains(cmd, "-XX:+UseG1GC"))
    end)

    it("inserts lombok agent at position 2 when jar exists", function()
      -- Create a temporary file to simulate lombok jar
      local tmp = vim.fn.tempname()
      vim.fn.writefile({""}, tmp)

      local cmd = server.build_cmd("/tmp/ws", tmp, {})
      assert.truthy(cmd[2]:find("javaagent"))
      assert.truthy(cmd[2]:find(tmp, 1, true))

      vim.fn.delete(tmp)
    end)

    it("skips lombok agent when jar is empty string", function()
      local cmd = server.build_cmd("/tmp/ws", "", { "-Xmx1G" })
      for _, arg in ipairs(cmd) do
        assert.falsy(arg:find("javaagent"))
      end
    end)

    it("adds lombok as raw javaagent for custom java launcher", function()
      local tmp = vim.fn.tempname()
      vim.fn.writefile({""}, tmp)

      local cmd = server.build_cmd("/tmp/ws", tmp, {}, false, "WARN", "/jdk/bin/java", "/jdtls/launcher.jar", "/jdtls/config_mac")
      assert.truthy(vim.tbl_contains(cmd, "-javaagent:" .. tmp))

      vim.fn.delete(tmp)
    end)
  end)

  describe("dap_bundles", function()
    it("returns empty table for nonexistent mason base", function()
      local bundles = server.dap_bundles("/nonexistent/path/")
      assert.same({}, bundles)
    end)
  end)
end)
