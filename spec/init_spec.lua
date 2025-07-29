local lumos = require('lumos')

describe('Lumos Main Module', function()
  describe('module exports', function()
    it('exports new_app function', function()
      assert.is_function(lumos.new_app)
    end)

    it('exports all submodules', function()
      assert.is_table(lumos.app)
      assert.is_table(lumos.core)
      assert.is_table(lumos.flags)
      assert.is_table(lumos.color)
      assert.is_table(lumos.loader)
      assert.is_table(lumos.progress)
      assert.is_table(lumos.prompt)
      assert.is_table(lumos.table)
    end)

    it('has correct version', function()
      assert.are.equal('0.1.0', lumos.version)
    end)

    it('can create an application', function()
      local app = lumos.new_app({name = 'test'})
      assert.are.equal('test', app.name)
    end)
  end)

  describe('integration', function()
    it('creates a functional application with all features', function()
      local app = lumos.new_app({
        name = 'integration-test',
        version = '0.1.0'
      })
      
      -- Add global flag
      app:flag('-v --verbose', 'Verbose output')
      
      -- Add command
      local cmd = app:command('test', 'Test command')
      cmd:arg('input', 'Input value')
      cmd:flag('-f --force', 'Force operation')
      cmd:action(function(ctx)
        return true
      end)
      
      -- Verify structure
      assert.are.equal('integration-test', app.name)
      assert.are.equal('0.1.0', app.version)
      assert.is_table(app.global_flags.verbose)
      assert.are.equal(1, #app.commands)
      assert.are.equal('test', app.commands[1].name)
      assert.is_function(app.commands[1].action)
    end)
  end)
end)
