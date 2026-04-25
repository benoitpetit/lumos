#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")

local app = lumos.new_app({
    name = "category_demo",
    version = "1.0.0",
    description = "Demonstrates command categorization in help"
})

-- Network commands
app:command("ping", "Ping a host"):category("Network")
app:command("fetch", "Fetch a URL"):category("Network")
app:command("scan", "Scan ports"):category("Network")

-- Storage commands
app:command("backup", "Backup data"):category("Storage")
app:command("restore", "Restore backup"):category("Storage")
app:command("clean", "Clean old files"):category("Storage")

-- Uncategorized command
app:command("version", "Show version")

os.exit(app:run(arg))
