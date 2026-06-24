--- Server module: builds JDTLS command, config, and starts/attaches.
local M = {}

local config = require("jdtls-nvim.config")
local paths = require("jdtls-nvim.paths")

--- Build the JDTLS command line.
---@param workspace_dir string
---@param lombok_jar string
---@param jvm_args string[]
---@param java_exec? string
---@param launcher_jar? string
---@param config_dir? string
---@return string[]
function M.build_cmd(workspace_dir, lombok_jar, jvm_args, java_exec, launcher_jar, config_dir)
  local use_custom_java = java_exec and java_exec ~= "" and launcher_jar and launcher_jar ~= "" and config_dir and
  config_dir ~= ""
  local cmd = use_custom_java and {
    java_exec,
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",
    "-Dlog.protocol=true",
    "-Dlog.level=ALL",
  } or { "jdtls" }

  for _, arg in ipairs(jvm_args) do
    if use_custom_java then
      cmd[#cmd + 1] = arg
    else
      cmd[#cmd + 1] = "-vmargs"
      cmd[#cmd + 1] = arg
    end
  end

  -- Lombok agent (Java 9+ only needs -javaagent, no bootclasspath)
  if lombok_jar ~= "" and vim.fn.filereadable(lombok_jar) == 1 then
    if use_custom_java then
      cmd[#cmd + 1] = "-javaagent:" .. lombok_jar
    else
      table.insert(cmd, 2, "--jvm-arg=-javaagent:" .. lombok_jar)
    end
  end

  if use_custom_java then
    cmd[#cmd + 1] = "-jar"
    cmd[#cmd + 1] = launcher_jar
    cmd[#cmd + 1] = "-configuration"
    cmd[#cmd + 1] = config_dir
  end

  -- Workspace data directory
  cmd[#cmd + 1] = "-data"
  cmd[#cmd + 1] = workspace_dir

  return cmd
end

--- Collect DAP bundles from Mason packages.
---@param mason_base string
---@return string[]
function M.dap_bundles(mason_base)
  local bundles = {}
  vim.list_extend(bundles, vim.fn.glob(
    mason_base .. "java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar",
    false, true))
  vim.list_extend(bundles, vim.fn.glob(
    mason_base .. "java-test/extension/server/*.jar",
    false, true))
  return bundles
end

--- Start or attach JDTLS to the current buffer.
---@return boolean started
function M.start()
  local ok_jdtls, jdtls = pcall(require, "jdtls")
  if not ok_jdtls then
    vim.notify("[jdtls.nvim] nvim-jdtls not found. Install mfussenegger/nvim-jdtls.", vim.log.levels.ERROR)
    return false
  end

  local cfg = config.get()

  -- Find project root
  local root_dir = jdtls.setup.find_root(cfg.root_markers)
  if root_dir == nil then return false end

  root_dir = paths.normalize_root(root_dir)

  -- Workspace
  local workspace_dir, project_name = paths.workspace_for_root(root_dir, cfg.workspace_dir)

  -- Store project name globally for other modules
  vim.g.jdtls_nvim_project_name = project_name

  -- Lombok
  local lombok_jar = paths.lombok_jar(cfg.lombok)

  -- Mason base
  local mason_base = paths.mason_base()

  -- DAP bundles
  local bundles = cfg.dap.enabled and M.dap_bundles(mason_base) or {}

  -- Capabilities
  local capabilities = cfg.capabilities
  if not capabilities then
    local ok_blink, blink = pcall(require, "blink.cmp")
    capabilities = ok_blink and blink.get_lsp_capabilities() or vim.lsp.protocol.make_client_capabilities()
  end

  -- Disable file watchers for non-existent paths
  capabilities.workspace = capabilities.workspace or {}
  capabilities.workspace.didChangeWatchedFiles = capabilities.workspace.didChangeWatchedFiles or {}
  capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = false

  -- Extended capabilities (IntelliJ parity)
  local ext_caps = vim.deepcopy(jdtls.extendedClientCapabilities)

  -- Build cmd
  local java_exec = paths.java_exec_from_home(cfg.jdtls_java_home)
  local launcher_jar = java_exec ~= "" and paths.jdtls_launcher_jar() or ""
  local config_dir = java_exec ~= "" and paths.jdtls_config_dir() or ""
  local cmd = M.build_cmd(workspace_dir, lombok_jar, cfg.jvm_args, java_exec, launcher_jar, config_dir)

  -- Settings
  local settings = require("jdtls-nvim.settings").build(cfg)

  -- JDTLS config
  local jdtls_config = {
    cmd = cmd,
    root_dir = root_dir,
    capabilities = capabilities,

    flags = {
      debounce_text_changes = 300,
      allow_incremental_sync = true,
    },

    init_options = {
      bundles = bundles,
      extendedClientCapabilities = ext_caps,
    },

    settings = settings,

    on_attach = function(client, bufnr)
      if not vim.api.nvim_buf_is_valid(bufnr) then return end

      -- Feature toggles
      if not cfg.semantic_tokens then
        client.server_capabilities.semanticTokensProvider = nil
      end

      if not cfg.inlay_hints and client.server_capabilities.inlayHintProvider then
        vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
      end

      -- Buffer keymaps
      if cfg.keymaps then
        require("jdtls-nvim.keymaps").attach(bufnr, cfg.keymap_prefix, workspace_dir)
      end

      -- Treesitter indentation
      if cfg.treesitter_indent then
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(bufnr) then return end
          if vim.bo[bufnr].filetype ~= "java" then return end
          if vim.treesitter.query.get("java", "indents") ~= nil then
            vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end)
      end

      -- User on_attach hook
      if cfg.on_attach then
        cfg.on_attach(client, bufnr)
      end
    end,

    test = {
      config_overrides = { vmArgs = "-ea -Xmx1g" },
    },
  }

  -- Reuse client for same root
  local function reuse_same_root(client, candidate)
    if not client or client.name ~= "jdtls" then return false end
    local client_root = paths.normalize_root(client.config and client.config.root_dir)
    local candidate_root = paths.normalize_root(candidate and candidate.root_dir)
    if client_root == "" or candidate_root == "" then return false end
    return client_root == candidate_root
  end

  jdtls.start_or_attach(jdtls_config, nil, { reuse_client = reuse_same_root })
  return true
end

return M
