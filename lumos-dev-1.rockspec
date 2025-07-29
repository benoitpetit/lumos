rockspec_format = "3.0"
package = "lumos"
version = "dev-1"

source = {
   url = ".",  -- Used for local builds
   dir = "."
}

description = {
   summary = "A modern Lua CLI framework with advanced features (Development Version)",
   detailed = [[
      Lumos is a comprehensive CLI framework for Lua that provides:
      - Easy command and flag definition with fluent API
      - Built-in validation and type checking
      - Automatic help generation and documentation
      - Shell completion support (Bash, Zsh, Fish)
      - Man page generation and Markdown docs
      - Progress bars and interactive prompts
      - JSON configuration support
      - Color output with terminal detection
      - Project scaffolding with 'lumos new' command
      
      This is the development version with latest features.
   ]],
   homepage = "https://github.com/benoitpetit/lumos",
   license = "MIT"
}

dependencies = {
   "lua >= 5.1",
   "luafilesystem >= 1.6.3"
}

build = {
   type = "builtin",
   modules = {
      ["lumos"] = "lumos/init.lua",
      ["lumos.app"] = "lumos/app.lua",
      ["lumos.core"] = "lumos/core.lua",
      ["lumos.flags"] = "lumos/flags.lua",
      ["lumos.color"] = "lumos/color.lua",
      ["lumos.config"] = "lumos/config.lua",
      ["lumos.json"] = "lumos/json.lua",
      ["lumos.loader"] = "lumos/loader.lua",
      ["lumos.progress"] = "lumos/progress.lua",
      ["lumos.prompt"] = "lumos/prompt.lua",
      ["lumos.table"] = "lumos/table.lua",
      ["lumos.completion"] = "lumos/completion.lua",
      ["lumos.manpage"] = "lumos/manpage.lua",
      ["lumos.markdown"] = "lumos/markdown.lua",
      ["lumos.format"] = "lumos/format.lua"
   },
   install = {
      bin = {
         ["lumos"] = "bin/lumos"
      }
   }
}

test = {
   type = "busted",
   platforms = {
      unix = {
         flags = { "--exclude-tags=slow" }
      }
   }
}
