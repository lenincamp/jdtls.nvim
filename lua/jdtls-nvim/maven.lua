--- Maven command builder for Java projects.
local M = {}

local context = require("jdtls-nvim.context")

local function shellescape(value)
  return vim.fn.shellescape(value)
end

local function file_exists(path)
  return type(path) == "string" and path ~= "" and vim.fn.filereadable(path) == 1
end

local function maven_config_exists(root_dir)
  if type(root_dir) ~= "string" or root_dir == "" then
    return false
  end
  return file_exists(root_dir .. "/.mvn/maven.config")
end

local function arg_key(value)
  local property = value:match("^-D([^=]+)=")
  if property then
    return "-D" .. property
  end
  if value:match("^%-s%s+") then
    return "-s"
  end
  if value:match("^%-pl%s+") then
    return "-pl"
  end
  return value
end

local function add_unique(args, seen, value)
  if type(value) ~= "string" or value == "" then
    return
  end
  local key = arg_key(value)
  if seen[key] then return end
  args[#args + 1] = value
  seen[key] = true
end

local function artifact_id_from_pom(pom)
  if not file_exists(pom) then
    return nil
  end

  local content = table.concat(vim.fn.readfile(pom), "\n")
  local without_parent = content:gsub("<parent>.-</parent>", "")
  return without_parent:match("<artifactId>%s*([^<%s]+)%s*</artifactId>")
end

local function module_selector(ctx)
  if not ctx.maven_module_dir then
    return nil
  end

  local artifact_id = artifact_id_from_pom(ctx.maven_module_dir .. "/pom.xml")
  if artifact_id and artifact_id ~= "" then
    return ":" .. artifact_id
  end

  return ctx.maven_module
end

local function java_major(ctx)
  for _, runtime in ipairs(ctx.java_runtimes or {}) do
    if runtime.default then
      local name = runtime.name or ""
      if name:find("JavaSE%-1%.8") then return 8 end
      local major = name:match("JavaSE%-(%d+)")
      if major then return tonumber(major) end
    end
  end

  local java = ctx.java_home and (ctx.java_home:gsub("/+$", "") .. "/bin/java") or nil
  if file_exists(java) or (java and vim.fn.executable(java) == 1) then
    local version = vim.fn.system(shellescape(java) .. " -version 2>&1"):match('version "([^"]+)"')
    if version then
      if version:match("^1%.8") then return 8 end
      local major = version:match("^(%d+)")
      if major then return tonumber(major) end
    end
  end

  return nil
end

local function debug_address(ctx, port)
  if java_major(ctx) == 8 then
    return tostring(port)
  end
  return "*:" .. tostring(port)
end

local function debug_arg(ctx, opts)
  if opts.debug == false then
    return nil
  end

  local suspend = opts.debug_suspend and "y" or "n"
  local port = opts.debug_port or 5005
  local agent = "-agentlib:jdwp=transport=dt_socket,server=y,suspend="
      .. suspend .. ",address=" .. debug_address(ctx, port)
  return "-Dmaven.surefire.debug=" .. shellescape(agent)
end

local function base_args(ctx, opts)
  opts = opts or {}
  local args = {}
  local seen = {}

  if ctx.maven_user_settings and not maven_config_exists(ctx.root_dir) then
    add_unique(args, seen, "-s " .. shellescape(ctx.maven_user_settings))
  end

  add_unique(args, seen, "-DfailIfNoTests=false")
  add_unique(args, seen, "-Djacoco.skip=true")
  add_unique(args, seen, "-Dmaven.javadoc.skip=true")
  add_unique(args, seen, "-Dmaven.site.skip=true")
  add_unique(args, seen, "-Dsurefire.useFile=false")
  add_unique(args, seen, "-DtrimStackTrace=false")
  add_unique(args, seen, "-Dmaven.source.skip=true")

  if opts.skip_tests then
    add_unique(args, seen, "-Dmaven.test.skip=true")
  end

  if opts.offline ~= false then
    add_unique(args, seen, "-o")
  end

  add_unique(args, seen, "-B")

  if opts.debug then
    add_unique(args, seen, debug_arg(ctx, opts))
  end

  local selector = module_selector(ctx)
  if opts.module ~= false and selector then
    add_unique(args, seen, "-pl " .. shellescape(selector))
    add_unique(args, seen, "-am")
    add_unique(args, seen, "-Dsurefire.failIfNoSpecifiedTests=false")
  end

  if opts.extra_args then
    for _, arg in ipairs(opts.extra_args) do
      add_unique(args, seen, arg)
    end
  end

  return args
end

local function with_defaults(ctx, opts)
  opts = opts or {}
  local maven_cfg = (ctx.config and ctx.config.maven) or {}
  local merged = vim.tbl_extend("force", {
    debug = maven_cfg.debug,
    debug_port = maven_cfg.debug_port,
    debug_suspend = maven_cfg.debug_suspend,
    retry_without_debug_on_port_busy = maven_cfg.retry_without_debug_on_port_busy,
    log_file = maven_cfg.log_file,
  }, opts)
  if merged.debug == nil then merged.debug = false end
  if merged.debug_port == nil then merged.debug_port = 5005 end
  if merged.debug_suspend == nil then merged.debug_suspend = false end
  if merged.retry_without_debug_on_port_busy == nil then
    merged.retry_without_debug_on_port_busy = true
  end
  if not merged.log_file or merged.log_file == "" then
    merged.log_file = "/tmp/nvim-java-test.log"
  end
  return merged
end

local function raw_command(ctx, opts)
  opts = opts or {}
  local goal = opts.goal or "test"
  if goal == "test" and opts.test and opts.debug == nil then
    opts.debug = true
  end

  local command = {
    "cd " .. shellescape(ctx.root_dir),
    "&&",
  }

  if ctx.java_home then
    command[#command + 1] = "JAVA_HOME=" .. shellescape(ctx.java_home)
  end

  command[#command + 1] = "mvn"
  command[#command + 1] = goal

  if opts.test then
    command[#command + 1] = "-Dtest=" .. shellescape(opts.test)
  end

  vim.list_extend(command, base_args(ctx, opts))

  return table.concat(command, " ")
end

local function zsh_retry_wrapper(debug_command, fallback_command, opts)
  local log_file = opts.log_file or "/tmp/nvim-java-test.log"
  local port = tostring(opts.debug_port or 5005)
  local script = table.concat({
    "set -o pipefail",
    "log=" .. shellescape(log_file),
    debug_command .. " 2>&1 | tee \"$log\"",
    "status=$?",
    "if grep -E 'Address already in use|bind failed|AGENT_ERROR_TRANSPORT_INIT|transport error 202' \"$log\" >/dev/null 2>&1; then",
    "  echo '[jdtls.nvim] Maven debug port " .. port .. " is busy; retrying without debug.'",
    "  " .. fallback_command .. " 2>&1 | tee -a \"$log\"",
    "  exit $?",
    "fi",
    "exit $status",
  }, "; ")
  return "zsh -lc " .. shellescape(script)
end

function M.command(opts)
  opts = opts or {}
  local ctx = context.get(opts.bufnr or 0)
  opts = with_defaults(ctx, opts)
  local goal = opts.goal or "test"
  if goal == "test" and opts.test and opts.debug == nil then
    opts.debug = true
  end

  local command = raw_command(ctx, opts)
  if goal == "test" and opts.debug and opts.retry_without_debug_on_port_busy then
    local fallback_opts = vim.tbl_extend("force", opts, { debug = false })
    return zsh_retry_wrapper(command, raw_command(ctx, fallback_opts), opts)
  end

  return command
end

function M.test_method(class_name, method_name, opts)
  opts = vim.tbl_extend("force", opts or {}, {
    goal = "test",
    test = class_name .. "#" .. method_name,
  })
  return M.command(opts)
end

function M.test_class(class_name, opts)
  opts = vim.tbl_extend("force", opts or {}, {
    goal = "test",
    test = class_name,
  })
  return M.command(opts)
end

function M.compile(opts)
  opts = vim.tbl_extend("force", opts or {}, {
    goal = "compile",
    skip_tests = true,
  })
  return M.command(opts)
end

function M.package(opts)
  opts = vim.tbl_extend("force", opts or {}, {
    goal = "package",
    skip_tests = true,
  })
  return M.command(opts)
end

return M
