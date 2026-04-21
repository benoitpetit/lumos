#!/bin/bash

# Lumos CLI Framework Installation Script
# This script installs Lumos globally and configures shell paths

set -e

echo "Installing Lumos CLI Framework..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect shell
SHELL_NAME=$(basename "$SHELL")
SHELL_RC=""

case "$SHELL_NAME" in
    "bash")
        SHELL_RC="$HOME/.bashrc"
        ;;
    "zsh")
        SHELL_RC="$HOME/.zshrc"
        ;;
    "fish")
        SHELL_RC="$HOME/.config/fish/config.fish"
        ;;
    *)
        echo -e "${YELLOW}Warning: Unsupported shell '$SHELL_NAME'. You may need to manually configure PATH.${NC}"
        SHELL_RC="$HOME/.profile"
        ;;
esac

# Check if Lua and LuaRocks are installed
if ! command -v lua &> /dev/null; then
    echo -e "${RED}Error: Lua is not installed. Please install Lua 5.1 or later.${NC}"
    echo "On Debian/Ubuntu: sudo apt-get install lua5.1"
    echo "On CentOS/RHEL: sudo yum install lua"
    echo "On macOS: brew install lua"
    exit 1
fi

if ! command -v luarocks &> /dev/null; then
    echo -e "${RED}Error: LuaRocks is not installed. Please install LuaRocks >= 3.8.${NC}"
    echo "On Debian/Ubuntu: sudo apt-get install luarocks"
    echo "On CentOS/RHEL: sudo yum install luarocks"
    echo "On macOS: brew install luarocks"
    exit 1
fi

# Check LuaRocks version
LUAROCKS_VERSION=$(luarocks --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
REQUIRED_VERSION="3.8.0"
if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$LUAROCKS_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo -e "${RED}Error: LuaRocks version $LUAROCKS_VERSION is too old. Version >= 3.8 is required.${NC}"
    exit 1
fi

# Detect if installation is running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Running as root. Installing globally.${NC}"
else
    echo -e "${BLUE}Installing locally for current user.${NC}"
fi

echo -e "${BLUE}✓ Lua and LuaRocks found${NC}"

# Install dependencies
echo -e "${BLUE}Installing dependencies...${NC}"
luarocks install --local luafilesystem || {
    echo -e "${RED}Failed to install luafilesystem${NC}"
    echo -e "${YELLOW}Please ensure LuaRocks is properly configured${NC}"
    exit 1
}

# Install Lumos
echo -e "${BLUE}Installing Lumos framework...${NC}"
if [ -f "lumos-0.3.6-1.rockspec" ]; then
    # Install from local source directory (production build)
    luarocks make --local lumos-0.3.6-1.rockspec || {
        echo -e "${RED}Failed to install Lumos from production rockspec${NC}"
        exit 1
    }
elif [ -f "lumos-dev-1.rockspec" ]; then
    # Install from local development directory
    echo -e "${YELLOW}Using development rockspec${NC}"
    luarocks make --local lumos-dev-1.rockspec || {
        echo -e "${RED}Failed to install Lumos from development rockspec${NC}"
        exit 1
    }
else
    # Install from LuaRocks repository
    luarocks install --local lumos || {
        echo -e "${RED}Failed to install Lumos from LuaRocks repository${NC}"
        echo -e "${YELLOW}If running from source, ensure rockspec files are present${NC}"
        exit 1
    }
fi

echo -e "${GREEN}✓ Lumos installed successfully${NC}"

# Configure shell PATH
LUA_VERSION=$(lua -v | awk '{print $2}' | cut -d. -f1,2)
LUAROCKS_BIN="$HOME/.luarocks/bin"
LUAROCKS_LUA_PATH="$HOME/.luarocks/share/lua/$LUA_VERSION"

# Function to add path if not already present
add_to_path() {
    local path_to_add="$1"
    local rc_file="$2"
    local path_export="export PATH=\"$path_to_add:\$PATH\""
    
    if [ -f "$rc_file" ] && grep -q "$path_to_add" "$rc_file"; then
        echo -e "${YELLOW}PATH already configured in $rc_file${NC}"
    else
        echo -e "${BLUE}Adding $path_to_add to PATH in $rc_file${NC}"
        echo "" >> "$rc_file"
        echo "# Added by Lumos installer" >> "$rc_file"
        echo "$path_export" >> "$rc_file"
    fi
}

# Function to add Lua path if not already present
add_lua_path() {
    local rc_file="$1"
    local lua_path_export="export LUA_PATH=\"$LUAROCKS_LUA_PATH/?.lua;$LUAROCKS_LUA_PATH/?/init.lua;\$LUA_PATH\""
    
    if [ -f "$rc_file" ] && grep -q "LUA_PATH.*luarocks" "$rc_file"; then
        echo -e "${YELLOW}LUA_PATH already configured in $rc_file${NC}"
    else
        echo -e "${BLUE}Adding LuaRocks Lua path to $rc_file${NC}"
        echo "$lua_path_export" >> "$rc_file"
    fi
}

# Configure shell profile
if [ "$SHELL_NAME" = "fish" ]; then
    # Fish shell has different syntax
    FISH_CONFIG="$HOME/.config/fish/config.fish"
    mkdir -p "$(dirname "$FISH_CONFIG")"
    
    if ! grep -q "$LUAROCKS_BIN" "$FISH_CONFIG" 2>/dev/null; then
        echo -e "${BLUE}Configuring Fish shell...${NC}"
        echo "" >> "$FISH_CONFIG"
        echo "# Added by Lumos installer" >> "$FISH_CONFIG"
        echo "set -gx PATH $LUAROCKS_BIN \$PATH" >> "$FISH_CONFIG"
        echo "set -gx LUA_PATH \"$LUAROCKS_LUA_PATH/?.lua;$LUAROCKS_LUA_PATH/?/init.lua;\$LUA_PATH\"" >> "$FISH_CONFIG"
    fi
else
    # Bash/Zsh configuration
    add_to_path "$LUAROCKS_BIN" "$SHELL_RC"
    add_lua_path "$SHELL_RC"
fi

# Create a system-wide installation option
echo -e "${BLUE}Creating system-wide launcher...${NC}"
SYSTEM_BIN="/usr/local/bin/lumos"
if [ -w "/usr/local/bin" ]; then
    cat > "$SYSTEM_BIN" << EOF
#!/bin/bash
# Lumos CLI global launcher
export PATH="\$HOME/.luarocks/bin:\$PATH"
export LUA_PATH="\$HOME/.luarocks/share/lua/$LUA_VERSION/?.lua;\$HOME/.luarocks/share/lua/$LUA_VERSION/?/init.lua:\$LUA_PATH"
exec "\$HOME/.luarocks/bin/lumos" "\$@"
EOF
    chmod +x "$SYSTEM_BIN"
    echo -e "${GREEN}✓ System-wide launcher created at $SYSTEM_BIN${NC}"
else
    echo -e "${YELLOW}Warning: Cannot create system-wide launcher. Run with sudo for system-wide installation.${NC}"
fi

# Test installation
echo -e "${BLUE}Testing installation...${NC}"
export PATH="$LUAROCKS_BIN:$PATH"
export LUA_PATH="$LUAROCKS_LUA_PATH/?.lua;$LUAROCKS_LUA_PATH/?/init.lua:$LUA_PATH"

if "$LUAROCKS_BIN/lumos" version &>/dev/null; then
    echo -e "${GREEN}Installation successful!${NC}"
    echo ""
    echo -e "${GREEN}Lumos CLI Framework is now installed!${NC}"
    echo ""
    echo -e "${BLUE}To start using Lumos:${NC}"
    echo "1. Restart your terminal or run: source $SHELL_RC"
    echo "2. Create a new project: lumos new my-awesome-cli"
    echo "3. Check the documentation: lumos --help"
    echo ""
    echo -e "${BLUE}Quick start:${NC}"
    echo "  lumos new hello-world"
    echo "  cd hello-world"
    echo "  make install"
    echo "  make run"
else
    echo -e "${RED}Installation test failed. Please check the installation manually.${NC}"
    exit 1
fi
