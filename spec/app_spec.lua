local app = require('lumos.app')

describe('App Module', function()
  describe('Application creation', function()
    it('creates an app with default values', function()
      local test_app = app.new_app()
      
      assert.are.equal('myapp', test_app.name)
      assert.are.equal('0.1.0', test_app.version)
      assert.are.equal('A Lua CLI application', test_app.description)
      assert.is_table(test_app.commands)
      assert.is_table(test_app.global_flags)
    end)

    it('creates an app with custom config', function()
      local config = {
        name = 'testapp',
        version = '1.2.3',
        description = 'Test application'
      }
      local test_app = app.new_app(config)
      
      assert.are.equal('testapp', test_app.name)
      assert.are.equal('1.2.3', test_app.version)
      assert.are.equal('Test application', test_app.description)
    end)
  end)

  describe('Command creation', function()
    it('creates commands with fluent API', function()
      local test_app = app.new_app()
      local cmd = test_app:command('test', 'Test command')
      
      assert.are.equal('test', cmd.name)
      assert.are.equal('Test command', cmd.description)
      assert.is_table(cmd.flags)
      assert.is_table(cmd.args)
    end)

    it('adds commands to app', function()
      local test_app = app.new_app()
      test_app:command('cmd1', 'Command 1')
      test_app:command('cmd2', 'Command 2')
      
      assert.are.equal(2, #test_app.commands)
      assert.are.equal('cmd1', test_app.commands[1].name)
      assert.are.equal('cmd2', test_app.commands[2].name)
    end)
  end)

  describe('Command configuration', function()
    it('adds arguments to commands', function()
      local test_app = app.new_app()
      local cmd = test_app:command('test', 'Test')
      cmd:arg('filename', 'File to process'):arg('output', 'Output file')
      
      assert.are.equal(2, #cmd.args)
      assert.are.equal('filename', cmd.args[1].name)
      assert.are.equal('File to process', cmd.args[1].description)
    end)

    it('adds flags to commands', function()
      local test_app = app.new_app()
      local cmd = test_app:command('test', 'Test')
      cmd:flag('-v --verbose', 'Verbose output')
      
      assert.is_table(cmd.flags.verbose)
      assert.are.equal('v', cmd.flags.verbose.short)
      assert.are.equal('verbose', cmd.flags.verbose.long)
      assert.are.equal('boolean', cmd.flags.verbose.type)
    end)

    it('adds options to commands', function()
      local test_app = app.new_app()
      local cmd = test_app:command('test', 'Test')
      cmd:option('-o --output', 'Output file')
      
      assert.is_table(cmd.flags.output)
      assert.are.equal('o', cmd.flags.output.short)
      assert.are.equal('output', cmd.flags.output.long)
      assert.are.equal('string', cmd.flags.output.type)
    end)

    it('sets action function', function()
      local test_app = app.new_app()
      local cmd = test_app:command('test', 'Test')
      local action_called = false
      
      cmd:action(function() 
        action_called = true
        return true
      end)
      
      assert.is_function(cmd.action)
    end)
  end)

  describe('Global flags', function()
    it('adds global flags to app', function()
      local test_app = app.new_app()
      test_app:flag('-v --verbose', 'Verbose output')
      
      assert.is_table(test_app.global_flags.verbose)
      assert.are.equal('v', test_app.global_flags.verbose.short)
      assert.are.equal('verbose', test_app.global_flags.verbose.long)
    end)
  end)

  describe('Fluent flag modifiers', function()
    it('supports :default() chaining', function()
      local test_app = app.new_app()
      local cmd = test_app:command('test', 'Test')
      cmd:flag_string('--format', 'Format'):default('json')
      
      assert.are.equal('json', cmd.flags.format.default)
    end)

    it('supports :required() chaining', function()
      local test_app = app.new_app()
      local cmd = test_app:command('test', 'Test')
      cmd:flag_string('--token', 'Token'):required(true)
      
      assert.is_true(cmd.flags.token.required)
    end)

    it('supports :env() chaining', function()
      local test_app = app.new_app()
      local cmd = test_app:command('test', 'Test')
      cmd:flag_string('--api-key', 'API Key'):env('MYAPP_API_KEY')
      
      assert.are.equal('MYAPP_API_KEY', cmd.flags['api_key'].env)
    end)

    it('supports :validate() chaining', function()
      local test_app = app.new_app()
      local cmd = test_app:command('test', 'Test')
      local validator = function(v) return v ~= "" end
      cmd:flag_string('--name', 'Name'):validate(validator)
      
      assert.is_function(cmd.flags.name.custom_validator)
    end)
  end)

  describe('Command categories and hooks', function()
    it('supports :category()', function()
      local test_app = app.new_app()
      local cmd = test_app:command('deploy', 'Deploy'):category('Ops')
      
      assert.are.equal('Ops', cmd._category)
    end)

    it('supports :pre_run() and :post_run()', function()
      local test_app = app.new_app()
      local cmd = test_app:command('test', 'Test')
      cmd:pre_run(function() end):post_run(function() end)
      
      assert.are.equal(1, #cmd.pre_runs)
      assert.are.equal(1, #cmd.post_runs)
    end)
  end)

  describe('app:run()', function()
    it('executes the matching command and returns true', function()
      local test_app = app.new_app({name = 'testapp', version = '1.0.0'})
      local executed = false

      test_app:command('greet', 'Say hello'):action(function(ctx)
        executed = true
        return true
      end)

      local result = test_app:run({'greet'})
      assert.is_true(executed)
      assert.are.equal(0, result)
    end)

    it('returns false for an unknown command', function()
      local test_app = app.new_app({name = 'testapp'})
      -- Suppress the help output during this test
      local original_print = _G.print
      _G.print = function() end
      local result = test_app:run({'nonexistent'})
      _G.print = original_print
      assert.are.equal(2, result)
    end)

    it('passes parsed flags to the command action', function()
      local test_app = app.new_app({name = 'testapp'})
      local received_flags = {}

      local cmd = test_app:command('build', 'Build something')
      cmd:flag('-v --verbose', 'Verbose mode')
      cmd:action(function(ctx)
        received_flags = ctx.flags
        return true
      end)

      test_app:run({'build', '--verbose'})
      assert.is_true(received_flags.verbose)
    end)

    it('passes positional args to the command action', function()
      local test_app = app.new_app({name = 'testapp'})
      local received_args = {}

      test_app:command('process', 'Process files')
        :arg('file', 'File to process')
        :action(function(ctx)
          received_args = ctx.args
          return true
        end)

      test_app:run({'process', 'myfile.txt'})
      assert.are.equal('myfile.txt', received_args[1])
    end)

    it('returns true and prints version when --version flag is set', function()
      local test_app = app.new_app({name = 'myapp', version = '2.0.0'})
      local printed = ""
      local original_print = _G.print
      _G.print = function(s) printed = printed .. (s or "") end

      local result = test_app:run({'--version'})

      _G.print = original_print
      assert.are.equal(0, result)
      assert.is_not_nil(printed:match("2%.0%.0"))
    end)

    it('shows --version (without -v) in help when -v is user-defined', function()
      local test_app = app.new_app({name = 'myapp', version = '2.0.0'})
      test_app:flag('-v --verbose', 'Verbose mode')

      local output = {}
      local original_print = _G.print
      _G.print = function(...)
        table.insert(output, table.concat({...}, ' '))
      end

      local result = test_app:run({'--help'})

      _G.print = original_print
      assert.are.equal(0, result)
      local text = table.concat(output, '\n')
      assert.truthy(text:find('%-%-version'))
      assert.falsy(text:find('%-v, %-%-version'))
    end)

    it('treats -v as verbose when user defines -v flag', function()
      local test_app = app.new_app({name = 'myapp', version = '2.0.0'})
      local saw_verbose = false

      local cmd = test_app:command('run', 'Run command')
      cmd:flag('-v --verbose', 'Verbose mode')
      cmd:action(function(ctx)
        saw_verbose = ctx.flags.verbose == true
        return true
      end)

      local result = test_app:run({'run', '-v'})
      assert.are.equal(0, result)
      assert.is_true(saw_verbose)
    end)

    it('handles empty args and shows help', function()
      local test_app = app.new_app({name = 'testapp'})
      local original_print = _G.print
      _G.print = function() end
      local result = test_app:run({})
      _G.print = original_print
      -- show_help returns EXIT_OK
      assert.are.equal(0, result)
    end)

    it('supports mutex groups', function()
      local test_app = app.new_app({name = 'testapp'})
      local cmd = test_app:command('deploy', 'Deploy')
      cmd:flag_string('-f --file', 'File')
      cmd:flag_string('-u --url', 'URL')
      cmd:mutex_group('input', {'file', 'url'}, { required = true })
      cmd:action(function() return true end)

      local original_print = _G.print
      _G.print = function() end
      local original_stderr = io.stderr
      local stderr_output = ""
      _G.io.stderr = { write = function(_, s) stderr_output = stderr_output .. (s or "") end, flush = function() end }

      -- Neither provided -> required error
      local r1 = test_app:run({'deploy'})
      assert.are.equal(2, r1)

      -- Both provided -> mutex error
      stderr_output = ""
      local r2 = test_app:run({'deploy', '--file', 'a.txt', '--url', 'http://x'})
      assert.are.equal(2, r2)
      assert.truthy(stderr_output:find("mutually exclusive") or stderr_output:find("exclusive"))

      -- One provided -> OK
      local r3 = test_app:run({'deploy', '--file', 'a.txt'})
      assert.are.equal(0, r3)

      _G.io.stderr = original_stderr
      _G.print = original_print
    end)

    it('supports middleware chain', function()
      local test_app = app.new_app({name = 'testapp'})
      local order = {}
      test_app:use(function(ctx, next)
        table.insert(order, 'app')
        return next()
      end)
      local cmd = test_app:command('build', 'Build')
      cmd:use(function(ctx, next)
        table.insert(order, 'cmd')
        return next()
      end)
      cmd:action(function(ctx)
        table.insert(order, 'action')
        return true
      end)

      test_app:run({'build'})
      assert.same({'app', 'cmd', 'action'}, order)
    end)

    it('middleware can short-circuit action', function()
      local test_app = app.new_app({name = 'testapp'})
      local cmd = test_app:command('build', 'Build')
      cmd:use(function(ctx, next)
        return require('lumos.error').new("INVALID_ARGUMENT", "blocked")
      end)
      cmd:action(function(ctx)
        return true
      end)

      local original_stderr = io.stderr
      local stderr_output = ""
      _G.io.stderr = { write = function(_, s) stderr_output = stderr_output .. (s or "") end, flush = function() end }
      local result = test_app:run({'build'})
      _G.io.stderr = original_stderr
      assert.are.equal(1, result)
      assert.truthy(stderr_output:find("blocked"))
    end)

    it('supports float flags', function()
      local test_app = app.new_app({name = 'testapp'})
      local received
      test_app:command('scale', 'Scale')
        :flag_float('-r --rate', 'Rate', { min = 0, max = 1, precision = 2 })
        :action(function(ctx)
          received = ctx.flags.rate
          return true
        end)
      test_app:run({'scale', '--rate', '0.7555'})
      assert.are.equal(0.76, received)
    end)

    it('supports array flags', function()
      local test_app = app.new_app({name = 'testapp'})
      local received
      test_app:command('tags', 'Tags')
        :flag_array('-t --tags', 'Tags', { separator = ',', unique = true })
        :action(function(ctx)
          received = ctx.flags.tags
          return true
        end)
      test_app:run({'tags', '--tags', 'a,b,c'})
      assert.same({'a', 'b', 'c'}, received)
    end)

    it('supports enum flags', function()
      local test_app = app.new_app({name = 'testapp'})
      local received
      test_app:command('level', 'Level')
        :flag_enum('-l --level', 'Level', {'debug', 'info', 'warn'})
        :action(function(ctx)
          received = ctx.flags.level
          return true
        end)
      test_app:run({'level', '--level', 'INFO'})
      assert.are.equal('info', received)
    end)

    it('handles typed errors from actions', function()
      local test_app = app.new_app({name = 'testapp'})
      test_app:command('fail', 'Fail'):action(function(ctx)
        return require('lumos.error').new("EXECUTION_FAILED", "boom", { exit_code = 7 })
      end)
      local original_stderr = io.stderr
      local stderr_output = ""
      _G.io.stderr = { write = function(_, s) stderr_output = stderr_output .. (s or "") end, flush = function() end }
      local result = test_app:run({'fail'})
      _G.io.stderr = original_stderr
      assert.are.equal(7, result)
      assert.truthy(stderr_output:find("boom"))
    end)

    it('handles success objects from actions', function()
      local test_app = app.new_app({name = 'testapp'})
      test_app:command('ok', 'OK'):action(function(ctx)
        return require('lumos.error').success({ id = 42 })
      end)
      local result = test_app:run({'ok'})
      assert.are.equal(0, result)
    end)
  end)

  describe('Subcommands', function()
    it('creates subcommands with fluent API', function()
      local test_app = app.new_app()
      local parent = test_app:command('parent', 'Parent command')
      local child = parent:subcommand('child', 'Child command')
      
      assert.are.equal('child', child.name)
      assert.are.equal('Child command', child.description)
      assert.are.equal(parent, child.parent)
      assert.are.equal(1, #parent.subcommands)
    end)

    it('executes subcommand actions', function()
      local test_app = app.new_app({name = 'testapp'})
      local parent = test_app:command('parent', 'Parent')
      local child = parent:subcommand('child', 'Child')
      local called = false
      child:action(function(ctx)
        called = true
        return true
      end)
      
      local result = test_app:run({'parent', 'child'})
      assert.is_true(called)
      assert.are.equal(0, result)
    end)

    it('validates subcommand args and flags', function()
      local test_app = app.new_app({name = 'testapp'})
      local parent = test_app:command('parent', 'Parent')
      local child = parent:subcommand('child', 'Child')
      child:arg('name', 'Name', {required = true})
      child:flag_int('--count', 'Count', 1, 10)
      child:action(function(ctx)
        assert.are.equal('alice', ctx.args[1])
        assert.are.equal(5, ctx.flags.count)
        return true
      end)
      
      local result = test_app:run({'parent', 'child', 'alice', '--count', '5'})
      assert.are.equal(0, result)
    end)

    it('shows help for subcommand', function()
      local test_app = app.new_app({name = 'testapp'})
      local parent = test_app:command('parent', 'Parent')
      local child = parent:subcommand('child', 'Child')
      
      local original_print = _G.print
      local output = {}
      _G.print = function(...) table.insert(output, table.concat({...}, ' ')) end
      local result = test_app:run({'parent', 'child', '--help'})
      _G.print = original_print
      
      assert.are.equal(0, result)
      local text = table.concat(output, '\n')
      assert.truthy(text:find('Usage:'))
    end)

    it('shows parent help when subcommand is unknown', function()
      local test_app = app.new_app({name = 'testapp'})
      local parent = test_app:command('parent', 'Parent')
      parent:subcommand('child', 'Child')
      
      local original_print = _G.print
      local output = {}
      _G.print = function(...) table.insert(output, table.concat({...}, ' ')) end
      local result = test_app:run({'parent', 'unknown'})
      _G.print = original_print
      
      assert.are.equal(0, result)
      local text = table.concat(output, '\n')
      assert.truthy(text:find('Usage:'))
    end)

    it('supports flag groups', function()
      local test_app = app.new_app({name = 'testapp'})
      local cmd = test_app:command('deploy', 'Deploy')
      cmd:flag_string('--host', 'Host'):group('Connection')
      cmd:flag_int('--port', 'Port'):group('Connection')
      cmd:flag_string('--format', 'Format'):group('Output')
      cmd:flag('--verbose', 'Verbose')

      assert.are.equal('Connection', cmd.flags.host._group)
      assert.are.equal('Connection', cmd.flags.port._group)
      assert.are.equal('Output', cmd.flags.format._group)
      assert.is_nil(cmd.flags.verbose._group)
    end)
  end)
end)
