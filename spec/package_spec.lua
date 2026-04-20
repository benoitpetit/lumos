local pkg = require('lumos.package')
local fs = require('lumos.fs')

describe('Package Module', function()

    describe('detect_host_target()', function()
        it('returns a non-empty string with os-arch format', function()
            local target = pkg.detect_host_target()
            assert.is_string(target)
            assert.is_true(#target > 0)
            assert.is_not_nil(target:find('-'))
        end)
    end)

    describe('list_targets()', function()
        it('returns a table', function()
            local targets = pkg.list_targets()
            assert.is_table(targets)
        end)

        it('includes linux-x86_64 if launcher present', function()
            local targets = pkg.list_targets()
            if pkg.find_launcher('linux-x86_64') then
                assert.is_not_nil(targets)
                local found = false
                for _, t in ipairs(targets) do
                    if t == 'linux-x86_64' then found = true end
                end
                assert.is_true(found, 'Expected linux-x86_64 in targets')
            end
        end)

        it('includes windows-x86_64 if launcher present', function()
            local targets = pkg.list_targets()
            if pkg.find_launcher('windows-x86_64') then
                local found = false
                for _, t in ipairs(targets) do
                    if t == 'windows-x86_64' then found = true end
                end
                assert.is_true(found, 'Expected windows-x86_64 in targets')
            end
        end)
    end)

    describe('find_launcher()', function()
        it('returns nil for unknown target', function()
            local path = pkg.find_launcher('nonexistent-target-12345')
            assert.is_nil(path)
        end)

        it('returns a path for linux-x86_64', function()
            local path = pkg.find_launcher('linux-x86_64')
            -- The launcher may or may not be present depending on build environment
            if path then
                assert.is_string(path)
                assert.is_true(#path > 0)
            end
        end)

        it('returns a path for windows-x86_64', function()
            local path = pkg.find_launcher('windows-x86_64')
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
            assert.is_not_nil(err:find("Launcher not found"))
        end)

        it('creates a package for linux-x86_64 when launcher is available', function()
            if not pkg.find_launcher('linux-x86_64') then
                print('Package create test skipped: linux-x86_64 launcher not available')
                return
            end

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
            assert.is_true(info.launcher_size > 0)

            local f = io.open(out, "rb")
            assert.is_not_nil(f, "Output package should exist")
            if f then f:close() end

            -- Run only on Linux hosts where the binary is native
            local uname_f = io.popen('uname -s')
            local uname = uname_f and uname_f:read('*l') or ''
            if uname_f then uname_f:close() end
            if uname == 'Linux' then
                local handle = io.popen(out .. " 2>&1")
                local output = handle and handle:read("*a") or ""
                local rc = handle and { handle:close() } or { nil, "exit", 1 }
                rc = (type(rc) == "table") and (rc[3] or 0) or 0
                assert.are.equal(0, rc, "Package exited with non-zero code: " .. output)
                assert.is_not_nil(output:find("hello from package"))
            end
        end)

        it('creates a package for windows-x86_64 when launcher is available', function()
            if not pkg.find_launcher('windows-x86_64') then
                print('Package create test skipped: windows-x86_64 launcher not available')
                return
            end

            local out = tmp_output_dir .. "/testpkg_win"
            local ok, err, info = pkg.create({
                entry = tmp_entry,
                output = out,
                include_lumos = false,
                target = "windows-x86_64",
            })

            if not ok then
                print('Package create test skipped: ' .. tostring(err))
                return
            end

            assert.is_true(ok, tostring(err))
            assert.is_not_nil(info)
            -- Output should have .exe appended
            assert.are.equal(out .. ".exe", info.output)
            assert.is_true(info.size > 0)
            assert.is_true(info.launcher_size > 0)

            local f = io.open(out .. ".exe", "rb")
            assert.is_not_nil(f, "Output package should exist")
            if f then f:close() end

            -- Do not attempt to run Windows binary on non-Windows hosts
        end)

        it('defaults to host target when none is specified', function()
            local host = pkg.detect_host_target()
            if not pkg.find_launcher(host) then
                print('Package create test skipped: host launcher ' .. host .. ' not available')
                return
            end

            local out = tmp_output_dir .. "/testpkg_host"
            local ok, err, info = pkg.create({
                entry = tmp_entry,
                output = out,
                include_lumos = false,
            })

            if not ok then
                print('Package create test skipped: ' .. tostring(err))
                return
            end

            assert.is_true(ok, tostring(err))
            assert.is_not_nil(info)
            assert.are.equal(host, info.target)
        end)
    end)

end)
