# Bundling & Portability

Guide for creating portable CLI applications with Lumos.

## Overview

Lumos provides **three distribution strategies**, each suited to different deployment constraints. All three are available immediately after installing Lumos via LuaRocks — no extra setup required.

### The `runtime/` Directory

When you install Lumos, a `runtime/` directory is copied alongside the Lua modules. It contains:

- **Precompiled launchers** (`runtime/lumos-launcher-<os>-<arch>`): Small native binaries (~250–650 KB) that embed a complete Lua interpreter. These are the foundation of `lumos package`.
- **Static libraries & headers** (`runtime/lib/<platform>/liblua.a` + `include/*.h`): Cross-compilation toolchains bundled with Lumos. `lumos build` prefers these over system libraries to guarantee version compatibility, especially when cross-compiling (e.g. building a Windows binary from Linux).
- **`launcher.c`**: The C source of the launcher, for transparency and custom builds.

> **Note:** If a launcher is missing for your target platform, Lumos can automatically download it from the corresponding GitHub Release (see `runtime_manager.sync()`).

### Three Distribution Methods

| Method | Command | What it does | Target needs Lua? | Build machine needs C compiler? |
|--------|---------|--------------|-------------------|---------------------------------|
| **Bundle** | `lumos bundle` | Amalgamates your code + dependencies into a single `.lua` file with a custom `package.searchers` preloader. | ✅ Yes | ❌ No |
| **Package** | `lumos package` | Concatenates a precompiled launcher binary + your amalgamated Lua code + a size footer. The launcher reads itself at runtime to extract and execute the Lua payload. | ❌ No | ❌ No |
| **Build** | `lumos build` | Generates a C wrapper that hex-encodes your Lua code, compiles it, and links it against the bundled `liblua.a`. Additional user C modules (e.g. `lfs`, `lpeg`, `cjson`) are statically linked when their `.a` archives are available on the build machine. Produces a true native binary. | ❌ No | ✅ Yes |

**When to choose which:**
- Use **`bundle`** when your users already have Lua installed and you want maximum transparency (plain text, debuggable).
- Use **`package`** when you need a native executable **without installing a C compiler** or dealing with build toolchains. This is the sweet spot for most users.
- Use **`build`** when you need maximum performance, want to statically link C modules (e.g. `lfs`, `lpeg`), or need fully static linking with `musl-gcc`.

### How `lumos package` Works Under the Hood

1. Your Lua entry file and all `require()` dependencies are amalgamated into a single Lua string.
2. A precompiled launcher binary (e.g. `lumos-launcher-linux-x86_64`) is read from disk.
3. The launcher binary + Lua payload + an 8-byte little-endian size footer are concatenated.
4. At runtime on the target machine, the launcher opens its own executable path, seeks to the end, reads the 8-byte footer to get the payload size, extracts the Lua code, and executes it via `luaL_loadbuffer` → `lua_pcall`.

### How `lumos build` Works Under the Hood

1. **Amalgamation** (same as bundle).
2. **Optional bytecode compilation** with `luac`.
3. **Toolchain detection**: finds `gcc`/`clang`/`mingw` and Lua headers/lib (`liblua.a`). The bundled `runtime/lib/<target>/liblua.a` is preferred to ensure version match; system libraries are used as fallback.
4. **Native module detection** (optional): scans for known C modules used by *your* application (`lfs`, `socket`, `ssl`, `cjson`, etc.). These are your own dependencies, not Lumos internals.
5. **C wrapper generation**: creates a `.c` file containing the Lua payload as a `unsigned char[]` array, plus `extern int luaopen_*` declarations and `package.preload` registrations for any detected native modules that have a static `.a` archive available.
6. **Compilation & linking**: produces the final binary. If a native module is missing its `.a` archive, the build continues and the module must be installed separately on the target machine.

---

## Requirements

- `lumos bundle`: **Lua runtime** must be installed on the target machine (Lua 5.1+). The output is a Lua script, not a native binary. Native C modules (e.g. `luafilesystem`) are *not* bundled and must be installed separately.
- `lumos build`: Produces a native binary. No Lua runtime is required on the target. By default the binary is dynamically linked to `libc`; use `--static` for a fully standalone executable. Requires a C compiler + Lua headers. Static native C modules can be linked in if their `.a` archives are available on the build machine.
- `lumos package`: Produces a standalone executable with **no C compiler required** on the build machine. The output is a precompiled launcher + your Lua payload. Native C modules cannot be included in the package.
- On **Windows**, run a bundle with `lua myapp` instead of `./myapp`. Native binaries built with `lumos build` or `lumos package` can run directly as `myapp.exe`.

## Quick Start

```bash
# Create a bundle of your application
lumos bundle src/main.lua -o dist/myapp

# The generated file can be run directly on Unix
./dist/myapp --help

# Or build a fully standalone native binary
lumos build src/main.lua -o dist/myapp
./dist/myapp --help

# Or package into a standalone executable without a C compiler
lumos package src/main.lua -o dist/myapp
./dist/myapp --help

# Cross-compile to Windows from Linux
lumos build src/main.lua -o dist/myapp -t windows-x86_64
lumos package src/main.lua -o dist/myapp -t windows-x86_64

# For macOS targets from Linux, use package (native build requires macOS host)
lumos package src/main.lua -o dist/myapp -t darwin-aarch64
```

## The `lumos bundle` Command

### Syntax

```bash
lumos bundle <entry_file> [options]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `entry_file` | Entry point file of your CLI (e.g., `src/main.lua`) |

### Options

| Option | Description |
|--------|-------------|
| `-o, --output <path>` | Output file path (default: `dist/<name>`) |
| `-d, --dir <path>` | Project directory (default: current directory) |
| `--no-lumos` | Do not bundle Lumos framework (requires Lumos on target) |
| `--strip-comments` | Remove comments to reduce file size |
| `--analyze` | Analyze dependencies without creating bundle |

## The `lumos build` Command

### Syntax

```bash
lumos build <entry_file> [options]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `entry_file` | Entry point file of your CLI (e.g., `src/main.lua`) |

### Options

| Option | Description |
|--------|-------------|
| `-o, --output <path>` | Output binary path (default: `dist/<name>`) |
| `-d, --dir <path>` | Project directory (default: current directory) |
| `-t, --target <name>` | Target platform for cross-compilation (e.g. `windows-x86_64`) |
| `--no-lumos` | Do not bundle Lumos framework |
| `--strip-comments` | Remove comments to reduce binary payload size |
| `--cc <compiler>` | Force a specific C compiler (e.g. `gcc`, `musl-gcc`) |
| `--static` | Produce a fully statically linked binary |
| `--bytecode` | Compile Lua payload to bytecode before embedding |
| `--debug-build` | Keep temporary C source file for debugging |
| `--analyze` | Analyze dependencies without building |

### How It Works

1. **Amalgamation**: `lumos build` first amalgamates your Lua code and dependencies exactly like `lumos bundle`.
2. **C Wrapper Generation**: It generates a small C program that embeds the Lua payload as a byte array and initializes a `lua_State`.
3. **Toolchain Detection**: It auto-detects your C compiler, Lua headers, and `liblua.a` static library.
4. **Static Native Modules**: If your app uses supported native C modules (e.g. `lfs`, `socket`, `ssl`, `cjson`, `lsqlite3`) and their static archives (`.a`) are found, they are linked directly into the binary and registered in `package.preload`. If a static archive is not found, the build emits a warning and continues without linking that module.
5. **Compilation**: The C wrapper is compiled and linked into a single executable.

### Cross-Platform Notes

| Platform | Architectures | Status | Notes |
|----------|--------------|--------|-------|
| **Linux** | x86_64, aarch64 | Fully supported | Both native and cross-compilation supported. Use `musl-gcc --static` for a 100% static, distro-independent binary. The bundled `runtime/lib/linux-aarch64/liblua.a` enables cross-builds from x86_64 hosts. |
| **Windows** | x86_64 | Supported | Cross-compile from Linux with `x86_64-w64-mingw32-gcc`. The bundled `runtime/lib/windows-x86_64/liblua.a` is used automatically; no need to build Lua for Windows manually. |
| **macOS** | x86_64, aarch64 | Partial | `lumos build -t darwin-*` must run on macOS hosts. From Linux, use `lumos package -t darwin-*` with a prebuilt launcher. |

## The `lumos package` Command

### Syntax

```bash
lumos package <entry_file> [options]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `entry_file` | Entry point file of your CLI (e.g., `src/main.lua`) |

### Options

| Option | Description |
|--------|-------------|
| `-o, --output <path>` | Output file path (default: `dist/<name>`) |
| `-d, --dir <path>` | Project directory (default: current directory) |
| `-t, --target <name>` | Target platform launcher (default: host platform, e.g. `linux-x86_64`) |
| `--list-targets` | List available launcher targets and exit |
| `--sync-runtime` | Download missing launchers before listing/packaging |
| `--no-lumos` | Do not bundle Lumos framework |
| `--strip-comments` | Remove comments to reduce payload size |

### How It Works

1. **Amalgamation**: `lumos package` first amalgamates your Lua code and dependencies exactly like `lumos bundle`.
2. **Launcher Selection**: It loads a precompiled launcher binary for the requested target platform. The launcher already contains a statically linked Lua interpreter.
3. **Concatenation**: The launcher binary, the Lua payload, and an 8-byte size footer are concatenated into a single file.
4. **Execution**: At runtime, the launcher opens its own executable file, reads the size footer, extracts the Lua payload, and executes it via `luaL_loadbuffer`.

### Stubs

Launchers are precompiled binaries stored in the `runtime/` directory of the Lumos installation. The following launchers are currently available:

- `lumos-launcher-linux-x86_64` -- Linux x86_64 (statically linked)
- `lumos-launcher-linux-aarch64` -- Linux ARM64 / aarch64 (cross-compiled from Linux x86_64 with `aarch64-linux-gnu-gcc`)
- `lumos-launcher-windows-x86_64` -- Windows x86_64 (cross-compiled from Linux)
- `lumos-launcher-darwin-x86_64` -- macOS Intel (build from source on macOS or via CI)
- `lumos-launcher-darwin-aarch64` -- macOS Apple Silicon (build from source on macOS or via CI)

All launchers are built against Lua 5.4.7 to keep runtime behavior consistent across platforms.

You can rebuild launchers from `runtime/launcher.c` using your platform's C compiler and `liblua.a`:

- `make build-launcher-linux`
- `make build-launcher-windows`
- `make build-launcher-macos` (prints instructions to run on macOS)

Or use the helper script directly:

```bash
bash scripts/build-launchers.sh all
```

### When to Use `package` vs `build`

- Use `lumos package` when you want a standalone executable **quickly** and don't have a C toolchain installed. Ideal for CI/CD pipelines and rapid distribution.
- Use `lumos build` when you need maximum control, want to embed static native C modules, or need to target a platform for which no launcher is available.

## Examples

### Basic Bundle

```bash
# Create a bundle with default values
lumos bundle src/main.lua

# Result: dist/main (self-contained Lua script)
```

### Custom Bundle

```bash
# Specify output file
lumos bundle src/main.lua -o bin/myapp

# Bundle with comment stripping
lumos bundle src/main.lua --strip-comments -o dist/myapp-min
```

### Analyze Dependencies

```bash
# See which modules will be included
lumos bundle src/main.lua --analyze

# Output:
# Analyzing dependencies for: src/main.lua
# Found 3 dependencies:
#   1. app
#      -> ./src/app.lua
#   2. config
#      -> ./src/config.lua
#   3. utils
#      -> ./src/utils.lua
#
# Lumos modules will also be bundled:
#   - lumos.init
#   - lumos.app
#   - lumos.core
#   - lumos.bundle
#   ...
```

### Native Binary Build

```bash
# Build a standalone native binary
lumos build src/main.lua -o dist/myapp

# Result: dist/myapp (native executable, no Lua required on target)
```

### Cross-Compilation to Windows

```bash
# Build a native Windows binary from Linux
lumos build src/main.lua -o dist/myapp -t windows-x86_64

# Package a Windows executable from Linux
lumos package src/main.lua -o dist/myapp -t windows-x86_64
```

### Package Build (No Compiler Required)

```bash
# List available launcher targets
lumos package --list-targets

# Package for the default target (host platform)
lumos package src/main.lua -o dist/myapp

# Package for a specific target
lumos package src/main.lua -t linux-x86_64 -o dist/myapp
```

### Build with Bytecode

```bash
# Compile Lua source to bytecode and embed it (obfuscation + smaller size)
lumos build src/main.lua -o dist/myapp --bytecode
```

### Fully Static Binary (Linux)

```bash
# Build a 100% static binary using musl
lumos build src/main.lua -o dist/myapp --static --cc musl-gcc

# Verify it has no dynamic dependencies
ldd dist/myapp
# output: not a dynamic executable
```

### Bundle Without Lumos

If the target machine already has Lumos installed:

```bash
# Create a lightweight bundle without Lumos
lumos bundle src/main.lua --no-lumos -o dist/myapp-light
```

## Generated File Structure

The generated bundle contains:

1. **Shebang**: `#!/usr/bin/env lua` for direct execution
2. **Header**: Metadata (date, number of modules)
3. **Preloader**: Bundled module loading system
4. **Bundled Modules**: All Lumos modules and your dependencies
5. **Main Code**: Your application

```lua
#!/usr/bin/env lua

-- ============================================
-- Bundled Lua CLI Application
-- Generated by Lumos Bundle
-- Date: 2026-01-21 14:30:00
-- Modules bundled: 18
-- ============================================

-- Bundled modules preloader
local _loadcode = loadstring or load
local _BUNDLED_MODULES = {}

_BUNDLED_MODULES["lumos"] = assert(_loadcode(...))

-- ... other modules ...

-- Install bundled module loader via package.searchers / package.loaders
local _searchers = package.searchers or package.loaders
table.insert(_searchers, 1, function(name)
    if _BUNDLED_MODULES[name] then
        return function(...)
            if package.loaded[name] == nil then
                local result = _BUNDLED_MODULES[name](...)
                if result == nil then result = true end
                package.loaded[name] = result
            end
            return package.loaded[name]
        end
    end
end)

-- ============================================
-- Main Application
-- ============================================

-- Your application code...
```

## Distribution Workflow

### 1. Develop Your CLI

```bash
# Create a new project
lumos new myapp
cd myapp

# Develop and test
make test
lua src/main.lua --help
```

### 2. Create the Bundle

```bash
# Analyze first
lumos bundle src/main.lua --analyze

# Create the bundle
lumos bundle src/main.lua -o dist/myapp --strip-comments
```

### 3. Test the Bundle

```bash
# Test locally
./dist/myapp --help
./dist/myapp greet World
```

### 4. Distribute

```bash
# The file is standalone and can be copied anywhere
scp dist/myapp user@server:/usr/local/bin/

# On the server (only Lua is required)
myapp --help
```

## Limitations

### `lumos bundle` and Native C Modules

`lumos bundle` creates a Lua script, so it cannot include native C modules such as `luasocket` or `luasec`. If your application uses these, they must be installed on the target machine.

### `lumos build` and Native C Modules

`lumos build` **can** statically link native C modules when their static archives (`.a` files) are available on the build machine. Currently supported modules include:

- **Filesystem**: `lfs`
- **Networking**: `socket`, `mime`, `ssl`
- **JSON**: `cjson`, `rapidjson`, `yajl`
- **Database**: `lsqlite3`, `dbi`
- **Parsing**: `lpeg`, `lpeglabel`
- **Crypto**: `bcrypt`, `argon2`, `md5`, `sha2`, `openssl`, `ossl`
- **Compression**: `zlib`, `lz4`, `zstd`, `brotli`
- **POSIX / OS**: `posix`, `unix`, `term`, `linenoise`, `readline`, `winio`
- **System / Process**: `system`, `proc`, `spawn`, `lanes`, `pthread`
- **Events**: `ev`, `inotify`, `epoll`, `kqueue`
- **HTTP**: `curl`, `cURL`
- **Serialization**: `pb`, `struct`, `uuid`, `base64`, `cmsgpack`
- **Images**: `gd`, `vips`
- **XML**: `expat`, `xmlreader`
- **Encoding**: `iconv`, `utf8`
- **Bitwise**: `bit`, `bit32`
- **Misc**: `sysctl`, `expect`, `child`

If a static archive is not found, `lumos build` will emit a warning but still produce the binary. In that case, the binary will fail at runtime if it attempts to `require` the missing module.

### `lumos package` and Native C Modules

`lumos package` uses a precompiled launcher that only contains the Lua interpreter. It cannot include native C modules. If your app uses `lfs`, `socket`, or any other C module, `lumos package` now fails early with an explicit error and tells you to use `lumos build` instead.

### Recommendations

1. **Minimize C dependencies**: Use pure Lua modules when possible
2. **Document prerequisites**: List required C dependencies
3. **Test on a clean machine**: Verify the bundle works without Lumos

## Programmatic API

The `lumos.bundle` and `lumos.native_build` modules can also be used directly in your scripts:

```lua
local bundle = require('lumos.bundle')

-- Create a bundle
local success, err, info = bundle.create({
    entry = "src/main.lua",
    output = "dist/myapp",
    include_lumos = true,
    strip_comments = true
})

if success then
    print("Bundle created: " .. info.output)
    print("Modules: " .. info.modules_count)
    print("Size: " .. info.size .. " bytes")
else
    print("Error: " .. err)
end

-- Analyze dependencies
local modules = bundle.analyze("src/main.lua", {".", "./src"})
for _, mod in ipairs(modules) do
    print(mod.name .. " -> " .. mod.path)
end

-- List Lumos modules
local lumos_mods = bundle.get_lumos_modules()
for _, name in ipairs(lumos_mods) do
    print(name)
end

-- Build a native binary programmatically
local native_build = require('lumos.native_build')
local ok, err, info = native_build.create({
    entry = "src/main.lua",
    output = "dist/myapp",
    include_lumos = true,
    strip_comments = true,
    static = true,
    cc = "musl-gcc"
})

if ok then
    print("Binary built: " .. info.output)
    print("Size: " .. info.size .. " bytes")
    print("Compiler: " .. info.compiler)
else
    print("Error: " .. err)
end

-- Package a standalone executable programmatically
local pkg = require('lumos.package')
local ok, err, info = pkg.create({
    entry = "src/main.lua",
    output = "dist/myapp",
    target = "linux-x86_64",
    include_lumos = true,
    strip_comments = true,
})

if ok then
    print("Package created: " .. info.output)
    print("Target: " .. info.target)
    print("Total size: " .. info.size .. " bytes")
    print("Launcher size: " .. info.launcher_size .. " bytes")
else
    print("Error: " .. err)
end
```

## Bundle Minimal (Tree-Shaking)

Starting with Lumos 0.3.x, you can create a **minimal bundle** that includes only the Lumos modules actually used by your application. This can significantly reduce bundle size.

### Programmatic API

```lua
local bundle = require('lumos.bundle')

-- Analyze dependencies
local deps = bundle.analyze_dependencies("src/main.lua")
for mod, _ in pairs(deps.lumos_modules) do
    print("Uses: " .. mod)
end

-- Create a minimal bundle
local ok, err = bundle.minimal("src/main.lua", "dist/myapp.lua", {
    minify = true
})

if ok then
    print("Minimal bundle created at dist/myapp.lua")
end

-- Simple minification
local minified = bundle.minify(code)
```

### How It Works

1. Parses `require()` and `pcall(require, ...)` calls in your entry file
2. Maps detected Lumos submodules to their top-level modules
3. Includes only the necessary Lumos modules plus core modules (`init`, `app`, `core`, `flags`)
4. Optionally strips comments and excess whitespace

## Comparison with Other Approaches

| Approach | Advantages | Disadvantages |
|----------|-----------|---------------|
| **lumos bundle** | Simple, integrated | Requires Lua runtime on target |
| **lumos build** | True native binary, zero dependencies, static C modules | Requires a C toolchain at build time |
| **lumos package** | Standalone binary, no C compiler needed | Requires a precompiled launcher for target platform |
| **luastatic** | Native binary executable | Complex to configure |
| **squish** | Very flexible | External tool required |
| **LuaRocks** | Standard distribution | Requires LuaRocks on target |

## Best Practices

1. **Use `--analyze` first** to understand what will be included
2. **Test the bundle/binary/package** on a machine without Lumos or Lua installed
3. **Use `--strip-comments`** for production builds to reduce size
4. **Use `lumos build --static`** for maximum portability on Linux
5. **Use `lumos package`** when you need a standalone binary quickly without a C toolchain
6. **Version your bundles** with a clear scheme (e.g., `myapp-1.0.0`)
7. **Document prerequisites** only when using `lumos bundle` with native C modules
