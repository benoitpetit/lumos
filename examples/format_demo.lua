#!/usr/bin/env lua

-- Demonstration of the Lumos format module
-- Shows ANSI text formatting capabilities (styles only)

-- Add parent directory to search path
package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local format = require('lumos.format')
local color = require('lumos.color')
local tbl = require('lumos.table')

local logger = require('lumos.logger')
local app = lumos.new_app({
    name = "format_demo",
    version = "0.2.2",
    description = "Demonstrates the Lumos format module"
})

app:command("demo", "Run the format demo"):action(function(ctx)
    print("=== Demonstration of the Lumos Format module ===\n")
    print("This module handles ANSI text formatting (styles only)")
    print("For colors, use lumos.color; for tables, use lumos.table\n")

    -- Basic text styles
    print("Basic text styles:")
    print("• " .. format.bold("Bold text"))
    print("• " .. format.italic("Italic text"))
    print("• " .. format.underline("Underlined text"))
    print("• " .. format.strikethrough("Strikethrough text"))
    print("• " .. format.dim("Dimmed text"))
    print("• " .. format.reverse("Reversed text"))
    print("• " .. format.hidden("Hidden text (you shouldn't see this)"))
    print()

    -- Template formatting
    print("Template formatting:")
    print(format.format("{bold}This is bold{reset} and {italic}this is italic{reset}"))
    print(format.format("{underline}Underlined{reset} and {strikethrough}strikethrough{reset}"))
    print()

    -- Combined styles
    print("Combined styles:")
    print("• " .. format.bold(format.underline("Bold + Underline")))
    print("• " .. format.italic(format.dim("Italic + Dim")))
    print()

    -- Text transformations
    print("Text transformations:")
    print("• uppercase: " .. format.uppercase("hello world"))
    print("• lowercase: " .. format.lowercase("HELLO WORLD"))
    print("• capitalize: " .. format.capitalize("hello world"))
    print("• title: " .. format.title_case("hello world"))
    print()

    -- Padding
    print("Padding:")
    print("• left:  [" .. format.pad_left("hi", 10) .. "]")
    print("• right: [" .. format.pad_right("hi", 10) .. "]")
    print("• center:[" .. format.pad_center("hi", 10) .. "]")
    print()

    -- Truncation
    print("Truncation:")
    print("• " .. format.truncate("This is a very long text", 15))
    print("• " .. format.truncate("Short", 15))
    print()

    -- Word wrap
    print("Word wrap:")
    local wrapped = format.wrap("This is a demonstration of the word wrap functionality in the Lumos format module.", 30)
    for _, line in ipairs(wrapped) do
        print("  " .. line)
    end
    print()

    -- Table formatting integration
    print("Table formatting integration:")
    local data = {
        {Style = "Bold", Example = format.bold("Bold")},
        {Style = "Italic", Example = format.italic("Italic")},
        {Style = "Underline", Example = format.underline("Underline")}
    }
    print(tbl.create(data, {headers = {"Style", "Example"}}))
    print()

    -- Status display
    print("Status display:")
    print("• " .. format.bold(color.green("✓ Success")))
    print("• " .. format.bold(color.red("✗ Error")))
    print("• " .. format.dim(color.yellow("⚠ Warning")))
    print()

    -- Enable/disable demonstration
    print("Enable/disable test:")
    print("With formatting: " .. format.bold("Bold text"))
    format.disable()
    print("Without formatting: " .. format.bold("Bold text"))
    format.enable()
    print("With formatting: " .. format.bold("Bold text"))

    return true
end)

os.exit(app:run(arg))
