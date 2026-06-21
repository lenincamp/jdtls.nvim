--- Java DAP error recovery: auto-retry on missing projectName, classpath hints.
--- Registered via dap.listeners when DAP is available.
local M = {}

local project = require("jdtls-nvim.project")

local function notify_java_eval_hint(msg)
  if not msg then return end
  local lowered = msg:lower()
  if lowered:find("classnotfound")
      or lowered:find("noclassdeffound")
      or lowered:find("library")
      or lowered:find("module") then
    vim.notify(
      "Java DAP: possible classpath/module issue. Prefer JDTLS main-class config (not Current File), then :JdtUpdateConfig and restart debug session.",
      vim.log.levels.WARN
    )
  end

  if lowered:find("specify projectname") then
    vim.notify(
      "Java DAP: missing projectName on attach session. Auto-retry is enabled; if it persists, run :JdtUpdateConfig and re-attach.",
      vim.log.levels.WARN
    )
  end
end

local function is_missing_project_name_error(msg)
  if not msg then return false end
  return msg:lower():find("specify projectname") ~= nil
end

local function maybe_set_java_project_name(session)
  if not session or not session.config or session.config.type ~= "java" then return false end
  if type(session.config.projectName) == "string" and session.config.projectName ~= "" then return true end

  local frame_source_path = session.current_frame
    and session.current_frame.source
    and session.current_frame.source.path
  local buf_path = vim.api.nvim_buf_get_name(0)
  local hint = frame_source_path or (buf_path ~= "" and buf_path or nil)

  local resolved = project.name(hint)
  if not resolved then return false end
  session.config.projectName = resolved
  return true
end

--- Wrap a DAP session request with Java-specific error recovery.
--- If the error is "specify projectName", auto-resolves and retries once.
---@param session table DAP session
---@param command string DAP command
---@param args table Request arguments
---@param on_success? fun(response: table)
---@param on_error? fun(msg: string) Called after recovery fails
---@param retry_count? number Internal retry counter
function M.request_with_recovery(session, command, args, on_success, on_error, retry_count)
  if not session then return end

  session:request(command, args, function(err, response)
    if err then
      local msg = M.normalize_error(err)
      if (retry_count or 0) < 1 and is_missing_project_name_error(msg) and maybe_set_java_project_name(session) then
        M.request_with_recovery(session, command, args, on_success, on_error, 1)
        return
      end
      vim.schedule(function()
        notify_java_eval_hint(msg)
        if on_error then
          on_error(msg)
        else
          vim.notify(string.format("DAP %s error: %s", command, msg), vim.log.levels.ERROR)
        end
      end)
      return
    end
    if on_success then on_success(response) end
  end)
end

--- Normalize DAP error responses to string.
---@param err any
---@return string|nil
function M.normalize_error(err)
  if not err then return nil end
  if type(err) == "string" then return err end
  if type(err) ~= "table" then return tostring(err) end

  local msg = err.message
  if not msg and err.body and err.body.error then
    msg = err.body.error.message
  end
  if not msg and err.error then
    msg = err.error.message or err.error
  end
  return msg or vim.inspect(err)
end

--- Check if an error is Java-specific and should trigger recovery.
---@param msg string
---@return boolean
function M.is_java_error(msg)
  if not msg then return false end
  local lowered = msg:lower()
  return lowered:find("specify projectname") ~= nil
      or lowered:find("classnotfound") ~= nil
      or lowered:find("noclassdeffound") ~= nil
end

return M
