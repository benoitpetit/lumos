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
end)

