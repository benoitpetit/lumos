-- Platform module tests
local platform = require('lumos.platform')

describe("Platform Module", function()
    it('detects a platform name', function()
        local name = platform.name()
        assert.is_string(name)
        assert.is_true(name == "linux" or name == "macos" or name == "windows" or name == "freebsd" or name == "openbsd" or name == "unknown")
    end)

    it('detects an architecture', function()
        local arch = platform.arch()
        assert.is_string(arch)
        assert.is_true(arch == "amd64" or arch == "arm64" or arch == "armv7" or arch == "386" or arch == "unknown")
    end)

    it('has consistent boolean helpers', function()
        local is_win = platform.is_windows()
        local is_unix = platform.is_unix()
        -- They must be opposites
        assert.equal(not is_win, is_unix)
    end)

    it('returns a path separator', function()
        local sep = platform.path_separator()
        if platform.is_windows() then
            assert.equal("\\", sep)
        else
            assert.equal("/", sep)
        end
    end)

    it('returns a path list separator', function()
        local sep = platform.path_list_separator()
        if platform.is_windows() then
            assert.equal(";", sep)
        else
            assert.equal(":", sep)
        end
    end)

    it('normalizes paths', function()
        local norm = platform.normalize_path("./foo/../bar")
        if platform.is_windows() then
            assert.truthy(norm:find("bar"))
            assert.falsy(norm:find("%./"))
        else
            assert.equal("/bar", platform.normalize_path("/foo/../bar"))
        end
    end)

    it('supports_colors returns a boolean', function()
        local ok = platform.supports_colors()
        assert.is_boolean(ok)
    end)

    it('is_interactive returns a boolean', function()
        local ok = platform.is_interactive()
        assert.is_boolean(ok)
    end)

    it('is_piped returns a boolean', function()
        local ok = platform.is_piped()
        assert.is_boolean(ok)
    end)
end)
