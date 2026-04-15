#!/usr/bin/env lua

-- Demonstration of the Lumos Table module
-- Shows various table formatting capabilities

-- Add parent directory to search path
package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local tbl = require('lumos.table')
local format = require('lumos.format')

local logger = require('lumos.logger')
local app = lumos.new_app({
    name = "table_demo",
    version = "0.2.2",
    description = "Demonstrates the Lumos table module"
})

app:command("demo", "Run the table demo"):action(function(ctx)
    print("=== Demonstration of the Lumos Table module ===\n")

    local data = {
        {Name = "Alice", Age = 30, Score = 95.5},
        {Name = "Bob", Age = 25, Score = 87.2},
        {Name = "Carol", Age = 28, Score = 92.3},
    }

    -- Basic Table
    print("Basic Table:\n")
    print(tbl.simple(data))
    print()

    -- Table with Headers and Alignment
    local options = {
        headers = {"Name", "Age", "Score"},
        align = {"left", "right", "center"}
    }
    print("Table with Headers and Alignment:\n")
    print(tbl.create(data, options))
    print()

    -- Key-Value Table
    local kv_data = {
        Alice = 95.5,
        Bob = 87.2,
        Carol = 92.3
    }
    print("Key-Value Table:\n")
    print(tbl.key_value(kv_data))
    print()

    -- Boxed Table
    local box_data = {"Row 1", "Row 2", "Row 3"}
    print("Boxed Table:\n")
    print(tbl.boxed(box_data, {header="Header", footer="Footer", align="center", large=true}))
    print()

    -- Styled Table Example
    local styled_options = {
        headers = {"Name", "Age", "Score"},
        align = {"left", "right", "center"},
        border = {
            top_left = "╔", top_right = "╗", bottom_left = "╚", bottom_right = "╝",
            horizontal = "═", vertical = "║", cross = "╬",
            top_tee = "╦", bottom_tee = "╩", left_tee = "╠", right_tee = "╣"
        }
    }
    print("Styled Table:\n")
    print(tbl.create(data, styled_options))
    print()

    return true
end)

os.exit(app:run(arg))
