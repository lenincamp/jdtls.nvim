--- Configuration module: merges user opts with defaults.
local M = {}

---@class jdtls_nvim.UserConfig
---@field jdtls_java_home? string JDK home used to launch JDTLS and Java DAP helpers
---@field jdtls_log_protocol? boolean Enable Eclipse JDTLS protocol logging
---@field jdtls_log_level? string Eclipse JDTLS log level, e.g. "OFF", "WARN", "INFO", "ALL"
---@field java_runtimes? table[] JDK runtime entries {name, path, default?}
---@field lombok? boolean|string Auto-detect or explicit path
---@field style_file? string Eclipse formatter XML path
---@field format_profile? string Eclipse formatter profile name
---@field extra_import_exclusions? string[] Additional import exclusion globs
---@field jvm_args? string[] Extra JVM args for JDTLS
---@field jenv? jdtls_nvim.JenvConfig Discover JDKs from jenv
---@field root_markers? string[] Project root markers
---@field root_resolver? fun(bufnr: integer, cfg: jdtls_nvim.Config): string? Custom project root resolver
---@field project_overrides? fun(root_dir: string, cfg: jdtls_nvim.Config, bufnr?: integer): table? Per-project option overrides
---@field maven_user_settings? string|fun(root_dir: string): string? Absolute path or resolver for java.configuration.maven.userSettings
---@field maven_lifecycle_mappings? string|fun(root_dir: string): string? Absolute path or resolver for java.configuration.maven.lifecycleMappings
---@field maven? jdtls_nvim.MavenConfig Maven command builder defaults
---@field update_build_configuration? string "automatic"|"interactive"|"disabled" for java.configuration.updateBuildConfiguration
---@field null_analysis_mode? string "automatic"|"disabled" for java.compile.nullAnalysis.mode
---@field dap? jdtls_nvim.DapConfig DAP configuration
---@field test? jdtls_nvim.TestConfig Test runner configuration
---@field keymaps? boolean Enable buffer-local keymaps (default: true)
---@field keymap_prefix? string Keymap prefix (default: "<leader>J")
---@field semantic_tokens? boolean Enable semantic tokens (default: false)
---@field inlay_hints? boolean Enable inlay hints (default: false)
---@field organize_imports_on_save? boolean Organize imports on save (default: true)
---@field treesitter_indent? boolean Enable treesitter indentation (default: true)
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

---@class jdtls_nvim.JenvConfig
---@field enabled? boolean Enable jenv discovery (default: false)
---@field use_java_home? boolean Prefer JAVA_HOME for JDTLS java_home (default: true)
---@field runtimes? string|number[] "active", "all", or Java majors to expose, e.g. {17, 21} (default: "active")

---@class jdtls_nvim.MavenConfig
---@field debug? boolean Enable debug-ready Maven tests by default
---@field debug_port? integer JDWP debug port
---@field debug_suspend? boolean Suspend JVM until debugger attaches
---@field retry_without_debug_on_port_busy? boolean Retry without debug when JDWP port is busy
---@field log_file? string Maven test log file used by retry wrapper

---@class jdtls_nvim.Config
---@field jdtls_java_home string
---@field jdtls_log_protocol boolean
---@field jdtls_log_level string
---@field java_runtimes table[]
---@field lombok boolean|string
---@field style_file string
---@field format_profile string
---@field extra_import_exclusions string[]
---@field jvm_args string[]
---@field jenv jdtls_nvim.JenvConfig
---@field root_markers string[]
---@field root_resolver? fun(bufnr: integer, cfg: jdtls_nvim.Config): string?
---@field project_overrides? fun(root_dir: string, cfg: jdtls_nvim.Config, bufnr?: integer): table?
---@field maven_user_settings? string|fun(root_dir: string): string?
---@field maven_lifecycle_mappings? string|fun(root_dir: string): string?
---@field maven jdtls_nvim.MavenConfig
---@field update_build_configuration string
---@field null_analysis_mode string
---@field dap jdtls_nvim.DapConfig
---@field test jdtls_nvim.TestConfig
---@field keymaps boolean
---@field keymap_prefix string
---@field semantic_tokens boolean
---@field inlay_hints boolean
---@field organize_imports_on_save boolean
---@field treesitter_indent boolean
---@field on_attach? fun(client: vim.lsp.Client, bufnr: integer)
---@field capabilities? table
---@field workspace_dir? fun(root_dir: string): string

---@type jdtls_nvim.Config
local defaults = {
  jdtls_java_home = "",
  jdtls_log_protocol = false,
  jdtls_log_level = "WARN",
  java_runtimes = {},
  lombok = true,
  style_file = "",
  format_profile = "",
  extra_import_exclusions = {},
  jvm_args = { "-Xms512m", "-Xmx3G", "-XX:+UseG1GC", "-XX:MaxGCPauseMillis=200", "-XX:+UseStringDeduplication" },
  jenv = {
    enabled = false,
    use_java_home = true,
    runtimes = "active",
  },
  root_markers = { "mvnw", "gradlew", "pom.xml", "build.gradle", ".git" },
  root_resolver = nil,
  project_overrides = nil,
  maven_user_settings = nil,
  maven_lifecycle_mappings = nil,
  maven = {
    debug = true,
    debug_port = 5005,
    debug_suspend = false,
    retry_without_debug_on_port_busy = true,
    log_file = "/tmp/nvim-java-test.log",
  },
  update_build_configuration = "interactive",
  null_analysis_mode = "automatic",
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

---@param root_dir? string
---@param bufnr? integer
---@return jdtls_nvim.Config
function M.resolve(root_dir, bufnr)
  local cfg = vim.deepcopy(resolved)
  if root_dir and type(cfg.project_overrides) == "function" then
    local ok, overrides = pcall(cfg.project_overrides, root_dir, vim.deepcopy(cfg), bufnr)
    if ok and type(overrides) == "table" then
      cfg = vim.tbl_deep_extend("force", cfg, overrides)
    end
  end
  return require("jdtls-nvim.jenv").apply(cfg)
end

---@return jdtls_nvim.Config
function M.defaults()
  return vim.deepcopy(defaults)
end

return M
