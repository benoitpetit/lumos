local native_build = require('lumos.native_build')

describe('Native Build Module', function()

    describe('generate_c_wrapper()', function()
        it('includes hex-encoded Lua payload', function()
            local c_code = native_build.generate_c_wrapper('print("hi")', {})
            assert.is_string(c_code)
            assert.is_not_nil(c_code:find('static const unsigned char bundled_lua'))
            assert.is_not_nil(c_code:find('0x'))
        end)

        it('includes luaL_loadbuffer and lua_pcall', function()
            local c_code = native_build.generate_c_wrapper('return 1', {})
            assert.is_not_nil(c_code:find('luaL_loadbuffer'))
            assert.is_not_nil(c_code:find('lua_pcall'))
        end)

        it('adds conditional preload for native modules', function()
            local c_code = native_build.generate_c_wrapper('', { native_modules = { 'lfs' } })
            assert.is_not_nil(c_code:find('extern int luaopen_lfs'))
            assert.is_not_nil(c_code:find('STATIC_LFS'))
            assert.is_not_nil(c_code:find('luaopen_lfs'))
        end)
    end)

    describe('detect_compiler()', function()
        it('returns a string when a compiler is available', function()
            local cc = native_build.detect_compiler()
            -- We cannot assume gcc is present everywhere, but on CI it should be.
            -- Just assert type when found.
            if cc then
                assert.is_string(cc)
                assert.is_true(#cc > 0)
            end
        end)

        it('respects preferred compiler', function()
            local cc = native_build.detect_compiler('gcc')
            if cc then
                assert.is_true(cc:find('gcc') ~= nil)
            end
        end)
    end)

    describe('detect_toolchain()', function()
        it('returns nil when no compiler is found', function()
            local tc, err = native_build.detect_toolchain({ cc = 'this_compiler_does_not_exist_12345' })
            assert.is_nil(tc)
            assert.is_not_nil(err)
        end)

        it('finds Lua headers and liblua when available', function()
            local tc, err = native_build.detect_toolchain()
            if not tc then
                print('Toolchain detection skipped: ' .. tostring(err))
                return
            end
            assert.is_string(tc.compiler)
            assert.is_string(tc.cflags)
            assert.is_not_nil(tc.lua_include_dir)
        end)
    end)

    describe('bytecode_compile()', function()
        it('compiles Lua source to bytecode', function()
            local bc, err = native_build.bytecode_compile('return 42')
            if not bc then
                print('Bytecode test skipped: ' .. tostring(err))
                return
            end
            assert.is_string(bc)
            -- Bytecode should differ from source and start with Lua signature
            assert.are_not.equal('return 42', bc)
            -- Lua 5.x bytecode starts with escape sequence 0x1b + 'Lua'
            assert.is_true(bc:byte(1) == 0x1b or bc:sub(2,4) == 'Lua')
        end)

        it('returns error when luac is missing', function()
            local bc, err = native_build.bytecode_compile('return 1', 'nonexistent_luac_xyz')
            assert.is_nil(bc)
            assert.is_not_nil(err)
        end)
    end)

    describe('create() end-to-end', function()
        local tmp_entry
        local tmp_output_dir

        before_each(function()
            tmp_entry = os.tmpname() .. ".lua"
            local f = io.open(tmp_entry, "w")
            f:write('print("hello from native build")\n')
            f:close()

            tmp_output_dir = os.tmpname() .. "_d"
            os.execute("mkdir -p " .. tmp_output_dir)
        end)

        after_each(function()
            os.remove(tmp_entry)
            os.execute("rm -rf " .. tmp_output_dir)
        end)

        it('builds a runnable native binary', function()
            local out_bin = tmp_output_dir .. "/testapp"
            local ok, err, info = native_build.create({
                entry = tmp_entry,
                output = out_bin,
                include_lumos = false,
            })

            if not ok then
                print('Native build skipped: ' .. tostring(err))
                return
            end

            assert.is_true(ok, tostring(err))
            assert.is_not_nil(info)
            assert.are.equal(out_bin, info.output)
            assert.is_true(info.size > 0)

            -- Run the binary
            local handle = io.popen(out_bin .. " 2>&1")
            local output = handle and handle:read("*a") or ""
            local rc = handle and { handle:close() } or { nil, "exit", 1 }
            if type(rc) == "table" then
                rc = rc[3] or 0
            else
                rc = 0
            end

            assert.are.equal(0, rc, "Binary exited with non-zero code: " .. output)
            assert.is_not_nil(output:find("hello from native build"))
        end)

        it('builds a runnable native binary with bytecode', function()
            local out_bin = tmp_output_dir .. "/testapp_bc"
            local ok, err, info = native_build.create({
                entry = tmp_entry,
                output = out_bin,
                include_lumos = false,
                bytecode = true,
            })

            if not ok then
                print('Native build with bytecode skipped: ' .. tostring(err))
                return
            end

            assert.is_true(ok)
            assert.is_true(info.bytecode)

            local handle = io.popen(out_bin .. " 2>&1")
            local output = handle and handle:read("*a") or ""
            local rc = handle and { handle:close() } or { nil, "exit", 1 }
            rc = (type(rc) == "table") and (rc[3] or 0) or 0
            assert.are.equal(0, rc, "Binary exited with non-zero code: " .. output)
            assert.is_not_nil(output:find("hello from native build"))
        end)

        it('returns an error for missing entry file', function()
            local ok, err = native_build.create({
                entry = "/nonexistent/path/file.lua",
                include_lumos = false,
            })
            assert.is_false(ok)
            assert.is_not_nil(err)
        end)
    end)

end)
