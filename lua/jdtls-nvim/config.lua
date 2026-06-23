--- Configuration module: merges user opts with defaults.
local M = {}

---@class jdtls_nvim.UserConfig
---@field jdtls_java_home? string JDK home used to launch JDTLS and Java DAP helpers
---@field java_runtimes? table[] JDK runtime entries {name, path, default?}
---@field lombok? boolean|string Auto-detect or explicit path
---@field style_file? string Eclipse formatter XML path
---@field format_profile? string Eclipse formatter profile name
---@field extra_import_exclusions? string[] Additional import exclusion globs
---@field jvm_args? string[] Extra JVM args for JDTLS
---@field root_markers? string[] Project root markers
---@field dap? jdtls_nvim.DapConfig DAP configuration
---@field test? jdtls_nvim.TestConfig Test runner configuration
---@field keymaps? boolean Enable buffer-local keymaps (default: true)
---@field keymap_prefix? string Keymap prefix (default: "<leader>J")
---@field semantic_tokens? boolean Enable semantic tokens (default: false)
---@field inlay_hints? boolean Enable inlay hints (default: false)
---@field organize_imports_on_save? boolean Organize imports on save (default: true)
---@field treesitter_indent? boolean Enable treesitter indentation (default: true)
---@field lsp_folding? boolean Enable LSP folding via jdtls (default: true)
---@field on_attach? fun(client: vim.lsp.Client, bufnr: integer) Extra on_attach hook
---@field capabilities? table Override LSP capabilities
---@field workspace_dir? fun(root_dir: string): string Custom workspace dir resolver

---@class jdtls_nvim.DapConfig
---@field enabled? boolean Enable DAP integration (default: true)
---@field profiles? table[] Extra/override DAP configurations
---@field hotcodereplace? string "auto"|"manual"|"off" (default: "auto")

---@class jdtls_nvim.TestConfig
---@field runner? string "maven"|"gradle" (default: "maven")
---@field send_command? fun(cmd: string) Hook to send test command (e.g., tmux)
---@field extra_args? string Additional Maven/Gradle args

---@class jdtls_nvim.Config
---@field jdtls_java_home string
---@field java_runtimes table[]
---@field lombok boolean|string
---@field style_file string
---@field format_profile string
---@field extra_import_exclusions string[]
---@field jvm_args string[]
---@field root_markers string[]
---@field dap jdtls_nvim.DapConfig
---@field test jdtls_nvim.TestConfig
---@field keymaps boolean
---@field keymap_prefix string
---@field semantic_tokens boolean
---@field inlay_hints boolean
---@field organize_imports_on_save boolean
---@field treesitter_indent boolean
---@field lsp_folding boolean
---@field on_attach? fun(client: vim.lsp.Client, bufnr: integer)
---@field capabilities? table
---@field workspace_dir? fun(root_dir: string): string

---@type jdtls_nvim.Config
local defaults = {
  jdtls_java_home = "",
  java_runtimes = {},
  lombok = true,
  style_file = "",
  format_profile = "",
  extra_import_exclusions = {},
  jvm_args = { "-Xms512m", "-Xmx3G", "-XX:+UseG1GC", "-XX:MaxGCPauseMillis=200", "-XX:+UseStringDeduplication" },
  root_markers = { "mvnw", "gradlew", "pom.xml", "build.gradle", ".git" },
  dap = {
    enabled = true,
    profiles = {},
    hotcodereplace = "auto",
  },
  test = {
    runner = "maven",
    send_command = nil,
    extra_args = "",
  },
  keymaps = true,
  keymap_prefix = "<leader>J",
  semantic_tokens = false,
  inlay_hints = false,
  organize_imports_on_save = true,
  treesitter_indent = true,
  lsp_folding = true,
  on_attach = nil,
  capabilities = nil,
  workspace_dir = nil,
}

---@type jdtls_nvim.Config
local resolved = vim.deepcopy(defaults)

---@param opts? jdtls_nvim.UserConfig
function M.setup(opts)
  opts = opts or {}
  resolved = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
end

---@return jdtls_nvim.Config
function M.get()
  return resolved
end

---@return jdtls_nvim.Config
function M.defaults()
  return vim.deepcopy(defaults)
end

return M
