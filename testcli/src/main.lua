#!/usr/bin/env lua
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
