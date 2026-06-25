--- JDTLS settings builder.
--- Translates plugin config into the nested java.* settings structure.
local M = {}

local IMPORT_EXCLUSIONS = {
  "**/node_modules/**",
  "**/.metadata/**",
  "**/archetype-resources/**",
  "**/META-INF/maven/**",
  "**/target/**",
  "**/build/**",
  "**/.gradle/**",
  "**/.idea/**",
  "**/.git/**",
  "**/dist/**",
  "**/out/**",
}

local FAVORITE_STATIC_MEMBERS = {
  "org.hamcrest.MatcherAssert.assertThat",
  "org.hamcrest.Matchers.*",
  "org.hamcrest.CoreMatchers.*",
  "org.junit.jupiter.api.Assertions.*",
  "java.util.Objects.requireNonNull",
  "java.util.Objects.requireNonNullElse",
  "org.mockito.Mockito.*",
  "org.mockito.ArgumentMatchers.*",
  "java.util.stream.Collectors.*",
  "java.util.Arrays.*",
  "java.util.Collections.*",
}

local FILTERED_TYPES = {
  "com.sun.*",
  "io.micrometer.shaded.*",
  "java.awt.*",
  "jdk.*",
  "sun.*",
}

--- Resolve Maven userSettings from config and project root.
---@param cfg jdtls_nvim.Config
---@param root_dir? string
---@return string|nil
local function resolve_maven_user_settings(cfg, root_dir)
  local value = cfg.maven_user_settings
  if value == nil then
    return nil
  end
  if type(value) == "function" then
    return value(root_dir or "")
  end
  if type(value) == "string" and value ~= "" then
    return value
  end
  return nil
end

--- Build JDTLS settings from plugin config.
---@param cfg jdtls_nvim.Config
---@param root_dir? string
---@return table
function M.build(cfg, root_dir)
  local exclusions = vim.deepcopy(IMPORT_EXCLUSIONS)
  if cfg.extra_import_exclusions and #cfg.extra_import_exclusions > 0 then
    vim.list_extend(exclusions, cfg.extra_import_exclusions)
  end

  local maven_user_settings = resolve_maven_user_settings(cfg, root_dir)
  local configuration_maven = {}
  if maven_user_settings then
    configuration_maven.userSettings = maven_user_settings
  end

  return {
    java = {
      maven = { enabled = true, downloadSources = true, updateSnapshots = false },
      gradle = { enabled = false, downloadSources = true },
      contentProvider = { preferred = "fernflower" },
      references = { includeDecompiledSources = true },

      autobuild = { enabled = false },
      maxConcurrentBuilds = 1,

      import = {
        exclusions = exclusions,
        maven = { enabled = true },
        gradle = { enabled = false },
      },

      configuration = {
        updateBuildConfiguration = cfg.update_build_configuration,
        runtimes = cfg.java_runtimes,
        maven = configuration_maven,
      },

      compile = {
        nullAnalysis = {
          mode = cfg.null_analysis_mode,
        },
      },

      signatureHelp = { enabled = true, description = { enabled = true } },

      completion = {
        enabled = true,
        overwrite = false,
        guessMethodArguments = false,
        favoriteStaticMembers = vim.deepcopy(FAVORITE_STATIC_MEMBERS),
        filteredTypes = vim.deepcopy(FILTERED_TYPES),
        importOrder = { "java", "jakarta", "javax", "com", "org" },
      },

      format = {
        enabled = true,
        comments = { enabled = true },
        settings = {
          url = cfg.style_file ~= "" and cfg.style_file or nil,
          profile = (cfg.style_file ~= "" and cfg.format_profile ~= "") and cfg.format_profile or nil,
        },
      },

      implementationsCodeLens = { enabled = false },
      referencesCodeLens = { enabled = false },

      inlayHints = {
        parameterNames = {
          enabled = "literals",
          exclusions = {},
        },
      },

      saveActions = {
        organizeImports = cfg.organize_imports_on_save,
      },

      sources = {
        organizeImports = {
          starThreshold = 9999,
          staticStarThreshold = 9999,
        },
      },

      codeGeneration = {
        toString = {
          template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
          codeStyle = "STRING_CONCATENATION",
          skipNullValues = false,
          listArrayContents = true,
        },
        hashCodeEquals = {
          useJava7Objects = true,
          useInstanceof = true,
        },
        useBlocks = true,
        addFinalForNewDeclaration = false,
        insertionLocation = "afterCursor",
      },

      project = {
        referencedLibraries = { "lib/**/*.jar" },
      },
    },
  }
end

return M
