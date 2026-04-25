local app = require('lumos.app')
local core = require('lumos.core')

describe('App variadic args and dupe check', function()
  it('supports variadic positional arguments', function()
    local test_app = app.new_app({name = 'testapp'})
    local captured = nil

    test_app:command('copy', 'Copy files')
      :arg('dest', 'Destination', {required = true})
      :arg('sources', 'Files to copy', {variadic = true, required = true})
      :action(function(ctx)
        captured = ctx.args
        return true
      end)

    local parsed = core.parse_arguments({'copy', '/tmp', 'a.txt', 'b.txt'}, test_app)
    local result = core.execute_command(test_app, parsed)
    assert.are.equal(0, result)
    assert.are.equal('/tmp', captured[1])
    assert.are.same({'a.txt', 'b.txt'}, captured[2])
  end)

  it('variadic args can be empty when not required', function()
    local test_app = app.new_app({name = 'testapp'})
    local captured = nil

    test_app:command('list', 'List files')
      :arg('files', 'Files', {variadic = true})
      :action(function(ctx)
        captured = ctx.args
        return true
      end)

    local parsed = core.parse_arguments({'list'}, test_app)
    local result = core.execute_command(test_app, parsed)
    assert.are.equal(0, result)
    assert.are.same({}, captured[1])
  end)

  it('errors on duplicate flag long name', function()
    local test_app = app.new_app({name = 'testapp'})
    local cmd = test_app:command('test', 'Test')
    cmd:flag('-f --file', 'File')
    assert.has_error(function()
      cmd:flag('-f --file', 'Another file')
    end, "Duplicate flag: --file")
  end)

  it('errors on duplicate flag short name', function()
    local test_app = app.new_app({name = 'testapp'})
    local cmd = test_app:command('test', 'Test')
    cmd:flag('-f --file', 'File')
    assert.has_error(function()
      cmd:flag('-f --foo', 'Foo')
    end, "Duplicate short flag: -f")
  end)
end)
