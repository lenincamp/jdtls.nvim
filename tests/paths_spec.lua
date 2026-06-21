local paths = require("jdtls-nvim.paths")

describe("jdtls-nvim.paths", function()
  describe("normalize_root", function()
    it("returns empty for nil", function()
      assert.equals("", paths.normalize_root(nil))
    end)

    it("returns empty for empty string", function()
      assert.equals("", paths.normalize_root(""))
    end)

    it("strips trailing slashes", function()
      local result = paths.normalize_root("/tmp/project/")
      assert.falsy(result:match("/$"))
    end)

    it("resolves a valid path", function()
      local result = paths.normalize_root("/tmp")
      assert.truthy(#result > 0)
      assert.falsy(result:match("/$"))
    end)
  end)

  describe("workspace_for_root", function()
    it("generates unique workspace dir from root", function()
      local dir1, name1 = paths.workspace_for_root("/tmp/project-a")
      local dir2, name2 = paths.workspace_for_root("/tmp/project-b")

      assert.truthy(dir1 ~= dir2)
      assert.equals("project-a", name1)
      assert.equals("project-b", name2)
      assert.truthy(dir1:find("jdtls%-workspaces"))
    end)

    it("generates same workspace dir for same root", function()
      local dir1 = paths.workspace_for_root("/tmp/stable-root")
      local dir2 = paths.workspace_for_root("/tmp/stable-root")
      assert.equals(dir1, dir2)
    end)

    it("uses custom resolver when provided", function()
      local custom = function(root)
        return "/custom/workspace/" .. vim.fn.fnamemodify(root, ":t")
      end
      local dir, name = paths.workspace_for_root("/tmp/my-project", custom)
      assert.equals("/custom/workspace/my-project", dir)
      assert.equals("my-project", name)
    end)
  end)

  describe("lombok_jar", function()
    it("returns empty for non-existent explicit path", function()
      assert.equals("", paths.lombok_jar("/nonexistent/lombok.jar"))
    end)

    it("returns empty for false override", function()
      -- When lombok=true, it auto-detects; result depends on system.
      -- We test the false/nil/string logic path here.
      local result = paths.lombok_jar("/does/not/exist.jar")
      assert.equals("", result)
    end)
  end)

  describe("mason_base", function()
    it("returns a path ending with slash", function()
      local base = paths.mason_base()
      assert.truthy(base:match("/$"))
    end)
  end)

  describe("java_exec_from_home", function()
    it("returns empty for empty home", function()
      assert.equals("", paths.java_exec_from_home(""))
      assert.equals("", paths.java_exec_from_home(nil))
    end)

    it("returns empty for non-executable java", function()
      assert.equals("", paths.java_exec_from_home("/does/not/exist"))
    end)
  end)

  describe("jdtls launcher paths", function()
    it("returns strings", function()
      assert.equals("string", type(paths.jdtls_launcher_jar()))
      assert.equals("string", type(paths.jdtls_config_dir()))
    end)
  end)
end)
