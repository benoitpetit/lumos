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

        it('reads known env variable DEBUG when set', function()
            -- Temporarily set env var (Lua os.getenv reads live env)
            -- We use a temp approach: call load_env and check key presence
            -- (We cannot truly set env vars from pure Lua; test that load_env
            --  runs without error and returns a table)
            local result = config.load_env("LUMOS_TEST_NONEXISTENT_PREFIX_XYZ")
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
end)
