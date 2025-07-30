-- app module
-- Auto-configure Lua paths for LuaRocks installation
local function setup_lua_paths()
    local home = os.getenv("HOME")
    if home then
        local version = _VERSION:match("%d+%.%d+") or "5.1"
        local luarocks_path = home .. "/.luarocks/share/lua/" .. version .. "/?.lua"
        local luarocks_cpath = home .. "/.luarocks/share/lua/" .. version .. "/?/init.lua"
        if not package.path:find(luarocks_path, 1, true) then
            package.path = luarocks_path .. ";" .. luarocks_cpath .. ";" .. package.path
        end
    end
end
setup_lua_paths()

local ok, lumos = pcall(require, 'lumos')
if not ok then
    error("Module 'lumos' is not available. Make sure it's installed with: luarocks install lumos")
end
local okc, color = pcall(require, 'lumos.color')
if not okc then
    color = { green = function(s) return s end }
end

local M = {}

function M.run(args)
    local app = lumos.new_app({
        name = "testcli",
        version = "0.1.0",
        description = "Mon CLI de test"
    })

    app:flag("-v --verbose", "Enable verbose mode")

    local greet = app:command("greet", "Greet someone")
    greet:arg("name", "Name of the person")
    greet:action(function(ctx)
        local name = ctx.args[1] or "World"
        print(color.green("Hello, " .. name .. "!"))
        return true
    end)

    app:run(args)
end

return M
