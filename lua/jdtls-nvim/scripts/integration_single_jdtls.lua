-- Integration: open Java buffer with real Neovim config; assert single jdtls client/process.
-- Usage: nvim --headless -S scripts/integration_single_jdtls.lua

print("=== jdtls single-instance integration ===")

-- Headless shells often default to Java 17; Mason jdtls requires Java 21+.
local java21 = "/opt/homebrew/Cellar/openjdk@21/21.0.11/libexec/openjdk.jdk/Contents/Home"
if (vim.env.JAVA_HOME or "") == "" and vim.fn.isdirectory(java21) == 1 then
  vim.env.JAVA_HOME = java21
  vim.env.PATH = java21 .. "/bin:" .. (vim.env.PATH or "")
  print("JAVA_HOME=" .. java21)
end

local java_file = vim.env.JDTLS_TEST_JAVA_FILE
if not java_file or java_file == "" then
  java_file = vim.fn.getcwd() .. "/src/main/java/StringCalculator.java"
end

if vim.fn.filereadable(java_file) ~= 1 then
  print("FAIL: java file not found: " .. java_file)
  vim.cmd("cquit 1")
  return
end

local function jdtls_client_count()
  return #vim.lsp.get_clients({ name = "jdtls" })
end

local function jdtls_process_count()
  local out = vim.fn.system("pgrep -fc '[j]dtls' 2>/dev/null || echo 0")
  return tonumber(vim.trim(out)) or 0
end

local function wait_until(deadline_ms, predicate)
  local deadline = vim.loop.now() + deadline_ms
  while vim.loop.now() < deadline do
    if predicate() then
      return true
    end
    vim.wait(250)
  end
  return predicate()
end

local function fail(msg)
  print("FAIL: " .. msg)
  vim.cmd("cquit 1")
end

local function pass(msg)
  print("PASS: " .. msg)
end

print("java_file=" .. java_file)

local procs_before = jdtls_process_count()
print("procs_before=" .. procs_before)

vim.cmd("edit " .. vim.fn.fnameescape(java_file))

if vim.bo.filetype ~= "java" then
  fail("buffer filetype is not java (got " .. tostring(vim.bo.filetype) .. ")")
end

-- lazy ft=java + ftplugin attach
local attached = wait_until(90000, function()
  return jdtls_client_count() >= 1
end)

if not attached then
  fail("no jdtls LSP client after 90s (clients=" .. jdtls_client_count() .. ")")
end

local clients_after_open = jdtls_client_count()
local procs_after_open = jdtls_process_count()
print("clients_after_open=" .. clients_after_open)
print("procs_after_open=" .. procs_after_open)

if clients_after_open ~= 1 then
  fail("expected 1 jdtls client after open, got " .. clients_after_open)
end

-- Simulate old bug: duplicate attach() from dotfiles ftplugin + plugin ftplugin
local ok_jdtls, jdtls_nvim = pcall(require, "jdtls-nvim")
if not ok_jdtls then
  fail("jdtls-nvim not loaded: " .. tostring(jdtls_nvim))
end

jdtls_nvim.attach()
jdtls_nvim.attach()
jdtls_nvim.attach()

vim.wait(3000)

local clients_after_dup = jdtls_client_count()
local procs_after_dup = jdtls_process_count()
print("clients_after_dup_attach=" .. clients_after_dup)
print("procs_after_dup_attach=" .. procs_after_dup)

if clients_after_dup ~= 1 then
  fail("duplicate attach() spawned extra clients: " .. clients_after_dup)
end

if procs_after_dup > procs_before + 1 then
  fail("duplicate attach() spawned extra processes: before=" .. procs_before .. " after=" .. procs_after_dup)
end

-- Second buffer in same project should reuse client
local java_file_2 = vim.fn.fnamemodify(java_file, ":h") .. "/TextProcessor.java"
if vim.fn.filereadable(java_file_2) == 1 then
  vim.cmd("edit " .. vim.fn.fnameescape(java_file_2))
  wait_until(30000, function()
    return jdtls_client_count() >= 1
  end)
  vim.wait(2000)
  local clients_second_buf = jdtls_client_count()
  local procs_second_buf = jdtls_process_count()
  print("clients_second_buf=" .. clients_second_buf)
  print("procs_second_buf=" .. procs_second_buf)
  if clients_second_buf ~= 1 then
    fail("second buffer should reuse client, got " .. clients_second_buf)
  end
  if procs_second_buf > procs_before + 1 then
    fail("second buffer spawned extra process: " .. procs_second_buf)
  end
  pass("second buffer reuses single jdtls client/process")
else
  print("SKIP: second java file not found")
end

pass("single jdtls client after open + triple attach()")
vim.cmd("quitall!")
