local flags = require('lumos.flags')

describe('Flags Module', function()
  it('parses long flags with no value', function()
    local result = flags.parse_single_flag('--verbose', {}, 1)
    assert.are.same({name = 'verbose', value = true, next_index = 2}, result)
  end)

  it('parses long flags with value in equal sign', function()
    local result = flags.parse_single_flag('--file=example.txt', {}, 1)
    assert.are.same({name = 'file', value = 'example.txt', next_index = 2}, result)
  end)

  it('parses short flags with no value', function()
    local result = flags.parse_single_flag('-v', {}, 1)
    assert.are.same({name = 'v', value = true, next_index = 2}, result)
  end)

  it('parses short flags with concatenated value', function()
    local result = flags.parse_single_flag('-ofile', {}, 1)
    assert.are.same({name = 'o', value = 'file', next_index = 2}, result)
  end)
  it('parses --long and short -s formats', function()
    local app = require('lumos').new_app({name = "testapp"})
    app:persistent_flag("--verbose -v", "Enable verbose output")

    assert.is_not_nil(app.persistent_flags.verbose)
    assert.equal("v", app.persistent_flags.verbose.short)
    assert.equal("verbose", app.persistent_flags.verbose.long)
  end)

  it('parses -s and --long formats', function()
    local app = require('lumos').new_app({name = "testapp"})
    app:persistent_flag("-v --verbose", "Enable verbose output")

    assert.is_not_nil(app.persistent_flags.verbose)
    assert.equal("v", app.persistent_flags.verbose.short)
    assert.equal("verbose", app.persistent_flags.verbose.long)
  end)

  it('parses --long only', function()
    local app = require('lumos').new_app({name = "testapp"})
    app:persistent_flag("--verbose", "Enable verbose output")

    assert.is_not_nil(app.persistent_flags.verbose)
    assert.is_nil(app.persistent_flags.verbose.short)
    assert.equal("verbose", app.persistent_flags.verbose.long)
  end)

  it('parses -s only', function()
    local app = require('lumos').new_app({name = "testapp"})
    app:persistent_flag("-v", "Enable verbose output")

    assert.is_not_nil(app.persistent_flags.v)
    assert.equal("v", app.persistent_flags.v.short)
    assert.equal("v", app.persistent_flags.v.long)
  end)
end)
