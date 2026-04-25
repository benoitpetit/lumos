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
  -- validate_flag: boolean (no type) should pass through without error
  it('validate_flag returns true for a boolean flag value', function()
    local ok, val = flags.validate_flag({long = "verbose"}, true)
    assert.is_true(ok)
    assert.is_true(val)
  end)

  -- validate_flag: int type with a boolean value must return false (not nil)
  it('validate_flag returns false (not nil) for boolean value on int flag', function()
    local ok, msg = flags.validate_flag({type = "int", long = "count"}, true)
    assert.is_false(ok)
    assert.is_string(msg)
  end)

  -- parse_single_flag: a negative number after a long flag is treated as its value
  it('treats negative number as value of preceding long flag', function()
    local result = flags.parse_single_flag('--offset', {'--offset', '-5'}, 1)
    assert.are.same({name = 'offset', value = '-5', next_index = 3}, result)
  end)

  -- parse_single_flag: a negative number after a short flag is treated as its value
  it('treats negative number as value of preceding short flag', function()
    local result = flags.parse_single_flag('-n', {'-n', '-42'}, 1)
    assert.are.same({name = 'n', value = '-42', next_index = 3}, result)
  end)

  -- parse_single_flag: --no-flag negation
  it('parses --no-flag as false value', function()
    local result = flags.parse_single_flag('--no-verbose', {'--no-verbose'}, 1)
    assert.are.same({name = 'verbose', value = false, next_index = 2}, result)
  end)

  it('parses --no-dry-run as false value with hyphen', function()
    local result = flags.parse_single_flag('--no-dry-run', {'--no-dry-run'}, 1)
    assert.are.same({name = 'dry_run', value = false, next_index = 2}, result)
  end)
end)
