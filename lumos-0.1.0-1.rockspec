package = "lumos"
version = "0.1.0-1"
source = {
   url = "git+https://github.com/benoitpetit/lumos.git",
   tag = "v0.1.0"
}
description = {
   summary = "A modern CLI framework for Lua",
   detailed = [[
      Lumos is a CLI framework for Lua inspired by Cobra for Go. It provides
      POSIX-compliant argument parsing, fluent command definition API, automatic
      help generation, color support, progress bars, and interactive prompts.
      
      Features:
      - POSIX-compliant argument parsing with short and long flags
      - Fluent command definition API with chainable methods
      - Automatic help generation with examples
      - ANSI color and styling support with terminal detection
      - Progress bars (simple and advanced)
      - Interactive prompts (input, password, confirmation, selection)
      - Global and local flags with inheritance
      - Robust error handling and validation
   ]],
   homepage = "https://github.com/benoitpetit/lumos",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1, < 5.5"
}
build = {
   type = "builtin",
   modules = {
      ["lumos"] = "lumos/init.lua",
      ["lumos.app"] = "lumos/app.lua",
      ["lumos.core"] = "lumos/core.lua",
      ["lumos.flags"] = "lumos/flags.lua",
      ["lumos.color"] = "lumos/color.lua",
      ["lumos.progress"] = "lumos/progress.lua",
      ["lumos.prompt"] = "lumos/prompt.lua",
      ["lumos.table"] = "lumos/table.lua",
      ["lumos.loader"] = "lumos/loader.lua"
   }
}
