#!/usr/bin/env lua

-- Demonstration of the Lumos format module
-- Shows ANSI text formatting capabilities (styles only)

-- Add parent directory to search path
package.path = package.path .. ";../?.lua;../?/init.lua;"

local format = require('lumos.format')
local color = require('lumos.color')
local tbl = require('lumos.table')

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
print(format.format("{underline}Underlined{reset} with {strikethrough}strikethrough{reset}"))
print(format.format("{dim}Dimmed text{reset} and {reverse}reversed text{reset}"))
print()

-- Text manipulation functions
print("Text truncation:")
local long_text = "This is a very long text that needs to be truncated"
print("Original: " .. long_text)
print("Truncated (20): " .. format.truncate(long_text, 20))
print("Truncated (30): " .. format.truncate(long_text, 30))
print("Custom ellipsis: " .. format.truncate(long_text, 25, " [...]"))
print()

print("Word wrapping:")
local wrap_text = "This is a long sentence that should be wrapped to multiple lines when displayed in a narrow terminal"
print("Original: " .. wrap_text)
print("\nWrapped to 30 characters:")
local wrapped = format.wrap(wrap_text, 30)
for i, line in ipairs(wrapped) do
  print(string.format("%2d: %s", i, line))
end
print()

print("Case transformations:")
local test_text = "hello_world_test"
print("Original: " .. test_text)
print("Title Case: " .. format.title_case(test_text))
print("Camel Case: " .. format.camel_case(test_text))
print("Snake Case: " .. format.snake_case("HelloWorldTest"))
print("Kebab Case: " .. format.kebab_case("HelloWorldTest"))
print()

-- Combining formats with colors
print("Combining formats with colors:")
print(color.red(format.bold("Bold Red Text")))
print(color.green(format.italic("Italic Green Text")))
print(color.blue(format.underline("Underlined Blue Text")))
print(color.yellow(format.strikethrough("Strikethrough Yellow Text")))
print()

-- Format combining
print("Format combining:")
print("Combined formats: " .. format.combine("Important Text", "bold", "underline"))
print("Function combining: " .. format.combine("Styled Text", format.italic, format.reverse))
print()

-- Practical examples with other modules
print("Practical examples combining with other modules:")

-- Table with formatted headers (using lumos.table)
local data = {
    {Name = "Alice", Status = "Active", Score = 95},
    {Name = "Bob", Status = "Inactive", Score = 87},
    {Name = "Carol", Status = "Active", Score = 92}
}

print("\nTable with formatted headers:")
local formatted_data = {}
for _, row in ipairs(data) do
    table.insert(formatted_data, {
        Name = format.bold(row.Name),
        Status = row.Status == "Active" and format.underline(row.Status) or format.dim(row.Status),
        Score = row.Score > 90 and format.bold(tostring(row.Score)) or tostring(row.Score)
    })
end
print(tbl.simple(formatted_data, {headers = {"Name", "Status", "Score"}}))
print()

-- Status messages
print("Status messages:")
local function status_message(level, message)
    local prefix = string.format("[%s]", level:upper())
    local formatted_prefix
    
    if level == "error" then
        formatted_prefix = format.bold(format.reverse(prefix))
    elseif level == "warning" then
        formatted_prefix = format.bold(prefix)
    elseif level == "success" then
        formatted_prefix = format.reverse(prefix)
    else
        formatted_prefix = format.dim(prefix)
    end
    
    return formatted_prefix .. " " .. message
end

print(status_message("error", "Database connection failed"))
print(status_message("warning", "Configuration file not found, using defaults"))
print(status_message("success", "File saved successfully"))
print(status_message("info", "Processing data..."))
print()

-- Using format with color status messages
print("Using format with color for status messages:")
local function status_message(level, message)
    local prefix = string.format("[%s]", level:upper())
    local styled_prefix
    
    if level == "error" then
        styled_prefix = color.red(format.bold(prefix))
    elseif level == "warning" then
        styled_prefix = color.yellow(format.underline(prefix))
    elseif level == "success" then
        styled_prefix = color.green(format.reverse(prefix))
    else
        styled_prefix = color.blue(format.dim(prefix))
    end
    
    return styled_prefix .. " " .. message
end

print(status_message("error", "Database connection failed"))
print(status_message("warning", "Configuration file not found, using defaults"))
print(status_message("success", "File saved successfully"))
print(status_message("info", "Processing data..."))
print()

-- Format state
print("Format status:")
print("• Formatting enabled: " .. (format.is_enabled() and "✓" or "✗"))
print("• Control: use LUMOS_NO_COLOR=1 or NO_COLOR=1 to disable")
print()

-- Enable/disable demonstration
print("Enable/disable test:")
print("With formatting: " .. format.bold("Bold text"))
format.disable()
print("Without formatting: " .. format.bold("Bold text"))
format.enable()
print("With formatting: " .. format.bold("Bold text"))
