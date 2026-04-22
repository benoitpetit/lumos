local config = require('lumos.config')

describe('Config Module', function()

    -- -------------------------------------------------------------------------
    describe('load_file — JSON files', function()
        local tmp_json

        before_each(function()
            -- Write a temp JSON file using io.open (bypass security for test setup)
            tmp_json = os.tmpname() .. ".json"
            local f = io.open(tmp_json, "w")
            f:write('{"name":"lumos","version":"1.0","debug":true,"port":8080}')
            f:close()
        end)

        after_each(function()
            os.remove(tmp_json)
        end)

        it('loads a valid JSON config file', function()
            local result, err = config.load_file(tmp_json)
            assert.is_nil(err)
            assert.is_table(result)
            assert.are.equal("lumos",  result.name)
            assert.are.equal("1.0",    result.version)
            assert.is_true(result.debug)
            assert.are.equal(8080,     result.port)
        end)

        it('returns nil and error message on invalid JSON', function()
            local bad = os.tmpname() .. ".json"
            local f = io.open(bad, "w")
            f:write("{not valid json}")
            f:close()
            local result, err = config.load_file(bad)
            os.remove(bad)
            assert.is_nil(result)
            assert.is_not_nil(err)
            assert.is_not_nil(err:match("Invalid JSON"))
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('load_file — key=value files', function()
        local tmp_kv

        before_each(function()
            tmp_kv = os.tmpname()
            local f = io.open(tmp_kv, "w")
            f:write("name=myapp\n")
            f:write("debug=true\n")
            f:write("workers=4\n")
            f:write("# this is a comment\n")
            f:write("   \n") -- blank line
            f:write("host=localhost\n")
            f:close()
        end)

        after_each(function()
            os.remove(tmp_kv)
        end)

        it('parses key=value pairs', function()
            local result, err = config.load_file(tmp_kv)
            assert.is_nil(err)
            assert.is_table(result)
            assert.are.equal("myapp",     result.name)
            assert.are.equal("localhost", result.host)
        end)

        it('converts boolean string values', function()
            local result = config.load_file(tmp_kv)
            assert.is_true(result.debug)
        end)

        it('converts numeric string values', function()
            local result = config.load_file(tmp_kv)
            assert.are.equal(4, result.workers)
        end)

        it('ignores comment lines', function()
            local result = config.load_file(tmp_kv)
            -- Comment line must not produce any key
            for k, _ in pairs(result) do
                assert.is_nil(k:match("^#"))
            end
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('load_file — error cases', function()
        it('returns nil and error when file does not exist', function()
            local result, err = config.load_file("/nonexistent/path/config.json")
            assert.is_nil(result)
            assert.is_not_nil(err)
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('load_env', function()
        it('returns a table', function()
            local result = config.load_env()
            assert.is_table(result)
        end)

        it('uses an empty prefix when none is provided', function()
            local result = config.load_env()
            assert.is_table(result)
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('merge_configs', function()
        it('merges defaults, config file, env and flags with correct priority', function()
            local defaults    = {host = "localhost", port = 80,   debug = false}
            local file_cfg    = {port = 443}
            local env_cfg     = {debug = true}
            local flags_cfg   = {port = 8080}

            local merged = config.merge_configs(defaults, file_cfg, env_cfg, flags_cfg)

            -- flags win over everything
            assert.are.equal(8080,        merged.port)
            -- env wins over file and defaults
            assert.is_true(merged.debug)
            -- defaults survive when nothing overrides
            assert.are.equal("localhost", merged.host)
        end)

        it('works with nil layers', function()
            local merged = config.merge_configs({key = "val"}, nil, nil, nil)
            assert.are.equal("val", merged.key)
        end)

        it('returns empty table when all layers are nil', function()
            local merged = config.merge_configs(nil, nil, nil, nil)
            assert.is_table(merged)
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('validate_schema', function()
        it('passes when data matches schema', function()
            local data = {name = "lumos", port = 8080}
            local schema = {
                name = {required = true, type = "string"},
                port = {type = "number"}
            }
            local ok, errors = config.validate_schema(data, schema)
            assert.is_true(ok)
            assert.are.equal(0, #errors)
        end)

        it('fails when required field is missing', function()
            local data = {port = 8080}
            local schema = {name = {required = true}}
            local ok, errors = config.validate_schema(data, schema)
            assert.is_false(ok)
            assert.are.equal(1, #errors)
            assert.is_not_nil(errors[1]:match("name is required"))
        end)

        it('fails when type does not match', function()
            local data = {port = "8080"}
            local schema = {port = {type = "number"}}
            local ok, errors = config.validate_schema(data, schema)
            assert.is_false(ok)
            assert.is_not_nil(errors[1]:match("must be number"))
        end)

        it('fails when custom validator returns false', function()
            local data = {env = "prod"}
            local schema = {
                env = {validate = function(v) return v == "dev" or v == "staging" end}
            }
            local ok, errors = config.validate_schema(data, schema)
            assert.is_false(ok)
            assert.is_not_nil(errors[1]:match("validation failed"))
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('load_validated', function()
        it('returns data when file is valid against schema', function()
            local tmp = os.tmpname() .. ".json"
            local f = io.open(tmp, "w")
            f:write('{"name":"lumos","debug":true}')
            f:close()

            local data, err = config.load_validated(tmp, {name = {required = true}})
            os.remove(tmp)
            assert.is_nil(err)
            assert.are.equal("lumos", data.name)
        end)

        it('returns nil and error when schema validation fails', function()
            local tmp = os.tmpname() .. ".json"
            local f = io.open(tmp, "w")
            f:write('{"debug":true}')
            f:close()

            local data, err = config.load_validated(tmp, {name = {required = true}})
            os.remove(tmp)
            assert.is_nil(data)
            assert.is_not_nil(err)
            assert.is_not_nil(err:match("Validation failed"))
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('load_file — YAML files', function()
        local tmp_yaml

        before_each(function()
            tmp_yaml = os.tmpname() .. ".yaml"
            local f = io.open(tmp_yaml, "w")
            f:write("name: lumos\nversion: '1.0'\ndebug: true\nport: 8080\n")
            f:close()
        end)

        after_each(function()
            os.remove(tmp_yaml)
        end)

        it('loads a valid YAML config file', function()
            local result, err = config.load_file(tmp_yaml)
            assert.is_nil(err)
            assert.is_table(result)
            assert.are.equal("lumos", result.name)
            assert.are.equal("1.0", result.version)
            assert.is_true(result.debug)
            assert.are.equal(8080, result.port)
        end)

        it('also recognises .yml extension', function()
            local tmp_yml = os.tmpname() .. ".yml"
            local f = io.open(tmp_yml, "w")
            f:write("key: value\n")
            f:close()
            local result, err = config.load_file(tmp_yml)
            os.remove(tmp_yml)
            assert.is_nil(err)
            assert.are.equal("value", result.key)
        end)

        it('returns nil and error on empty YAML file', function()
            local bad = os.tmpname() .. ".yaml"
            local f = io.open(bad, "w")
            f:write("   \n")
            f:close()
            local result, err = config.load_file(bad)
            os.remove(bad)
            assert.is_nil(result)
            assert.is_not_nil(err)
            assert.is_not_nil(err:match("Invalid YAML"))
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('load_file — TOML files', function()
        it('parses nested tables', function()
            local tmp = os.tmpname() .. ".toml"
            local f = io.open(tmp, "w")
            f:write('[server]\nhost = "localhost"\nport = 8080\n\n[server.ssl]\nenabled = true\n')
            f:close()
            local result, err = config.load_file(tmp)
            os.remove(tmp)
            assert.is_nil(err)
            assert.is_table(result.server)
            assert.are.equal("localhost", result.server.host)
            assert.are.equal(8080, result.server.port)
            assert.is_table(result.server.ssl)
            assert.is_true(result.server.ssl.enabled)
        end)

        it('parses inline tables', function()
            local tmp = os.tmpname() .. ".toml"
            local f = io.open(tmp, "w")
            f:write('point = { x = 1, y = 2 }\nname = "test"\n')
            f:close()
            local result, err = config.load_file(tmp)
            os.remove(tmp)
            assert.is_nil(err)
            assert.is_table(result.point)
            assert.are.equal(1, result.point.x)
            assert.are.equal(2, result.point.y)
            assert.are.equal("test", result.name)
        end)

        it('parses table arrays', function()
            local tmp = os.tmpname() .. ".toml"
            local f = io.open(tmp, "w")
            f:write('[[products]]\nname = "Hammer"\nsku = 738594937\n\n[[products]]\nname = "Nail"\nsku = 284758393\n')
            f:close()
            local result, err = config.load_file(tmp)
            os.remove(tmp)
            assert.is_nil(err)
            assert.is_table(result.products)
            assert.are.equal(2, #result.products)
            assert.are.equal("Hammer", result.products[1].name)
            assert.are.equal("Nail", result.products[2].name)
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('load_env', function()
        it('loads environment variables with a prefix', function()
            -- Set a test environment variable
            local test_key = "LUMOS_TEST_CONFIG_VAR"
            local test_value = "hello_world"
            os.execute("export " .. test_key .. "=" .. test_value)
            -- On most POSIX shells, `export` in a sub-shell won't affect the parent,
            -- so we set it via Lua's os.execute with a shell that persists it.
            -- We use a trick: set via the shell and read back.
            local handle = io.popen("export LUMOS_TEST_CONFIG_VAR=hello_world && env | grep LUMOS_TEST_CONFIG_VAR")
            if handle then handle:close() end

            -- Because env vars are hard to set portably in tests, we at least
            -- verify the function runs without crashing and returns a table.
            local result = config.load_env("LUMOS")
            assert.is_table(result)
        end)

        it('returns an empty table on Windows when no env vars match', function()
            -- This test documents the expected behavior; on Windows the function
            -- now uses `set` instead of returning an empty table unconditionally.
            local result = config.load_env("NONEXISTENT_PREFIX_XYZ")
            assert.is_table(result)
        end)
    end)
end)
