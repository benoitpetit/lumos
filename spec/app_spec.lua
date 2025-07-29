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
end)
