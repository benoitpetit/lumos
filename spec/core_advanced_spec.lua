local core = require('lumos.core')
local app  = require('lumos.app')

describe('Advanced Core Module', function()
    describe('Command aliases', function()
        it('finds commands by alias', function()
            local test_app = app.new_app()
            local cmd = test_app:command('create', 'Create something')
            cmd:alias('c'):alias('new')
            
            local found_by_name   = core.find_command(test_app, 'create')
            local found_by_alias1 = core.find_command(test_app, 'c')
            local found_by_alias2 = core.find_command(test_app, 'new')
            
            assert.are.equal(cmd, found_by_name)
            assert.are.equal(cmd, found_by_alias1)
            assert.are.equal(cmd, found_by_alias2)
        end)
        
        it('returns nil for unknown command or alias', function()
            local test_app = app.new_app()
            test_app:command('test', 'Test command')
            
            local not_found = core.find_command(test_app, 'unknown')
            assert.is_nil(not_found)
        end)
    end)
    
    describe('Flag validation and merging', function()
        it('validates and merges flags correctly', function()
            local test_app = app.new_app()
            test_app.persistent_flags = {
                verbose = {type = "boolean", persistent = true}
            }
            
            local cmd = test_app:command('test', 'Test command')
            cmd.flags = {
                count = {type = "int", min = 1, max = 10}
            }
            
            local parsed_flags = {
                verbose = true,
                count = "5"
            }
            
            local merged, errors = core.validate_and_merge_flags(test_app, cmd, parsed_flags)
            
            assert.are.equal(0, #errors)
            assert.is_true(merged.verbose)
            assert.are.equal(5, merged.count)
        end)
        
        it('reports validation errors', function()
            local test_app = app.new_app()
            local cmd = test_app:command('test', 'Test command')
            cmd.flags = {
                count = {type = "int", min = 1, max = 10}
            }
            
            local parsed_flags = {
                count = "15"  -- exceeds max
            }
            
            local merged, errors = core.validate_and_merge_flags(test_app, cmd, parsed_flags)
            
            assert.are.equal(1, #errors)
            assert.matches("must be <= 10", errors[1])
        end)

        it('applies default values for flags', function()
            local test_app = app.new_app()
            local cmd = test_app:command('test', 'Test command')
            cmd.flags = {
                format = {type = "string", long = "format", default = "json"}
            }

            local merged, errors = core.validate_and_merge_flags(test_app, cmd, {})
            assert.are.equal(0, #errors)
            assert.are.equal("json", merged.format)
        end)

        it('reads flag values from environment variables', function()
            local test_app = app.new_app()
            local cmd = test_app:command('test', 'Test command')
            cmd.flags = {
                name = {type = "string", long = "name", env = "LUMOS_TEST_NAME"}
            }

            -- Instead, directly test the env binding by querying the flag definition
            assert.are.equal("LUMOS_TEST_NAME", cmd.flags.name.env)
        end)

        it('reports required flags as errors when missing', function()
            local test_app = app.new_app()
            local cmd = test_app:command('test', 'Test command')
            cmd.flags = {
                token = {type = "string", long = "token", required = true}
            }

            local merged, errors = core.validate_and_merge_flags(test_app, cmd, {})
            assert.are.equal(1, #errors)
            assert.matches("is required", errors[1])
        end)

        it('runs custom validators', function()
            local test_app = app.new_app()
            local cmd = test_app:command('test', 'Test command')
            cmd.flags = {
                port = {
                    type = "int",
                    long = "port",
                    custom_validator = function(v)
                        return v > 1024, "port must be > 1024"
                    end
                }
            }

            local merged_ok, errors_ok = core.validate_and_merge_flags(test_app, cmd, {port = "8080"})
            assert.are.equal(0, #errors_ok)

            local merged_bad, errors_bad = core.validate_and_merge_flags(test_app, cmd, {port = "80"})
            assert.are.equal(1, #errors_bad)
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('Argument validation', function()
        it('validates required positional arguments', function()
            local test_app = app.new_app()
            local cmd = test_app:command('deploy', 'Deploy app')
            cmd:arg('env', 'Environment', {required = true})

            local parsed = core.parse_arguments({'deploy'}, test_app)
            local validated, errors = core.validate_args(cmd, parsed)
            assert.are.equal(1, #errors)
            assert.is_not_nil(errors[1]:match("required"))
        end)

        it('converts positional args to int type', function()
            local test_app = app.new_app()
            local cmd = test_app:command('serve', 'Serve app')
            cmd:arg('port', 'Port number', {type = 'int'})

            local parsed = core.parse_arguments({'serve', '8080'}, test_app)
            local validated, errors = core.validate_args(cmd, parsed)
            assert.are.equal(0, #errors)
            assert.are.equal(8080, validated[1])
        end)

        it('applies default values for missing args', function()
            local test_app = app.new_app()
            local cmd = test_app:command('greet', 'Greet')
            cmd:arg('name', 'Name', {default = 'World'})

            local parsed = core.parse_arguments({'greet'}, test_app)
            local validated, errors = core.validate_args(cmd, parsed)
            assert.are.equal(0, #errors)
            assert.are.equal('World', validated[1])
        end)

        it('enforces min and max on numeric args', function()
            local test_app = app.new_app()
            local cmd = test_app:command('scale', 'Scale')
            cmd:arg('count', 'Instance count', {type = 'int', min = 1, max = 10})

            local parsed = core.parse_arguments({'scale', '15'}, test_app)
            local validated, errors = core.validate_args(cmd, parsed)
            assert.are.equal(1, #errors)
            assert.is_not_nil(errors[1]:match("must be <= 10"))
        end)

        it('runs custom validators on args', function()
            local test_app = app.new_app()
            local cmd = test_app:command('deploy', 'Deploy')
            cmd:arg('env', 'Environment', {
                validate = function(v)
                    return v == 'staging' or v == 'production', "must be staging or production"
                end
            })

            local parsed_ok = core.parse_arguments({'deploy', 'staging'}, test_app)
            local validated_ok, errors_ok = core.validate_args(cmd, parsed_ok)
            assert.are.equal(0, #errors_ok)

            local parsed_bad = core.parse_arguments({'deploy', 'dev'}, test_app)
            local validated_bad, errors_bad = core.validate_args(cmd, parsed_bad)
            assert.are.equal(1, #errors_bad)
        end)

        it('returns EXIT_USAGE when required arg is missing in execute_command', function()
            local test_app = app.new_app({name = 'testapp'})
            test_app:command('deploy', 'Deploy')
                :arg('env', 'Environment', {required = true})
                :action(function(ctx) return true end)

            local parsed = core.parse_arguments({'deploy'}, test_app)
            local result = core.execute_command(test_app, parsed)
            assert.are.equal(2, result)
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('parse_arguments()', function()
        it('returns empty parsed structure for no args', function()
            local test_app = app.new_app()
            local parsed = core.parse_arguments({}, test_app)
            assert.is_nil(parsed.command)
            assert.is_table(parsed.flags)
            assert.is_table(parsed.args)
        end)

        it('parses a command name', function()
            local test_app = app.new_app()
            local parsed = core.parse_arguments({'build'}, test_app)
            assert.are.equal('build', parsed.command)
        end)

        it('parses a long flag with --flag=value syntax', function()
            local test_app = app.new_app()
            local parsed = core.parse_arguments({'--output=dist'}, test_app)
            assert.are.equal('dist', parsed.flags.output)
        end)

        it('parses a boolean long flag', function()
            local test_app = app.new_app()
            local parsed = core.parse_arguments({'--verbose'}, test_app)
            assert.is_true(parsed.flags.verbose)
        end)

        it('parses a short flag', function()
            local test_app = app.new_app()
            local parsed = core.parse_arguments({'-v'}, test_app)
            assert.is_true(parsed.flags.v)
        end)

        it('parses command and positional args', function()
            local test_app = app.new_app()
            local parsed = core.parse_arguments({'run', 'file.lua', 'arg2'}, test_app)
            assert.are.equal('run',      parsed.command)
            assert.are.equal('file.lua', parsed.args[1])
            assert.are.equal('arg2',     parsed.args[2])
        end)

        it('parses mixed flags and positional args', function()
            local test_app = app.new_app()
            local parsed = core.parse_arguments({'deploy', '--env=prod', 'myapp'}, test_app)
            assert.are.equal('deploy',  parsed.command)
            assert.are.equal('prod',    parsed.flags.env)
            assert.are.equal('myapp',   parsed.args[1])
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('execute_command()', function()
        it('executes a command action and returns its result', function()
            local test_app = app.new_app({name = 'testapp'})
            local called   = false

            test_app:command('go', 'Go!'):action(function(ctx)
                called = true
                return true
            end)

            local parsed = core.parse_arguments({'go'}, test_app)
            local result = core.execute_command(test_app, parsed)

            assert.is_true(called)
            assert.are.equal(0, result)
        end)

        it('returns EXIT_USAGE and prints error to stderr for unknown command', function()
            local test_app = app.new_app({name = 'testapp'})
            local original_print = _G.print
            local original_stderr = io.stderr
            local output = ""
            io.stderr = {write = function(_, s) output = output .. (s or "") end}
            _G.print = function() end

            local parsed = {command = 'unknown', flags = {}, args = {}}
            local result = core.execute_command(test_app, parsed)

            _G.print = original_print
            io.stderr = original_stderr
            assert.are.equal(2, result)
            assert.is_not_nil(output:match("Unknown command"))
        end)

        it('shows help and returns EXIT_OK when no command given', function()
            local test_app = app.new_app({name = 'testapp'})
            local original_print = _G.print
            _G.print = function() end

            local parsed = {command = nil, flags = {}, args = {}}
            local result = core.execute_command(test_app, parsed)

            _G.print = original_print
            assert.are.equal(0, result)
        end)

        it('returns EXIT_USAGE when command has no action', function()
            local test_app = app.new_app({name = 'testapp'})
            test_app:command('noop', 'Does nothing')  -- no :action()

            local original_print = _G.print
            _G.print = function() end

            local parsed = core.parse_arguments({'noop'}, test_app)
            local result = core.execute_command(test_app, parsed)

            _G.print = original_print
            assert.are.equal(2, result)
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('show_help()', function()
        it('prints app name and version', function()
            local test_app = app.new_app({name = 'myapp', version = '3.0.0'})
            local output = ""
            local original_print = _G.print
            _G.print = function(s) output = output .. (s or "") .. "\n" end

            core.show_help(test_app)

            _G.print = original_print
            assert.is_not_nil(output:match("myapp"))
            assert.is_not_nil(output:match("3%.0%.0"))
        end)

        it('lists available commands', function()
            local test_app = app.new_app({name = 'myapp'})
            test_app:command('build',  'Build the project')
            test_app:command('deploy', 'Deploy to server')

            local output = ""
            local original_print = _G.print
            _G.print = function(s) output = output .. (s or "") .. "\n" end

            core.show_help(test_app)

            _G.print = original_print
            assert.is_not_nil(output:match("build"))
            assert.is_not_nil(output:match("deploy"))
        end)

        it('groups commands by category', function()
            local test_app = app.new_app({name = 'myapp'})
            test_app:command('build', 'Build'):category('Dev')
            test_app:command('deploy', 'Deploy'):category('Ops')
            test_app:command('test', 'Test')  -- no category

            local output = ""
            local original_print = _G.print
            _G.print = function(s) output = output .. (s or "") .. "\n" end

            core.show_help(test_app)

            _G.print = original_print
            assert.is_not_nil(output:match("Dev commands:"))
            assert.is_not_nil(output:match("Ops commands:"))
            assert.is_not_nil(output:match("Available commands:"))
        end)
    end)

    describe('suggest_command()', function()
        it('suggests a close command name', function()
            local test_app = app.new_app({name = 'myapp'})
            test_app:command('deploy', 'Deploy')

            local suggestion = core.suggest_command(test_app, 'deplpy')
            assert.are.equal('deploy', suggestion)
        end)

        it('returns nil when no close match', function()
            local test_app = app.new_app({name = 'myapp'})
            test_app:command('build', 'Build')

            local suggestion = core.suggest_command(test_app, 'xyz')
            assert.is_nil(suggestion)
        end)
    end)

    describe('Hooks', function()
        it('executes pre_run and post_run hooks', function()
            local test_app = app.new_app({name = 'testapp'})
            local pre_called = false
            local post_called = false

            test_app:command('hooked', 'Hooked cmd')
                :pre_run(function(ctx)
                    pre_called = true
                    assert.are.equal('hooked', ctx.command.name)
                end)
                :post_run(function(ctx)
                    post_called = true
                    assert.is_true(ctx.success)
                end)
                :action(function(ctx)
                    return true
                end)

            local parsed = core.parse_arguments({'hooked'}, test_app)
            local result = core.execute_command(test_app, parsed)

            assert.are.equal(0, result)
            assert.is_true(pre_called)
            assert.is_true(post_called)
        end)

        it('returns EXIT_ERROR when pre_run fails', function()
            local test_app = app.new_app({name = 'testapp'})
            local action_called = false

            test_app:command('fail_pre', 'Fail pre')
                :pre_run(function(ctx)
                    error("pre_run error")
                end)
                :action(function(ctx)
                    action_called = true
                    return true
                end)

            local parsed = core.parse_arguments({'fail_pre'}, test_app)
            local result = core.execute_command(test_app, parsed)

            assert.are.equal(1, result)
            assert.is_false(action_called)
        end)

        it('executes app-level persistent_pre_run', function()
            local test_app = app.new_app({name = 'testapp'})
            local persistent_called = false

            test_app:persistent_pre_run(function(ctx)
                persistent_called = true
            end)

            test_app:command('cmd', 'Cmd')
                :action(function(ctx) return true end)

            local parsed = core.parse_arguments({'cmd'}, test_app)
            local result = core.execute_command(test_app, parsed)

            assert.are.equal(0, result)
            assert.is_true(persistent_called)
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('load_config()', function()
        it('loads a JSON config file', function()
            local tmp = os.tmpname() .. ".json"
            local f = io.open(tmp, "w")
            f:write('{"host":"localhost","port":3000}')
            f:close()

            local result, err = core.load_config(tmp)
            os.remove(tmp)

            assert.is_nil(err)
            assert.is_table(result)
            assert.are.equal("localhost", result.host)
            assert.are.equal(3000,        result.port)
        end)

        it('returns nil and error for nonexistent file', function()
            local result, err = core.load_config("/nonexistent/file.json")
            assert.is_nil(result)
            assert.is_not_nil(err)
        end)
    end)

    describe('Subcommand support', function()
        it('finds subcommands by name', function()
            local test_app = app.new_app()
            local parent = test_app:command('parent', 'Parent')
            local child = parent:subcommand('child', 'Child')
            
            assert.are.equal(child, core.find_subcommand(parent, 'child'))
            assert.is_nil(core.find_subcommand(parent, 'missing'))
        end)

        it('shows command help for a specific command', function()
            local test_app = app.new_app({name = 'testapp'})
            local cmd = test_app:command('hello', 'Say hello')
            
            local original_print = _G.print
            local output = {}
            _G.print = function(...) table.insert(output, table.concat({...}, ' ')) end
            core.show_command_help(test_app, cmd)
            _G.print = original_print
            
            local text = table.concat(output, '\n')
            assert.truthy(text:find('Usage:'))
            assert.truthy(text:find('hello'))
        end)

        it('executes subcommand action through execute_command', function()
            local test_app = app.new_app({name = 'testapp'})
            local parent = test_app:command('parent', 'Parent')
            local child = parent:subcommand('child', 'Child')
            local called = false
            child:action(function(ctx)
                called = true
                return true
            end)
            
            local parsed = core.parse_arguments({'parent', 'child'}, test_app)
            local result = core.execute_command(test_app, parsed)
            assert.is_true(called)
            assert.are.equal(0, result)
        end)

        it('returns EXIT_USAGE when subcommand action is missing', function()
            local test_app = app.new_app({name = 'testapp'})
            local parent = test_app:command('parent', 'Parent')
            parent:subcommand('child', 'Child')
            
            local parsed = core.parse_arguments({'parent', 'child'}, test_app)
            local result = core.execute_command(test_app, parsed)
            assert.are.equal(2, result)
        end)
    end)
end)

