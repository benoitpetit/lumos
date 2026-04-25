#!/usr/bin/env bash
set -euo pipefail

# Build precompiled launchers for lumos package
# Uses Lua 5.4.7 from source for all platforms to ensure version uniformity.
# Supports: linux-x86_64 (static via musl-gcc or gcc)
#           windows-x86_64 (cross-compile via mingw-w64)
# macOS launchers must be built on a Mac.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LAUNCHERS_DIR="$PROJECT_ROOT/runtime"
LUA_VERSION="${LUA_VERSION:-5.4.7}"
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
echo "Lua version: $LUA_VERSION"
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
        echo "Warning: musl-gcc not found, falling back to gcc"
        STATIC_FLAGS="-static"
    fi

    cd "$LUA_SRC"
    make clean || true
    make linux CC="$CC"

    cd "$BUILD_DIR"
    if ! $CC $STATIC_FLAGS -O2 "$LAUNCHERS_DIR/launcher.c" -o "$LAUNCHERS_DIR/lumos-launcher-linux-x86_64" \
        "$LUA_SRC/src/liblua.a" -lm -I"$LUA_SRC/src"; then
        if [ "$CC" = "gcc" ] && [ "$STATIC_FLAGS" = "-static" ]; then
            echo "Warning: static gcc build failed, retrying without -static"
            $CC -O2 "$LAUNCHERS_DIR/launcher.c" -o "$LAUNCHERS_DIR/lumos-launcher-linux-x86_64" \
                "$LUA_SRC/src/liblua.a" -lm -I"$LUA_SRC/src"
        else
            echo "Error: failed to build linux launcher"
            exit 1
        fi
    fi

    # Install Linux static lib and headers for native_build
    mkdir -p "$LAUNCHERS_DIR/lib/linux-x86_64/include"
    cp "$LUA_SRC/src/liblua.a" "$LAUNCHERS_DIR/lib/linux-x86_64/"
    cp "$LUA_SRC/src/"*.h "$LAUNCHERS_DIR/lib/linux-x86_64/include/"

    echo "linux-x86_64 launcher built."
}

# --- Linux aarch64 (static) ---
build_linux_aarch64() {
    echo ""
    echo "--- Building linux-aarch64 launcher ---"
    local CC=""
    if [ "$(uname -m)" = "aarch64" ]; then
        CC="gcc"
        echo "Detected native aarch64 host, using gcc"
    elif command -v aarch64-linux-gnu-gcc &>/dev/null; then
        CC="aarch64-linux-gnu-gcc"
        echo "Using cross-compiler: $CC"
    else
        echo "Error: No aarch64 compiler found. Install gcc on an aarch64 host, or aarch64-linux-gnu-gcc for cross-compilation."
        exit 1
    fi

    cd "$LUA_SRC"
    make clean || true
    make linux CC="$CC"

    cd "$BUILD_DIR"
    if ! $CC -static -O2 "$LAUNCHERS_DIR/launcher.c" -o "$LAUNCHERS_DIR/lumos-launcher-linux-aarch64" \
        "$LUA_SRC/src/liblua.a" -lm -I"$LUA_SRC/src"; then
        echo "Warning: static build failed, retrying without -static"
        if ! $CC -O2 "$LAUNCHERS_DIR/launcher.c" -o "$LAUNCHERS_DIR/lumos-launcher-linux-aarch64" \
            "$LUA_SRC/src/liblua.a" -lm -I"$LUA_SRC/src"; then
            echo "Error: failed to build linux-aarch64 launcher"
            exit 1
        fi
    fi

    # Install Linux aarch64 static lib and headers for native_build
    mkdir -p "$LAUNCHERS_DIR/lib/linux-aarch64/include"
    cp "$LUA_SRC/src/liblua.a" "$LAUNCHERS_DIR/lib/linux-aarch64/"
    cp "$LUA_SRC/src/"*.h "$LAUNCHERS_DIR/lib/linux-aarch64/include/"

    echo "linux-aarch64 launcher built."
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

    cd "$LUA_SRC"
    make clean || true
    make mingw CC="$MINGW_CC"

    cd "$BUILD_DIR"
    local win_out="$LAUNCHERS_DIR/lumos-launcher-windows-x86_64"
    $MINGW_CC -static -O2 "$LAUNCHERS_DIR/launcher.c" -o "$win_out" \
        "$LUA_SRC/src/liblua.a" -I"$LUA_SRC/src" -lm

    # mingw may append .exe regardless of -o; normalize to extensionless launcher name
    if [ -f "${win_out}.exe" ]; then
        mv -f "${win_out}.exe" "$win_out"
    fi

    # Install cross-compiled lib and headers for native_build
    mkdir -p "$LAUNCHERS_DIR/lib/windows-x86_64/include"
    cp "$LUA_SRC/src/liblua.a" "$LAUNCHERS_DIR/lib/windows-x86_64/"
    cp "$LUA_SRC/src/"*.h "$LAUNCHERS_DIR/lib/windows-x86_64/include/"

    echo "windows-x86_64 launcher built."
}

# --- macOS ---
build_macos() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        echo ""
        echo "--- macOS launchers cannot be built on Linux ---"
        echo "To build darwin launchers, run the following on a Mac with Xcode Command Line Tools:"
        echo ""
        echo "  # Download and build Lua 5.4 from source first:"
        echo "  curl -L -R -O https://www.lua.org/ftp/lua-5.4.7.tar.gz"
        echo "  tar zxf lua-5.4.7.tar.gz && cd lua-5.4.7 && make macosx"
        echo ""
        echo "  # For Intel Macs:"
        echo "  cc -O2 runtime/launcher.c -o runtime/lumos-launcher-darwin-x86_64 \\"
        echo "      lua-5.4.7/src/liblua.a -lm -Ilua-5.4.7/src"
        echo ""
        echo "  # For Apple Silicon Macs:"
        echo "  cc -O2 -arch arm64 runtime/launcher.c -o runtime/lumos-launcher-darwin-aarch64 \\"
        echo "      lua-5.4.7/src/liblua.a -lm -Ilua-5.4.7/src"
        return 0
    fi

    echo ""
    echo "--- Building darwin launchers ---"

    cd "$BUILD_DIR"

    # Intel Macs
    cd "$LUA_SRC"
    make clean || true
    make macosx CC="cc -arch x86_64"

    echo "Building darwin-x86_64 launcher..."
    cc -O2 -arch x86_64 "$LAUNCHERS_DIR/launcher.c" -o "$LAUNCHERS_DIR/lumos-launcher-darwin-x86_64" \
        "$LUA_SRC/src/liblua.a" -lm -I"$LUA_SRC/src"

    # Install x86_64 static lib and headers for native_build
    mkdir -p "$LAUNCHERS_DIR/lib/darwin-x86_64/include"
    cp "$LUA_SRC/src/liblua.a" "$LAUNCHERS_DIR/lib/darwin-x86_64/"
    cp "$LUA_SRC/src/"*.h "$LAUNCHERS_DIR/lib/darwin-x86_64/include/"

    # Apple Silicon
    cd "$LUA_SRC"
    make clean || true
    make macosx CC="cc -arch arm64"

    echo "Building darwin-aarch64 launcher..."
    cc -O2 -arch arm64 "$LAUNCHERS_DIR/launcher.c" -o "$LAUNCHERS_DIR/lumos-launcher-darwin-aarch64" \
        "$LUA_SRC/src/liblua.a" -lm -I"$LUA_SRC/src"

    # Install arm64 static lib and headers for native_build
    mkdir -p "$LAUNCHERS_DIR/lib/darwin-aarch64/include"
    cp "$LUA_SRC/src/liblua.a" "$LAUNCHERS_DIR/lib/darwin-aarch64/"
    cp "$LUA_SRC/src/"*.h "$LAUNCHERS_DIR/lib/darwin-aarch64/include/"

    echo "darwin launchers built."
}

# Parse arguments
TARGET="${1:-all}"

case "$TARGET" in
    linux)
        build_linux
        ;;
    linux-aarch64)
        build_linux_aarch64
        ;;
    windows)
        build_windows
        ;;
    macos)
        build_macos
        ;;
    all)
        build_linux
        build_linux_aarch64
        build_windows
        build_macos
        ;;
    *)
        echo "Usage: $0 [linux|linux-aarch64|windows|macos|all]"
        exit 1
        ;;
esac

echo ""
echo "============================================"
echo "Launcher build complete."
ls -la "$LAUNCHERS_DIR"/lumos-launcher-*
echo "============================================"
