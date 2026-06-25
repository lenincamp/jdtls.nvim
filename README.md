# jdtls.nvim

Opinionated JDTLS configuration for Neovim. Wraps [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) with sensible defaults, automatic Lombok/DAP setup, and a minimal `setup()` + `attach()` API.

## Features

- **Zero-config start** — auto-detects project root, Lombok, Mason DAP bundles
- **DAP integration** — 4 built-in debug configurations + error recovery (auto-retry on `projectName` resolution)
- **Buffer keymaps** — organize imports, extract variable/method, invert condition, clean workspace
- **Feature toggles** — semantic tokens, inlay hints, treesitter indent, organize-imports-on-save
- **Project name resolution** — from JDTLS roots, `vim.g`, or filesystem markers
- **jenv integration** — optional JDK discovery from `JAVA_HOME` and `jenv versions`
- **Project-specific overrides** — custom root resolver, Maven settings, and per-root options without forking plugin defaults
- **Context API** — expose resolved root, Java home, Maven settings, and module for task runners
- **Workspace management** — deterministic workspace dirs with project-name scoping

## Requirements

- Neovim ≥ 0.10
- [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) — JDTLS client
- [jdtls](https://github.com/eclipse-jdtls/eclipse.jdt.ls) — installed via Mason or manually
- (Optional) [java-debug-adapter](https://github.com/microsoft/java-debug) + [java-test](https://github.com/microsoft/vscode-java-test) — via Mason for DAP

## Installation

### lazy.nvim

```lua
{
  "lcampoverde/jdtls.nvim",
  ft = "java",
  dependencies = { "mfussenegger/nvim-jdtls" },
  opts = {
    -- All fields optional; shown with defaults:
    -- java_runtimes = {},
    -- lombok = true,
    -- dap = { enabled = true, hotcodereplace = "auto" },
    -- keymaps = true,
    -- keymap_prefix = "<leader>J",
    -- semantic_tokens = false,
    -- inlay_hints = false,
  },
}
```

With `opts = {}` or just `opts = true`, the plugin uses all defaults.
The `ft = "java"` ensures the bundled `ftplugin/java.lua` triggers `attach()` on the first Java buffer.

### Manual / pack system

```lua
-- In your plugin loader or init.lua:
vim.cmd("packadd nvim-jdtls")
vim.cmd("packadd jdtls.nvim")

require("jdtls-nvim").setup({
  -- your overrides
})
-- attach() is called automatically via ftplugin/java.lua
```

## Configuration

```lua
require("jdtls-nvim").setup({
  -- JDK runtimes for multi-version projects
  java_runtimes = {
    { name = "JavaSE-17", path = "/usr/lib/jvm/java-17" },
    { name = "JavaSE-21", path = "/usr/lib/jvm/java-21", default = true },
  },

  -- Optional jenv discovery.
  -- Manual jdtls_java_home/java_runtimes still win when provided.
  jenv = {
    enabled = false,
    use_java_home = true, -- prefer JAVA_HOME for launching JDTLS
    runtimes = "active",  -- "active" | "all" | {17, 21}
  },

  -- Lombok: true = auto-detect from Mason, false = disable, string = explicit path
  lombok = true,

  -- Eclipse formatter
  style_file = "~/.config/eclipse-formatter.xml",
  format_profile = "MyProfile",

  -- Extra JVM args for JDTLS server
  jvm_args = { "-Xms512m", "-Xmx3G", "-XX:+UseG1GC" },

  -- Optional JDK used to launch JDTLS and Java DAP helpers.
  -- Leave empty to use the default `jdtls` launcher and PATH java.
  jdtls_java_home = "",
  jdtls_log_protocol = false,
  jdtls_log_level = "WARN",

  -- Project root detection markers
  root_markers = { "mvnw", "gradlew", "pom.xml", "build.gradle", ".git" },

  -- Optional custom root resolver.
  -- Useful for Maven reactors or monorepos where the nearest pom.xml is not the desired root.
  root_resolver = function(bufnr, cfg)
    -- Return an absolute root path, or nil to fall back to root_markers.
    return nil
  end,

  -- Optional per-root config overlay. Called after root resolution.
  project_overrides = function(root_dir, cfg, bufnr)
    -- Return a table merged into the resolved config, or nil for no override.
    return nil
  end,

  -- Maven import settings passed to eclipse.jdt.ls as:
  -- java.configuration.maven.userSettings
  maven_user_settings = "/absolute/path/to/settings.xml",
  -- or:
  -- maven_user_settings = function(root_dir)
  --   return root_dir .. "/settings.xml"
  -- end,

  -- Optional m2e lifecycle mapping XML passed as:
  -- java.configuration.maven.lifecycleMappings
  maven_lifecycle_mappings = "/absolute/path/to/lifecycle-mapping.xml",

  -- Maven command builder defaults
  maven = {
    debug = true,
    debug_port = 5005,
    debug_suspend = false,
    retry_without_debug_on_port_busy = true,
    log_file = "/tmp/nvim-java-test.log",
  },

  -- JDTLS build/import preferences
  update_build_configuration = "interactive", -- "automatic" | "interactive" | "disabled"
  null_analysis_mode = "automatic",           -- "automatic" | "disabled"

  -- DAP (debug adapter protocol) integration
  dap = {
    enabled = true,
    hotcodereplace = "auto", -- "auto" | "manual" | "off"
    profiles = {},           -- extra DAP configurations to append
  },

  -- Test runner
  test = {
    runner = "maven",      -- "maven" | "gradle"
    extra_args = "",       -- additional CLI args
    send_command = nil,    -- fn(cmd) to send test command (e.g., tmux)
  },

  -- Buffer keymaps (set false to handle yourself)
  keymaps = true,
  keymap_prefix = "<leader>J",

  -- Feature toggles
  semantic_tokens = false,
  inlay_hints = false,
  organize_imports_on_save = true,
  treesitter_indent = true,

  -- Extra hooks
  on_attach = function(client, bufnr)
    -- your custom on_attach logic
  end,
  capabilities = nil,      -- override LSP capabilities
  workspace_dir = nil,     -- fn(root_dir) → custom workspace path
})
```

### JVM Used By JDTLS

By default, this plugin starts JDTLS through the `jdtls` executable:

```lua
cmd = { "jdtls" }
```

That means the Java runtime used to run the JDTLS server is resolved by the `jdtls` launcher itself, usually from the environment (`JAVA_HOME`/`PATH`) active when Neovim starts.

These options have different responsibilities:

- `jdtls_java_home` selects the JDK used by Java tooling: the JDTLS server process and Java DAP `javaExec`.
- `jvm_args` adds JVM flags for the JDTLS server process, such as `-Xmx3G`.
- `java_runtimes` configures project JDKs exposed to Eclipse JDTLS through `java.configuration.runtimes`.

Use `jdtls_java_home` when JDTLS itself must run on a pinned JDK:

```lua
require("jdtls-nvim").setup({
  jdtls_java_home = "/path/to/jdk-21",
})
```

When set, the plugin derives `<jdtls_java_home>/bin/java` and starts JDTLS with Mason’s Eclipse launcher jar. If the Java executable, launcher jar, or JDTLS config directory cannot be resolved, it falls back to the default `{ "jdtls" }` command.

`jdtls_java_home` does not replace `java_runtimes`; those still describe project JDKs available to Eclipse JDTLS.

### jenv Integration

When `jenv.enabled = true`, the plugin can derive Java configuration from the current shell environment:

```lua
require("jdtls-nvim").setup({
  jenv = {
    enabled = true,
    use_java_home = true,
    runtimes = "active",
  },
})
```

Resolution order:

1. Explicit `jdtls_java_home` wins.
2. If `use_java_home` is true and `JAVA_HOME` points to a valid JDK, use it to launch JDTLS.
3. Otherwise use `jenv prefix $(jenv version-name)`.
4. If `java_runtimes` is empty, build runtimes from `jenv.runtimes`.

`jenv.runtimes` accepts:

- `"active"`: fastest path, exposes only `jenv version-name`.
- `"all"`: exposes every `jenv versions --bare` entry.
- `{17, 21}`: exposes the first valid jenv runtime matching each requested Java major.

Use `jenv local <version>` in project roots when different projects need different Java versions. The plugin caches jenv discovery per Neovim session; restart Neovim or call `require("jdtls-nvim.jenv").clear_cache()` after changing jenv versions.

## Project Roots And Maven Settings

By default, root detection is generic and uses:

```lua
root_markers = { "mvnw", "gradlew", "pom.xml", "build.gradle", ".git" }
```

This works well for normal Maven/Gradle projects because the nearest `pom.xml` or build file becomes the JDTLS root.

For monorepos or Maven reactors, the nearest `pom.xml` can be a child module while the desired JDTLS root is the aggregator. Use `root_resolver` for that case:

```lua
require("jdtls-nvim").setup({
  root_resolver = function(bufnr)
    local path = vim.api.nvim_buf_get_name(bufnr)
    if path == "" then
      path = vim.loop.cwd()
    end

    local git_root = vim.fs.root(path, { ".git" })
    if git_root and vim.fn.filereadable(git_root .. "/pom.xml") == 1 then
      return git_root
    end

    -- nil keeps the plugin default root_markers behavior.
    return nil
  end,
})
```

Custom Maven settings can be static or derived from the resolved root:

```lua
require("jdtls-nvim").setup({
  maven_user_settings = function(root_dir)
    local settings = root_dir .. "/ci-settings.xml"
    return vim.fn.filereadable(settings) == 1 and settings or nil
  end,
})
```

This maps to `java.configuration.maven.userSettings`. It affects JDTLS project import and dependency resolution; shell commands still need their own Maven flags or `.mvn/maven.config`.

For m2e lifecycle issues, provide a lifecycle mapping file:

```lua
require("jdtls-nvim").setup({
  maven_lifecycle_mappings = function(root_dir)
    local mapping = root_dir .. "/.mvn/m2e-lifecycle.xml"
    return vim.fn.filereadable(mapping) == 1 and mapping or nil
  end,
})
```

For project-specific behavior without changing global defaults, use `project_overrides`:

```lua
require("jdtls-nvim").setup({
  project_overrides = function(root_dir)
    if vim.fn.filereadable(root_dir .. "/ci-settings.xml") ~= 1 then
      return nil
    end

    return {
      maven_user_settings = root_dir .. "/ci-settings.xml",
      update_build_configuration = "automatic",
    }
  end,
})
```

## Context API

`context()` exposes resolved settings for task runners:

```lua
local ctx = require("jdtls-nvim").context(0)

print(ctx.root_dir)
print(ctx.java_home)
print(ctx.maven_user_settings)
print(ctx.maven_module)
print(ctx.maven_module_dir)
```

This lets external test/build runners reuse the same root, Java, and Maven settings that JDTLS uses.

## Maven Command Builder

The Maven builder creates shell commands using the same context as JDTLS:

```lua
local maven = require("jdtls-nvim").maven()

local cmd = maven.test_method("MyTest", "works", {
  bufnr = 0,
})
```

Test commands are debug-ready by default:

```bash
-Dmaven.surefire.debug="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
```

That opens JDWP on port `5005` without blocking when no debugger is attached. Use suspend mode when you need to attach before test startup:

```lua
maven.test_method("MyTest", "works", {
  debug_suspend = true,
})
```

Disable debug flags explicitly:

```lua
maven.test_class("MyTest", {
  debug = false,
})
```

Configure the debug port globally:

```lua
require("jdtls-nvim").setup({
  maven = {
    debug_port = 5010,
  },
})
```

If the debug port is already in use, the generated command detects common JDWP bind errors, prints a warning in the terminal, and retries once without debug:

```text
[jdtls.nvim] Maven debug port 5005 is busy; retrying without debug.
```

For Java 8 runtimes the builder uses `address=5005`; for Java 9+ it uses `address=*:5005`.

Available helpers:

```lua
maven.command({ goal = "test", test = "MyTest#works" })
maven.test_method("MyTest", "works")
maven.test_class("MyTest")
maven.compile({ skip_tests = true })
maven.package({ skip_tests = true })
```

Behavior:

- Uses `JAVA_HOME=<ctx.java_home>` when available.
- Uses `ctx.maven_user_settings` unless `<root>/.mvn/maven.config` exists.
- Uses `-pl :artifactId -am` when buffer is inside a Maven module.
- Adds `-Dsurefire.failIfNoSpecifiedTests=false` only for module-scoped commands.
- Adds `-Dmaven.test.skip=true` for compile/package helpers, not for test helpers.
- Opens debug port by default for tests, with retry without debug on port bind failure.

## Keymaps

Default prefix: `<leader>J` (configurable via `keymap_prefix`).

| Key | Action |
|-----|--------|
| `<leader>JI` | Invert condition (code action) |
| `<leader>Jti` | Organize imports |
| `<leader>Jtv` | Extract variable |
| `<leader>Jtm` | Extract method |
| `<leader>Jtu` | Update JDTLS config (`:JdtUpdateConfig`) |
| `<leader>Jtw` | Clean workspace directory |

## DAP Integration

The plugin provides 4 built-in DAP configurations (via `dap_configurations()`):

1. **Attach (port 51922)** — remote debug attach
2. **Launch Current File** — run current Java file
3. **Attach (port 5005)** — standard remote debug port
4. **Maven Test (current class)** — run tests via Maven

### Error Recovery

When a DAP session errors with "specify projectName", the plugin auto-resolves the project name from JDTLS roots and retries the request. Access via:

```lua
local recovery = require("jdtls-nvim").dap_recovery()
recovery.request_with_recovery(session, command, args, on_success, on_error)
recovery.is_java_error(msg)    -- detect Java-specific errors
recovery.normalize_error(err)  -- normalize DAP error to string
```

## API

```lua
local jdtls = require("jdtls-nvim")

jdtls.setup(opts)                  -- configure (before attach)
jdtls.attach()                     -- attach JDTLS to current buffer
jdtls.get_config()                 -- read-only resolved config
jdtls.context(bufnr?)              -- resolved root/java/maven context
jdtls.maven()                      -- Maven command builder
jdtls.dap_configurations(bufnr?)   -- DAP profiles for nvim-dap
jdtls.project_name(path_hint?)     -- resolve Java project name
jdtls.dap_recovery()               -- DAP error recovery module
```

## License

MIT
