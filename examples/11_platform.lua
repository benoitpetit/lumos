#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")
local platform = require("lumos.platform")

local app = lumos.new_app({
    name = "platform_demo",
    version = "1.0.0",
    description = "Cross-platform utilities"
})

local info = app:command("info", "Platform information")

info:action(function(ctx)
    print(color.bold("=== Platform Information ===\n"))

    print("OS:         " .. color.cyan(platform.os()))
    print("Arch:       " .. color.cyan(platform.arch()))
    print("Type:       " .. color.cyan(platform.type()))
    print("Version:    " .. color.cyan(platform.version() or "unknown"))
    print("Release:    " .. color.cyan(platform.release() or "unknown"))

    print()
    print("Is Windows: " .. color.yellow(tostring(platform.is_windows())))
    print("Is macOS:   " .. color.yellow(tostring(platform.is_macos())))
    print("Is Linux:   " .. color.yellow(tostring(platform.is_linux())))
    print("Is Unix:    " .. color.yellow(tostring(platform.is_unix())))

    print()
    print("Has Colors: " .. color.yellow(tostring(platform.has_colors())))
    print("Is TTY:     " .. color.yellow(tostring(platform.is_tty())))
    print("Terminal:   " .. color.cyan(os.getenv("TERM") or "unknown"))

    print()
    print("PID:        " .. color.cyan(tostring(platform.get_pid())))

    local home = os.getenv("HOME") or os.getenv("USERPROFILE") or "unknown"
    print("Home Dir:   " .. color.cyan(home))

    return true
end)

local detect = app:command("detect", "Auto-detection features")

detect:action(function(ctx)
    print(color.bold("=== Feature Detection ===\n"))

    local features = {
        {"Colors", platform.has_colors()},
        {"Interactive TTY", platform.is_tty()},
        {"File System", platform.is_windows() or platform.is_unix()},
        {"Shell", platform.is_windows() and "cmd/powershell" or "bash"},
        {"Unicode", true}
    }

    for _, feat in ipairs(features) do
        local status = feat[2] and color.green("✓ supported") or color.red("✗ not supported")
        print(string.format("  %-20s %s", feat[1], status))
    end

    return true
end)

local paths = app:command("paths", "Platform paths")

paths:action(function(ctx)
    print(color.bold("=== Platform Paths ===\n"))

    local is_win = platform.is_windows()

    print(string.format("  Path Separator: %s", color.cyan(is_win and "\\" or "/")))
    print(string.format("  Line Ending:     %s", color.cyan(is_win and "\\r\\n" or "\\n")))
    print(string.format("  Current Dir:     %s", color.cyan(platform.current_dir() or ".")))
    print(string.format("  Temp Dir:        %s", color.cyan(platform.temp_dir() or "/tmp")))

    return true
end)

os.exit(app:run(arg))