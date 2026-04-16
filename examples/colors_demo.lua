#!/usr/bin/env lua

-- Demonstration of the Lumos color module
-- Shows all coloring and styling capabilities

-- Add parent directory to search path
package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local color = require('lumos.color')
local format = require('lumos.format')

local logger = require('lumos.logger')
local app = lumos.new_app({
    name = "colors_demo",
    version = require("lumos").version,
    description = "Demonstrates the Lumos color module"
})

app:command("demo", "Run the color demo"):action(function(ctx)
    print("=== Demonstration of the Lumos Color module ===\n")

    -- Basic colors
    print("Basic colors:")
    print("• " .. color.red("Red"))
    print("• " .. color.green("Green"))
    print("• " .. color.blue("Blue"))
    print("• " .. color.yellow("Yellow"))
    print("• " .. color.magenta("Magenta"))
    print("• " .. color.cyan("Cyan"))
    print("• " .. color.black("Black"))
    print("• " .. color.format("{white}White{reset}"))
    print()

    -- Bright colors
    print("Bright colors:")
    print("• " .. color.colorize("Bright red", "bright_red"))
    print("• " .. color.colorize("Bright green", "bright_green"))
    print("• " .. color.colorize("Bright blue", "bright_blue"))
    print("• " .. color.colorize("Bright yellow", "bright_yellow"))
    print("• " .. color.colorize("Bright magenta", "bright_magenta"))
    print("• " .. color.colorize("Bright cyan", "bright_cyan"))
    print()

    -- Background colors
    print("Background colors:")
    print("• " .. color.colorize("Red background", "bg_red"))
    print("• " .. color.colorize("Green background", "bg_green"))
    print("• " .. color.colorize("Blue background", "bg_blue"))
    print("• " .. color.colorize("Yellow background", "bg_yellow"))
    print()

    -- Text styles
    print("Text styles:")
    print("• " .. format.bold("Bold text"))
    print("• " .. format.dim("Dimmed text"))
    print("• " .. format.italic("Italic text"))
    print("• " .. format.underline("Underlined text"))
    print("• " .. format.strikethrough("Strikethrough text"))
    print()

    -- Formatting with templates
    print("Formatting with templates:")
    print(color.format("{red}Error:{reset} Something went wrong"))
    print(color.format("{green}{bold}Success!{reset} The operation is finished"))
    print(color.format("{blue}Info:{reset} {dim}Additional details{reset}"))
    print(color.format("{yellow}Warning:{reset} Check your configuration"))
    print()

    -- Practical examples
    print("Practical examples:")

    local function log_message(level, message)
        local colors = {
            ERROR = "red",
            WARN = "yellow",
            INFO = "blue",
            SUCCESS = "green"
        }
        local template = "{" .. colors[level] .. "}{bold}[" .. level .. "]{reset} " .. message
        print(color.format(template))
    end

    log_message("ERROR", "Database connection failed")
    log_message("WARN", "Default configuration used")
    log_message("INFO", "Processing...")
    log_message("SUCCESS", "File saved successfully")
    print()

    -- Colored progress bar
    print("Colored progress bar:")
    local function colored_progress(percentage)
        local filled = math.floor(percentage / 2)
        local empty = 50 - filled
        local bar_color = "red"
        if percentage > 33 then bar_color = "yellow" end
        if percentage > 66 then bar_color = "green" end
        local bar = string.rep("█", filled) .. string.rep("░", empty)
        return color.format("[{" .. bar_color .. "}" .. bar .. "{reset}] " .. percentage .. "%")
    end

    for i = 0, 100, 25 do
        print(colored_progress(i))
    end
    print()

    -- Color status
    print("Color status:")
    print("• Colors enabled: " .. (color.is_enabled() and "✓" or "✗"))
    print("• Control: use LUMOS_NO_COLOR=1 to disable")
    print()

    -- Enable/disable test
    print("Enable/disable test:")
    print("With colors: " .. color.red("Red text"))
    color.disable()
    print("Without colors: " .. color.red("Red text"))
    color.enable()
    print("With colors: " .. color.red("Red text"))

    return true
end)

os.exit(app:run(arg))
