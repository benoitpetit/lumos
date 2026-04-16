local bundle = require('lumos.bundle')

describe('Bundle Module', function()

    -- -------------------------------------------------------------------------
    describe('get_lumos_modules()', function()
        it('returns a table of module names', function()
            local mods = bundle.get_lumos_modules()
            assert.is_table(mods)
            assert.is_true(#mods > 0)
        end)

        it('contains the core lumos modules', function()
            local mods = bundle.get_lumos_modules()
            local mod_set = {}
            for _, m in ipairs(mods) do mod_set[m] = true end

            assert.is_true(mod_set["lumos.app"]      ~= nil)
            assert.is_true(mod_set["lumos.core"]     ~= nil)
            assert.is_true(mod_set["lumos.flags"]    ~= nil)
            assert.is_true(mod_set["lumos.security"] ~= nil)
            assert.is_true(mod_set["lumos.logger"]   ~= nil)
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('analyze()', function()
        local tmp_entry

        before_each(function()
            -- Create a temporary Lua script that requires one module
            tmp_entry = os.tmpname() .. ".lua"
            local f = io.open(tmp_entry, "w")
            f:write('local json = require("lumos.json")\n')
            f:write('print("hello")\n')
            f:close()
        end)

        after_each(function()
            os.remove(tmp_entry)
        end)

        it('returns a table', function()
            local deps = bundle.analyze(tmp_entry, {"."})
            assert.is_table(deps)
        end)

        it('returns nil-safe when entry file does not exist', function()
            local deps = bundle.analyze("/nonexistent/file.lua", {"."})
            assert.is_table(deps)
            assert.are.equal(0, #deps)
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('amalgamate()', function()
        local tmp_entry

        before_each(function()
            tmp_entry = os.tmpname() .. ".lua"
            local f = io.open(tmp_entry, "w")
            f:write('local json = require("lumos.json")\n')
            f:write('print("hello")\n')
            f:close()
        end)

        after_each(function()
            os.remove(tmp_entry)
            os.execute("rm -rf .lumos/cache/")
        end)

        it('fails when no entry file is provided', function()
            local ok, err = bundle.amalgamate({})
            assert.is_false(ok)
            assert.is_not_nil(err)
            assert.is_not_nil(err:match("[Ee]ntry"))
        end)

        it('returns the amalgamated Lua string', function()
            local ok, err, lua_code, count = bundle.amalgamate({
                entry = tmp_entry,
                include_lumos = false,
            })
            assert.is_true(ok, tostring(err))
            assert.is_string(lua_code)
            assert.is_number(count)
            assert.is_true(#lua_code > 0)
            -- Should contain the preloader signature
            assert.is_not_nil(lua_code:find("_BUNDLED_MODULES"))
            -- Should use package.searchers / package.loaders instead of monkey-patching require
            assert.is_not_nil(lua_code:find("package.searchers") or lua_code:find("package.loaders"))
        end)

        it('returns the same content that would be written by create()', function()
            local out_file = os.tmpname() .. "_bundle"
            local ok1, err1, lua_code = bundle.amalgamate({
                entry = tmp_entry,
                include_lumos = false,
            })
            assert.is_true(ok1)

            local ok2, err2, info = bundle.create({
                entry = tmp_entry,
                output = out_file,
                include_lumos = false,
            })
            assert.is_true(ok2)

            local f = io.open(out_file, "r")
            local written = f and f:read("*a") or ""
            if f then f:close() end
            os.remove(out_file)

            assert.are.equal(lua_code, written)
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('create()', function()
        local tmp_entry
        local tmp_output_dir

        before_each(function()
            -- Minimal entry script
            tmp_entry = os.tmpname() .. ".lua"
            local f = io.open(tmp_entry, "w")
            f:write('print("bundled app")\n')
            f:close()

            -- Temporary output directory (append suffix to avoid conflict with the
            -- file that os.tmpname() itself creates on Linux)
            tmp_output_dir = os.tmpname() .. "_d"
            os.execute("mkdir -p " .. tmp_output_dir)
        end)

        after_each(function()
            os.remove(tmp_entry)
            os.execute("rm -rf " .. tmp_output_dir)
            os.execute("rm -rf .lumos/cache/")
        end)

        it('fails when no entry file is provided', function()
            local ok, err = bundle.create({})
            assert.is_false(ok)
            assert.is_not_nil(err)
            assert.is_not_nil(err:match("[Ee]ntry"))
        end)

        it('fails when entry file does not exist', function()
            local ok, err = bundle.create({entry = "/nonexistent/entry.lua"})
            assert.is_false(ok)
            assert.is_not_nil(err)
        end)

        it('fails when entry path is a directory', function()
            local ok, err = bundle.create({entry = "/tmp"})
            assert.is_false(ok)
            assert.is_not_nil(err)
            assert.is_not_nil(err:match("not a file"))
        end)

        it('creates a bundle file successfully', function()
            local out_file = tmp_output_dir .. "/testbundle"
            local ok, err = bundle.create({
                entry       = tmp_entry,
                output      = out_file,
                include_lumos = false,  -- skip lumos modules for speed
            })
            assert.is_true(ok, "Expected success but got error: " .. tostring(err))
            -- Check output file exists
            local f = io.open(out_file, "r")
            assert.is_not_nil(f, "Output file should exist")
            if f then f:close() end
        end)

        it('bundle output starts with a shebang line', function()
            local out_file = tmp_output_dir .. "/shebang_test"
            bundle.create({
                entry         = tmp_entry,
                output        = out_file,
                include_lumos = false,
            })
            local f = io.open(out_file, "r")
            if f then
                local first_line = f:read("*l")
                f:close()
                assert.is_not_nil(first_line:match("^#!"))
            end
        end)

        it('returns module count and size in result info', function()
            local out_file = tmp_output_dir .. "/info_test"
            local ok, err, info = bundle.create({
                entry         = tmp_entry,
                output        = out_file,
                include_lumos = false,
            })
            assert.is_true(ok)
            assert.is_not_nil(info)
            assert.is_number(info.modules_count)
            assert.is_number(info.size)
            assert.is_true(info.size > 0)
        end)
    end)

    describe('minimal bundle', function()
        local tmp_entry
        local tmp_output

        before_each(function()
            tmp_entry = os.tmpname() .. ".lua"
            tmp_output = os.tmpname() .. ".lua"
            local f = io.open(tmp_entry, "w")
            f:write('local lumos = require("lumos")\n')
            f:write('local app = lumos.new_app()\n')
            f:write('app:run({"--version"})\n')
            f:close()
        end)

        after_each(function()
            os.remove(tmp_entry)
            os.remove(tmp_output)
        end)

        it('creates a minimal bundle', function()
            local ok, err = bundle.minimal(tmp_entry, tmp_output)
            assert.is_true(ok, err)
            local f = io.open(tmp_output, "r")
            assert.is_not_nil(f)
            local content = f:read("*a")
            f:close()
            assert.truthy(content:find("Lumos Minimal Bundle"))
            assert.truthy(content:find("lumos.init"))
        end)
    end)

    describe('minify', function()
        it('removes comments and excess whitespace', function()
            local code = "-- comment\nlocal x = 1\n\n\nlocal y = 2\n"
            local min = bundle.minify(code)
            assert.falsy(min:find("%-%- comment"))
            assert.truthy(min:find("local x = 1"))
            assert.falsy(min:find("\n\n"))
        end)
    end)

end)
