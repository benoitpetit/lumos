#!/usr/bin/env bash
set -euo pipefail

# Build precompiled launchers for lumos package
# Supports: linux-x86_64 (static via musl-gcc or gcc)
#           windows-x86_64 (cross-compile via mingw-w64)
# macOS launchers must be built on a Mac (see build-launchers-macos.sh or CI).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LAUNCHERS_DIR="$PROJECT_ROOT/runtime"
LUA_VERSION="${LUA_VERSION:-5.3.6}"
LUA_URL="https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz"
BUILD_DIR="${BUILD_DIR:-/tmp/lumos-launcher-build}"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download Lua sources if not present
if [ ! -d "lua-${LUA_VERSION}" ]; then
    echo "Downloading Lua ${LUA_VERSION} sources..."
    curl -L -R -O "$LUA_URL"
    tar zxf "lua-${LUA_VERSION}.tar.gz"
fi

LUA_SRC="$BUILD_DIR/lua-${LUA_VERSION}"

echo "============================================"
echo "Building runtime launchers in $LAUNCHERS_DIR"
echo "============================================"

# --- Linux x86_64 (static) ---
build_linux() {
    echo ""
    echo "--- Building linux-x86_64 launcher ---"
    local CC="gcc"
    local STATIC_FLAGS=""
    if command -v musl-gcc &>/dev/null; then
        CC="musl-gcc"
        STATIC_FLAGS="-static"
    else
        echo "Warning: musl-gcc not found, falling back to gcc (may not be fully static)"
        STATIC_FLAGS="-static"
    fi

    $CC $STATIC_FLAGS -O2 "$LAUNCHERS_DIR/launcher.c" -o "$LAUNCHERS_DIR/lumos-launcher-linux-x86_64" \
        /usr/lib/x86_64-linux-gnu/liblua5.3.a -lm -I/usr/include/lua5.3

    echo "linux-x86_64 launcher built."
}

# --- Windows x86_64 (cross-compile) ---
build_windows() {
    echo ""
    echo "--- Building windows-x86_64 launcher ---"
    local MINGW_CC="x86_64-w64-mingw32-gcc"
    if ! command -v "$MINGW_CC" &>/dev/null; then
        echo "Error: $MINGW_CC not found. Install gcc-mingw-w64-x86-64 (Debian/Ubuntu) or mingw-w64-gcc (Arch/Fedora)."
        exit 1
    fi

    # Build Windows liblua.a
    cd "$LUA_SRC"
    make clean || true
    make mingw CC="$MINGW_CC"

    cd "$BUILD_DIR"
    $MINGW_CC -static -O2 "$LAUNCHERS_DIR/launcher.c" -o "$LAUNCHERS_DIR/lumos-launcher-windows-x86_64" \
        "$LUA_SRC/src/liblua.a" -I"$LUA_SRC/src" -lm

    # Install cross-compiled lib and headers for native_build
    mkdir -p "$LAUNCHERS_DIR/lib/windows-x86_64/include"
    cp "$LUA_SRC/src/liblua.a" "$LAUNCHERS_DIR/lib/windows-x86_64/"
    cp "$LUA_SRC/src/"*.h "$LAUNCHERS_DIR/lib/windows-x86_64/include/"

    echo "windows-x86_64 launcher built."
}

# --- macOS ---
build_macos() {
    echo ""
    echo "--- macOS launchers cannot be built on Linux ---"
    echo "To build darwin launchers, run the following on a Mac with Xcode Command Line Tools:"
    echo ""
    echo "  # For Intel Macs:"
    echo "  cc -O2 launcher.c -o lumos-launcher-darwin-x86_64 \\"
    echo "      /usr/local/lib/liblua5.3.a -lm -I/usr/local/include/lua5.3"
    echo ""
    echo "  # For Apple Silicon Macs:"
    echo "  cc -O2 launcher.c -o lumos-launcher-darwin-aarch64 \\"
    echo "      /opt/homebrew/lib/liblua5.3.a -lm -I/opt/homebrew/include/lua5.3"
    echo ""
    echo "Or use the GitHub Actions workflow .github/workflows/build-launchers.yml"
}

# Parse arguments
TARGET="${1:-all}"

case "$TARGET" in
    linux)
        build_linux
        ;;
    windows)
        build_windows
        ;;
    macos)
        build_macos
        ;;
    all)
        build_linux
        build_windows
        build_macos
        ;;
    *)
        echo "Usage: $0 [linux|windows|macos|all]"
        exit 1
        ;;
esac

echo ""
echo "============================================"
echo "Stub build complete."
ls -la "$LAUNCHERS_DIR"/lumos-launcher-*
echo "============================================"
