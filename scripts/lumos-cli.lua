-- lumos-cli.lua : Générateur de squelette de projet CLI Lumos

-- lumos-cli.lua : Lumos CLI project skeleton generator

-- Try to use local lumos if available, else fallback to system/luarocks
-- Add local lumos paths for both ./lumos/ and ../lumos/ (if run from scripts/)
local paths = {
    './lumos/?.lua',
    './lumos/?/init.lua',
    '../lumos/?.lua',
    '../lumos/?/init.lua'
}
for _, p in ipairs(paths) do
    if not package.path:find(p, 1, true) then
        package.path = package.path .. ';' .. p
    end
end
local lumos = require('lumos')
local color = require('lumos.color')
local prompt = require('lumos.prompt')


-- Cross-platform recursive directory creation with lfs
local lfs = require('lfs')
local function mkdir_p(path)
    local sep = package.config:sub(1,1)
    local p = ''
    for dir in string.gmatch(path, "[^" .. sep .. "]+") do
        p = p == '' and dir or (p .. sep .. dir)
        if not lfs.attributes(p, 'mode') then
            local ok, err = lfs.mkdir(p)
            if not ok then
                print('Error creating directory: ' .. p .. ' (' .. tostring(err) .. ')')
                return false
            end
        end
    end
    return true
end

local function write_file(path, content)
    local f = io.open(path, 'w')
    if not f then
        print('Error creating file: ' .. path)
        return false
    end
    f:write(content)
    f:close()
    return true
end

local function get_main_template(name, description)
    return [[#!/usr/bin/env lua
-- Add local path for app module
local src_path = debug.getinfo(1, 'S').source:match("^@(.+/)main.lua$") or "./src/"
package.path = src_path .. "?.lua;" .. src_path .. "?/init.lua;" .. package.path
local ok, app = pcall(require, 'app')
if not ok then
    print("Error: module 'app' not found. Make sure Lumos is installed or present in ./src.")
    os.exit(1)
end

-- Entrypoint for your CLI app
app.run(arg)
]]
end

local function get_module_template(name, description)
    return string.format([[-- app module
local ok, lumos = pcall(require, 'lumos')
if not ok then
    error("Module 'lumos' is not available. Place the lumos folder in ./src or install it locally.")
end
local okc, color = pcall(require, 'lumos.color')
if not okc then
    color = { green = function(s) return s end }
end

local M = {}

function M.run(args)
    local app = lumos.new_app({
        name = "%s",
        version = "0.1.0",
        description = "%s"
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
]], name, description)
end

local function get_test_template(name)
    return [[-- Basic test for app
local app = require('app')

describe("App CLI", function()
    it("should run without error", function()
        assert.has_no.errors(function()
            app.run({"greet", "TestUser"})
        end)
    end)
end)
]]
end

local function get_readme_template(name)
    return string.format([[# %s CLI Project

This project was generated with lumos-cli.

## Structure

- src/app.lua : Main CLI module
- src/main.lua : Entrypoint
- tests/app_spec.lua : Example test (busted)

## Getting Started

```bash
lua src/main.lua greet Alice
```

## Run tests

```bash
busted tests/
```
]], name)
end

local app = lumos.new_app({
    name = "lumos-cli",
    version = "0.1.0",
    description = "Lumos CLI project template generator"
})

app:command("new", "Create a new Lumos CLI project interactively")
    :action(function(ctx)
        print(color.cyan("Welcome to the Lumos CLI project generator!"))
        local project_name = prompt.input("Project name", "myapp")
        local description = prompt.input("Project description", "A CLI app built with Lumos")
        print(color.yellow("Creating project structure for " .. project_name .. " ..."))
        mkdir_p(project_name .. "/src")
        mkdir_p(project_name .. "/tests")
        -- Copy local lumos folder if present
        local function copy_dir(src, dst)
            for file in lfs.dir(src) do
                if file ~= "." and file ~= ".." then
                    local src_path = src .. "/" .. file
                    local dst_path = dst .. "/" .. file
                    local attr = lfs.attributes(src_path)
                    if attr.mode == "directory" then
                        mkdir_p(dst_path)
                        copy_dir(src_path, dst_path)
                    else
                        local fsrc = io.open(src_path, "rb")
                        local fdst = io.open(dst_path, "wb")
                        if fsrc and fdst then
                            fdst:write(fsrc:read("*a"))
                            fsrc:close()
                            fdst:close()
                        end
                    end
                end
            end
        end
        if lfs.attributes("./lumos", "mode") == "directory" then
            mkdir_p(project_name .. "/src/lumos")
            copy_dir("./lumos", project_name .. "/src/lumos")
        end
        write_file(project_name .. "/src/main.lua", get_main_template(project_name, description))
        write_file(project_name .. "/src/app.lua", get_module_template(project_name, description))
        write_file(project_name .. "/tests/app_spec.lua", get_test_template(project_name))
        write_file(project_name .. "/README.md", get_readme_template(project_name))
        print(color.green("Lumos CLI project created in " .. project_name .. ". To run:\n  lua src/main.lua greet Alice"))
        return true
    end)

app:run(arg)
