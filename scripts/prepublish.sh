#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Lumos Pre-publish Script
# =============================================================================
# Orchestrates the release workflow:
#   1. Prompt for new version (or accept as argument)
#   2. Bump version across source files
#   3. Sync rockspec module lists with lumos/*.lua
#   4. Run coherence checks (VERSION == version.lua, modules match)
#   5. Check for development artifacts (TODO/FIXME)
#   6. Run examples
#   7. Run test suite
#   8. Lint rockspecs
#   9. Verify runtime version reports correctly
#
# Usage:
#   ./scripts/prepublish.sh [X.Y.Z]
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

CURRENT_VERSION="$(cat VERSION | tr -d '[:space:]')"

# -----------------------------------------------------------------------------
# Get version from argument or prompt
# -----------------------------------------------------------------------------
if [ -z "${1:-}" ]; then
    echo -e "${BLUE}Current version: ${CURRENT_VERSION}${NC}"
    read -rp "Enter new version (e.g., 0.3.8): " VERSION
else
    VERSION="$1"
fi

# Validate version format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Version must be in format X.Y.Z (e.g., 0.3.8)${NC}"
    exit 1
fi

SAME_VERSION=0
if [ "$VERSION" == "$CURRENT_VERSION" ]; then
    SAME_VERSION=1
    echo -e "\n${YELLOW}Running verification for current version ${VERSION} (no bump)${NC}"
else
    echo -e "\n${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Lumos Pre-publish Script v${VERSION}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
fi
echo ""

FAIL=0

# -----------------------------------------------------------------------------
# Step 1/8: Bump version
# -----------------------------------------------------------------------------
if [ "$SAME_VERSION" -eq 1 ]; then
    echo -e "${YELLOW}Step 1/8: Version bump skipped (already at ${VERSION})${NC}"
else
    echo -e "${YELLOW}Step 1/8: Bumping version from ${CURRENT_VERSION} to ${VERSION}...${NC}"
    lua scripts/bump-version.lua "$VERSION"
    echo -e "${GREEN}✓ Version bumped to ${VERSION}${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# Step 2/8: Sync rockspec module lists
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Step 2/8: Syncing rockspec module lists...${NC}"
cat > /tmp/lumos_sync_rockspec.lua <<'LUAEOF'
local dir = arg[1]
local version = arg[2]

local function scan_modules(root)
    local p = io.popen('ls ' .. root .. '/lumos/*.lua 2>/dev/null')
    local files = {}
    for line in p:lines() do
        local name = line:match('lumos/([^/]+)%.lua$')
        if name then table.insert(files, name) end
    end
    p:close()
    table.sort(files)
    return files
end

local function update_rockspec(path, files)
    local f = io.open(path, 'r')
    if not f then print('SKIP: ' .. path); return end
    local content = f:read('*a')
    f:close()

    local start_marker = 'modules = {'
    local end_marker = 'copy_directories'
    local start_pos = content:find(start_marker, 1, true)
    local end_pos = content:find(end_marker, start_pos, true)
    if not start_pos or not end_pos then
        print('WARN: could not find markers in ' .. path)
        return
    end

    local before = content:sub(1, start_pos + #start_marker - 1)
    local after_pos = content:find('},', end_pos - 30, true)
    if not after_pos then after_pos = content:find('}', end_pos - 10, true) end
    if not after_pos then
        print('WARN: could not find closing brace in ' .. path)
        return
    end
    local after = content:sub(after_pos)

    local lines = {}
    for _, name in ipairs(files) do
        local key = name == 'init' and 'lumos' or 'lumos.' .. name
        table.insert(lines, string.format('      ["%s"] = "lumos/%s.lua",', key, name))
    end

    local out = io.open(path, 'w')
    out:write(before .. '\n' .. table.concat(lines, '\n') .. '\n   ' .. after)
    out:close()
    print('UPDATED: ' .. path)
end

local files = scan_modules(dir)
update_rockspec(dir .. '/lumos-dev-1.rockspec', files)
update_rockspec(dir .. '/lumos-' .. version .. '-1.rockspec', files)
LUAEOF

lua /tmp/lumos_sync_rockspec.lua "$PROJECT_DIR" "$VERSION"
echo -e "${GREEN}✓ Rockspecs synchronized${NC}\n"

# -----------------------------------------------------------------------------
# Step 3/8: Coherence checks
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Step 3/8: Running coherence checks...${NC}"

# VERSION == version.lua
LUA_VERSION=$(lua -e "print(require('lumos.version'))")
if [ "$LUA_VERSION" != "$VERSION" ]; then
    echo -e "  ${RED}✗ version.lua ($LUA_VERSION) != VERSION ($VERSION)${NC}"
    FAIL=1
else
    echo -e "  ${GREEN}✓${NC} version.lua matches VERSION"
fi

# rockspec modules == lumos/*.lua
cat > /tmp/lumos_check_modules.lua <<'LUAEOF'
local dir = arg[1]
local rockspec = arg[2]

local function rockspec_modules(path)
    local f = io.open(path, 'r')
    local content = f:read('*a')
    f:close()
    local mods = {}
    for key in content:gmatch('%["([^"]+)"%]%s*=%s*"lumos/[^"]+"') do
        local name = key == 'lumos' and 'init' or key:match('^lumos%.(.+)$')
        if name then mods[name] = true end
    end
    return mods
end

local function disk_modules(root)
    local p = io.popen('ls ' .. root .. '/lumos/*.lua 2>/dev/null')
    local mods = {}
    for line in p:lines() do
        local name = line:match('lumos/([^/]+)%.lua$')
        if name then mods[name] = true end
    end
    p:close()
    return mods
end

local disk = disk_modules(dir)
local spec = rockspec_modules(rockspec)
local missing = {}
local extra = {}

for name in pairs(disk) do
    if not spec[name] then table.insert(missing, name) end
end
for name in pairs(spec) do
    if not disk[name] then table.insert(extra, name) end
end

table.sort(missing)
table.sort(extra)

if #missing > 0 then
    print('MISSING in ' .. rockspec .. ': ' .. table.concat(missing, ', '))
end
if #extra > 0 then
    print('EXTRA in ' .. rockspec .. ': ' .. table.concat(extra, ', '))
end
if #missing == 0 and #extra == 0 then
    print('OK: modules match')
end
LUAEOF

echo -n "  "
lua /tmp/lumos_check_modules.lua "$PROJECT_DIR" "lumos-dev-1.rockspec"
echo -n "  "
lua /tmp/lumos_check_modules.lua "$PROJECT_DIR" "lumos-$VERSION-1.rockspec"
echo ""

# -----------------------------------------------------------------------------
# Step 4/8: Development artifacts
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Step 4/8: Checking for development artifacts...${NC}"
TODO_FOUND=0
TODO_COUNT=$(grep -rn --include='*.lua' -P '\b(TODO|FIXME|XXX)\b' lumos/ 2>/dev/null | wc -l) || true
if [ "$TODO_COUNT" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠${NC} Found $TODO_COUNT TODO/FIXME/XXX markers"
    grep -rn --include='*.lua' -P '\b(TODO|FIXME|XXX)\b' lumos/ 2>/dev/null | sed 's/^/    /' || true
    TODO_FOUND=1
else
    echo -e "  ${GREEN}✓${NC} No TODO/FIXME/XXX markers"
fi
echo ""

# -----------------------------------------------------------------------------
# Step 5/8: Examples
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Step 5/8: Running examples...${NC}"
if make examples >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Examples OK"
else
    echo -e "  ${YELLOW}⚠${NC} Some examples failed"
fi
echo ""

# -----------------------------------------------------------------------------
# Step 6/8: Test suite
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Step 6/8: Running test suite...${NC}"
if make test >/tmp/test.log 2>&1; then
    echo -e "  ${GREEN}✓${NC} All tests passed"
else
    echo -e "  ${RED}✗${NC} Tests failed"
    tail -20 /tmp/test.log
    FAIL=1
fi
echo ""

# -----------------------------------------------------------------------------
# Step 7/8: Lint rockspecs
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Step 7/8: Linting rockspecs...${NC}"
if make check-rockspec >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Rockspecs valid"
else
    echo -e "  ${RED}✗${NC} Rockspec lint failed"
    FAIL=1
fi
echo ""

# -----------------------------------------------------------------------------
# Step 8/8: Verify runtime version
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Step 8/8: Verifying runtime version...${NC}"
RUNTIME_VERSION=$(lua -e "print(require('lumos.version'))")
if [ "$RUNTIME_VERSION" == "$VERSION" ]; then
    echo -e "  ${GREEN}✓${NC} Runtime reports correct version: ${RUNTIME_VERSION}"
else
    echo -e "  ${RED}✗${NC} Runtime version mismatch: ${RUNTIME_VERSION} (expected ${VERSION})"
    FAIL=1
fi
echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
if [ "$FAIL" -eq 0 ]; then
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Pre-publish completed successfully!${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}\n"

    echo -e "Summary:"
    echo -e "  - Version: ${GREEN}${VERSION}${NC}"
    echo -e "  - Coherence: ${GREEN}OK${NC}"
    echo -e "  - Tests: ${GREEN}PASS${NC}"
    echo -e "  - Rockspecs: ${GREEN}VALID${NC}"
    echo -e "  - Runtime: ${GREEN}OK${NC}\n"

    CHANGED=$(git diff --name-only 2>/dev/null | wc -l)
    if [ "$CHANGED" -gt 0 ]; then
        echo -e "Modified files (${CHANGED}):"
        git diff --name-only 2>/dev/null | sed 's/^/  /'
        echo ""
    fi

    if [ "$SAME_VERSION" -eq 1 ]; then
        echo -e "${GREEN}All verification checks passed for version ${VERSION}.${NC}\n"
    fi

    echo -e "Release workflow (example commands):"
    echo ""
    echo -e "  ${YELLOW}git add -A${NC}"
    echo -e "  ${YELLOW}git commit -m \"release: Version ${VERSION}\"${NC}"
    echo -e "  ${YELLOW}git tag v${VERSION}${NC}"
    echo -e "  ${YELLOW}git push origin main --tags${NC}"
    echo ""
    echo -e "Then publish to LuaRocks:"
    echo -e "  ${YELLOW}luarocks upload lumos-${VERSION}-1.rockspec${NC}"
    echo ""

    if [ "$TODO_FOUND" -eq 1 ]; then
        echo -e "${YELLOW}Warning: TODO/FIXME markers were found. Review them before publishing if needed.${NC}\n"
    fi

    if [ "$SAME_VERSION" -eq 0 ]; then
        echo -e "${GREEN}Ready to publish!${NC}"
    fi
else
    echo -e "${RED}═══════════════════════════════════════════════════${NC}"
    echo -e "${RED}  Pre-publish failed. Fix issues above.${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════${NC}"
    exit 1
fi
