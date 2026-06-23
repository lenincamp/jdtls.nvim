# jdtls.nvim

Opinionated JDTLS configuration for Neovim. Wraps [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) with sensible defaults, automatic Lombok/DAP setup, and a minimal `setup()` + `attach()` API.

## Features

- **Zero-config start** — auto-detects project root, Lombok, Mason DAP bundles
- **DAP integration** — 4 built-in debug configurations + error recovery (auto-retry on `projectName` resolution)
- **Buffer keymaps** — organize imports, extract variable/method, invert condition, clean workspace
- **Feature toggles** — semantic tokens, inlay hints, treesitter indent, LSP folding, organize-imports-on-save
- **Project name resolution** — from JDTLS roots, `vim.g`, or filesystem markers
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

  -- Project root detection markers
  root_markers = { "mvnw", "gradlew", "pom.xml", "build.gradle", ".git" },

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
  lsp_folding = true,

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
jdtls.dap_configurations(bufnr?)   -- DAP profiles for nvim-dap
jdtls.project_name(path_hint?)     -- resolve Java project name
jdtls.dap_recovery()               -- DAP error recovery module
```

## License

MIT
