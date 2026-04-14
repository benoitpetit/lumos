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
            assert.is_true(result)
        end)

        it('returns false and prints error for unknown command', function()
            local test_app = app.new_app({name = 'testapp'})
            local original_print = _G.print
            local output = ""
            _G.print = function(s) output = output .. (s or "") end

            local parsed = {command = 'unknown', flags = {}, args = {}}
            local result = core.execute_command(test_app, parsed)

            _G.print = original_print
            assert.is_false(result)
            assert.is_not_nil(output:match("Unknown command"))
        end)

        it('shows help and returns true when no command given', function()
            local test_app = app.new_app({name = 'testapp'})
            local original_print = _G.print
            _G.print = function() end

            local parsed = {command = nil, flags = {}, args = {}}
            local result = core.execute_command(test_app, parsed)

            _G.print = original_print
            assert.is_true(result)
        end)

        it('returns false when command has no action', function()
            local test_app = app.new_app({name = 'testapp'})
            test_app:command('noop', 'Does nothing')  -- no :action()

            local original_print = _G.print
            _G.print = function() end

            local parsed = core.parse_arguments({'noop'}, test_app)
            local result = core.execute_command(test_app, parsed)

            _G.print = original_print
            assert.is_false(result)
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
end)

