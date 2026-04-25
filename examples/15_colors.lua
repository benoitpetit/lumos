#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local color = require("lumos.color")

print("=== Lumos Color Palette ===\n")

local colors = {
    {"black", color.black},
    {"red", color.red},
    {"green", color.green},
    {"yellow", color.yellow},
    {"blue", color.blue},
    {"magenta", color.magenta},
    {"cyan", color.cyan},
    {"white", color.white},
    {"dim", color.dim},
    {"bold", color.bold},
    {"underline", color.underline}
}

for _, pair in ipairs(colors) do
    local name, fn = pair[1], pair[2]
    print(string.format("  %-12s %s", name, fn(name)))
end

print("\n=== Backgrounds ===\n")

local backgrounds = {
    {"bg_black", color.bg_black},
    {"bg_red", color.bg_red},
    {"bg_green", color.bg_green},
    {"bg_yellow", color.bg_yellow},
    {"bg_blue", color.bg_blue},
    {"bg_magenta", color.bg_magenta},
    {"bg_cyan", color.bg_cyan},
    {"bg_white", color.bg_white}
}

for _, pair in ipairs(backgrounds) do
    local name, fn = pair[1], pair[2]
    print(string.format("  %-12s %s", name, fn(name)))
end

print("\n=== Bold Colors ===\n")

local bold_colors = {
    {"bold_red", color.red, true},
    {"bold_green", color.green, true},
    {"bold_yellow", color.yellow, true},
    {"bold_blue", color.blue, true}
}

for _, triple in ipairs(bold_colors) do
    local name, fn = triple[1], triple[2]
    local styled = color.bold(fn(name))
    print(string.format("  %-12s %s", name, styled))
end

print("\n=== Combined Styles ===\n")

local combined = {
    {"bold + underline", color.bold(color.underline("Important Text"))},
    {"red + bold", color.bold(color.red("Error"))},
    {"green + bold", color.bold(color.green("Success"))},
    {"yellow + dim", color.dim(color.yellow("Warning"))},
    {"cyan + underline", color.underline(color.cyan("Link"))}
}

for _, pair in ipairs(combined) do
    print(string.format("  %-20s %s", pair[1], pair[2]))
end

print("\n=== Context Examples ===\n")

print(color.bold("Status Indicators:"))
print(string.format("  %s  Success", color.green("✓")))
print(string.format("  %s  Error", color.red("✗")))
print(string.format("  %s  Warning", color.yellow("⚠")))
print(string.format("  %s  Info", color.cyan("ℹ")))

print("\nLog Levels:")
print(string.format("  %s  TRACE", color.dim("trace")))
print(string.format("  %s  DEBUG", color.magenta("debug")))
print(string.format("  %s  INFO", color.green("info")))
print(string.format("  %s  WARN", color.yellow("warn")))
print(string.format("  %s  ERROR", color.red("error")))

print("\nFile Types:")
print(string.format("  %s  .lua", color.cyan("script")))
print(string.format("  %s  .md", color.white("docs")))
print(string.format("  %s  .json", color.yellow("config")))

print("\n=== Utility Functions ===\n")

print("strip:     '" .. color.dim("[demo]") .. "' -> '" .. color.strip(color.dim("[demo]")) .. "'")
print("is_enabled: " .. tostring(color.is_enabled()))
print("256 color support: " .. (color.set256 or "N/A"))

print("\n=== Dynamic Styling ===\n")

local function status_color(success)
    return success and color.green or color.red
end

for i = 1, 5 do
    local success = (i % 2 == 0)
    local fn = status_color(success)
    print(string.format("  Task %d: %s", i, fn(success and "PASS" or "FAIL")))
end