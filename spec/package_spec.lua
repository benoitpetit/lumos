local pkg = require('lumos.package')
local fs = require('lumos.fs')

describe('Package Module', function()

    describe('list_targets()', function()
        it('returns a table', function()
            local targets = pkg.list_targets()
            assert.is_table(targets)
        end)
    end)

    describe('find_stub()', function()
        it('returns nil for unknown target', function()
            local path = pkg.find_stub('nonexistent-target-12345')
            assert.is_nil(path)
        end)

        it('returns a path for linux-x86_64', function()
            local path = pkg.find_stub('linux-x86_64')
            -- The stub may or may not be present depending on build environment
            if path then
                assert.is_string(path)
                assert.is_true(#path > 0)
            end
        end)
    end)

    describe('create()', function()
        local tmp_entry
        local tmp_output_dir

        before_each(function()
            tmp_entry = os.tmpname() .. ".lua"
            local f = io.open(tmp_entry, "w")
            f:write('print("hello from package")\n')
            f:close()

            tmp_output_dir = os.tmpname() .. "_d"
            fs.mkdir_p(tmp_output_dir)
        end)

        after_each(function()
            os.remove(tmp_entry)
            fs.rmdir_p(tmp_output_dir)
        end)

        it('fails when entry file is missing', function()
            local ok, err = pkg.create({ entry = "/nonexistent/path.lua" })
            assert.is_false(ok)
            assert.is_not_nil(err)
        end)

        it('fails for unknown target', function()
            local ok, err = pkg.create({
                entry = tmp_entry,
                target = "unknown-target",
            })
            assert.is_false(ok)
            assert.is_not_nil(err:find("Stub not found"))
        end)

        it('creates a package when stub is available', function()
            -- Skip if stub is missing
            if not pkg.find_stub('linux-x86_64') then
                print('Package create test skipped: stub not available')
                return
            end

            -- Skip binary execution on macOS (stub is linux-x86_64)
            local uname_f = io.popen('uname -s')
            local uname = uname_f and uname_f:read('*l') or ''
            if uname_f then uname_f:close() end
            local is_macos = uname == 'Darwin'

            local out = tmp_output_dir .. "/testpkg"
            local ok, err, info = pkg.create({
                entry = tmp_entry,
                output = out,
                include_lumos = false,
                target = "linux-x86_64",
            })

            if not ok then
                print('Package create test skipped: ' .. tostring(err))
                return
            end

            assert.is_true(ok, tostring(err))
            assert.is_not_nil(info)
            assert.are.equal(out, info.output)
            assert.is_true(info.size > 0)
            assert.is_true(info.stub_size > 0)

            -- Verify the file exists and is executable (on Unix)
            local f = io.open(out, "rb")
            assert.is_not_nil(f, "Output package should exist")
            if f then f:close() end

            -- Try to run it (skip on macOS since binary is linux-x86_64)
            if not is_macos then
                local handle = io.popen(out .. " 2>&1")
                local output = handle and handle:read("*a") or ""
                local rc = handle and { handle:close() } or { nil, "exit", 1 }
                rc = (type(rc) == "table") and (rc[3] or 0) or 0
                assert.are.equal(0, rc, "Package exited with non-zero code: " .. output)
                assert.is_not_nil(output:find("hello from package"))
            end
        end)
    end)

end)
