#!/usr/bin/env lua
--[[
  Bump version script for Lumos.
  Usage: lua scripts/bump-version.lua <new-version>
  Example: lua scripts/bump-version.lua 0.3.4
--]]

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function write_file(path, content)
    local f = io.open(path, "w")
    if not f then error("Cannot write to " .. path) end
    f:write(content)
    f:close()
end

local function replace_in_file(path, old_ver, new_ver)
    local content = read_file(path)
    if not content then
        print("SKIP (not found): " .. path)
        return
    end
    local new_content, count = content:gsub(old_ver, new_ver)
    if count > 0 then
        write_file(path, new_content)
        print("UPDATED " .. count .. "x: " .. path)
    else
        print("SKIP (no match): " .. path)
    end
end

local new_version = arg[1]
if not new_version or new_version == "" then
    print("Usage: lua scripts/bump-version.lua <new-version>")
    os.exit(1)
end

local version_file = read_file("VERSION")
if not version_file then
    print("ERROR: VERSION file not found")
    os.exit(1)
end

local old_version = version_file:match("^%s*(%S+)%s*$")
if not old_version then
    print("ERROR: Could not parse current version from VERSION file")
    os.exit(1)
end

if old_version == new_version then
    print("New version is the same as old version (" .. old_version .. "). Nothing to do.")
    os.exit(0)
end

print("Bumping version: " .. old_version .. " -> " .. new_version)

-- Update single-source-of-truth files
write_file("VERSION", new_version .. "\n")
write_file("lumos/version.lua", '-- Lumos Version\n-- Single source of truth for the framework version.\n\nreturn "' .. new_version .. '"\n')
print("UPDATED: VERSION")
print("UPDATED: lumos/version.lua")

-- Update files that reference the old version
local files_to_update = {
    "bin/lumos",
    "lumos-dev-1.rockspec",
    "Makefile",
    "scripts/install.sh",
    "spec/init_spec.lua",
    "README.md",
    "README_FR.md",
    "docs/cli.md",
    "docs/security.md",
    "docs/use.md",
    "CHANGELOG.md",
}

for _, path in ipairs(files_to_update) do
    replace_in_file(path, old_version, new_version)
end

-- Handle rockspec rename
local old_rockspec = "lumos-" .. old_version .. "-1.rockspec"
local new_rockspec = "lumos-" .. new_version .. "-1.rockspec"
local rockspec_content = read_file(old_rockspec)
if rockspec_content then
    local updated = rockspec_content:gsub(old_version, new_version)
    write_file(new_rockspec, updated)
    os.remove(old_rockspec)
    print("RENAMED: " .. old_rockspec .. " -> " .. new_rockspec)
else
    print("WARNING: " .. old_rockspec .. " not found")
end

print("\nDone. Review the changes before committing.")
print("Suggested commit message: release: bump version to " .. new_version)
print("Suggested tag: v" .. new_version)
