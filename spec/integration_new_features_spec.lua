-- Integration test for all new features working together in a real CLI flow
local app = require('lumos.app')
local core = require('lumos.core')
local yaml = require('lumos.yaml')
local config = require('lumos.config')
local logger = require('lumos.logger')
local Middleware = require('lumos.middleware')

describe("Integration — New Features in Real CLI Flow", function()
    -- Capture stdout/stderr helpers
    local function capture_outputs()
        local stdout, stderr = "", ""
        local orig_stdout, orig_stderr = io.stdout, io.stderr
        io.stdout = { write = function(_, s) stdout = stdout .. (s or "") end, flush = function() end }
        io.stderr = { write = function(_, s) stderr = stderr .. (s or "") end, flush = function() end }
        return function()
            io.stdout, io.stderr = orig_stdout, orig_stderr
            return stdout, stderr
        end
    end

    describe("YAML configuration end-to-end", function()
        it("loads YAML config via app config_file", function()
            local tmp = os.tmpname() .. ".yaml"
            local f = io.open(tmp, "w")
            f:write("name: testapp\ndebug: true\nitems:\n  - one\n  - two\n")
            f:close()

            local test_app = app.new_app({ name = "cli", config_file = tmp })
            test_app:command("show", "Show config"):action(function(ctx)
                return true
            end)

            local restore = capture_outputs()
            test_app:run({"show"})
            restore()

            assert.is_table(test_app.loaded_config)
            assert.are.equal("testapp", test_app.loaded_config.name)
            assert.is_true(test_app.loaded_config.debug)
            assert.are.same({"one", "two"}, test_app.loaded_config.items)
            os.remove(tmp)
        end)

        it("merges YAML config with env and flags", function()
            local tmp = os.tmpname() .. ".yaml"
            local f = io.open(tmp, "w")
            f:write("timeout: 30\n")
            f:close()

            local merged = config.merge_configs(
                {timeout = 10},
                config.load_file(tmp),
                {timeout = 20},
                {timeout = 5}
            )
            os.remove(tmp)
            assert.are.equal(5, merged.timeout)
        end)
    end)

    describe("Countable flags in real command execution", function()
        it("counts -vvv and sets log level via middleware", function()
            local test_app = app.new_app({ name = "cli" })
            test_app:flag("-v --verbose", "Verbose"):countable()

            local levels = {}
            test_app:command("run", "Run")
                :use(Middleware.builtin.verbosity())
                :action(function(ctx)
                    -- The validator merges by long name, so the value is in ctx.flags.verbose
                    table.insert(levels, { verbose = ctx.flags.verbose })
                    return true
                end)

            local restore = capture_outputs()
            test_app:run({"-vvv", "run"})
            restore()

            assert.are.equal(3, levels[1].verbose)
        end)

        it("counts command-level countable flags", function()
            local test_app = app.new_app({ name = "cli" })
            test_app:command("run", "Run")
                :flag("-d --debug", "Debug mode"):countable()
                :action(function(ctx)
                    return ctx.flags.debug
                end)

            local restore = capture_outputs()
            local result = test_app:run({"run", "-ddd"})
            restore()

            assert.are.equal(0, result) -- action returns truthy number 3 → EXIT_OK
        end)
    end)

    describe("Quiet mode suppresses output", function()
        it("--quiet suppresses help text", function()
            local test_app = app.new_app({ name = "cli" })
            test_app:command("run", "Run"):action(function() return true end)

            local restore = capture_outputs()
            test_app:run({"--quiet", "--help"})
            local stdout, stderr = restore()

            assert.are.equal("", stdout)
        end)

        it("-q suppresses version text", function()
            local test_app = app.new_app({ name = "cli", version = "1.0" })

            local restore = capture_outputs()
            test_app:run({"-q", "--version"})
            local stdout, stderr = restore()

            assert.are.equal("", stdout)
        end)
    end)

    describe("Middleware timeout and circuit breaker in chain", function()
        it("timeout middleware aborts slow commands", function()
            local test_app = app.new_app({ name = "cli" })
            test_app:command("slow", "Slow command")
                :use(Middleware.builtin.timeout({ seconds = 0.01 }))
                :action(function(ctx)
                    -- Wall-clock busy loop so timeout fires even with socket.gettime()
                    local socket_ok, socket = pcall(require, "socket")
                    local gettime = socket_ok and socket.gettime or os.clock
                    local start = gettime()
                    while gettime() - start < 0.1 do
                        for _ = 1, 10000 do math.sqrt(12345.6789) end
                    end
                    return true
                end)

            local restore = capture_outputs()
            local exit_code = test_app:run({"slow"})
            local stdout, stderr = restore()

            assert.are.not_equal(0, exit_code) -- must be non-zero (TIMEOUT = 13)
            assert.is_not_nil(stderr:match("Operation exceeded") or stdout:match("Operation exceeded"))
        end)

        it("circuit breaker blocks after failures", function()
            local test_app = app.new_app({ name = "cli" })
            test_app:command("risky", "Risky command")
                :use(Middleware.builtin.circuit_breaker({ failure_threshold = 2, recovery_timeout = 3600 }))
                :action(function(ctx)
                    return nil, require('lumos.error').new("EXECUTION_FAILED", "boom")
                end)

            local restore = capture_outputs()
            test_app:run({"risky"}) -- failure 1
            test_app:run({"risky"}) -- failure 2, trips breaker
            local exit_code = test_app:run({"risky"}) -- blocked
            restore()

            -- EXECUTION_FAILED has exit_code 10
            assert.are.equal(10, exit_code)
        end)
    end)

    describe("Logger JSON format in CLI context", function()
        it("outputs JSON logs when format is json", function()
            local logs = {}
            local mock_output = { write = function(_, s) table.insert(logs, s) end, flush = function() end }

            logger.set_output(mock_output)
            logger.set_format("json")
            logger.set_level("INFO")
            logger.info("deploy started", {env = "prod"})
            logger.set_format("text")
            logger.set_output(io.stderr)

            local entry = logs[1]
            assert.is_not_nil(entry)
            assert.is_not_nil(entry:match('"level":"INFO"'))
            assert.is_not_nil(entry:match('"message":"deploy started"'))
            assert.is_not_nil(entry:match('"env":"prod"'))
        end)
    end)

    describe("Windows env loading (simulated)", function()
        it("load_env returns a table even on Windows", function()
            -- We can't simulate Windows, but we can verify the function doesn't crash
            -- and returns a table on POSIX too.
            local result = config.load_env("NONEXISTENT_PREFIX_999")
            assert.is_table(result)
        end)
    end)

    describe("Complete CLI with all new features combined", function()
        it("runs a realistic workflow", function()
            local tmp_yaml = os.tmpname() .. ".yaml"
            local f = io.open(tmp_yaml, "w")
            f:write("environment: staging\nretries: 2\n")
            f:close()

            local test_app = app.new_app({
                name = "deploy-cli",
                version = "2.0",
                config_file = tmp_yaml,
                env_prefix = "DEPLOY"
            })

            test_app:flag("-v --verbose", "Increase verbosity"):countable()
            test_app:persistent_flag_string("--format", "Output format")

            test_app:command("deploy", "Deploy application")
                :arg("target", "Deployment target", { required = true })
                :flag("--dry-run", "Simulate deployment")
                :use(Middleware.builtin.timeout({ seconds = 5 }))
                :action(function(ctx)
                    -- Config was auto-loaded
                    assert.is_table(ctx.config)
                    -- Countable flag works
                    assert.is_number(ctx.flags.v)
                    -- Persistent flag works
                    assert.is_not_nil(ctx.flags.format)
                    return require('lumos.error').success({target = ctx.args[1]})
                end)

            local restore = capture_outputs()
            local exit_code = test_app:run({"-vv", "--format", "json", "deploy", "production"})
            local stdout, stderr = restore()

            os.remove(tmp_yaml)
            assert.are.equal(0, exit_code)
        end)
    end)
end)
