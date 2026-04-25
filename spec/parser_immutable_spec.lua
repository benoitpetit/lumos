local parser = require('lumos.parser')

describe('Parser args immutability', function()
  it('does not mutate the input args table when expanding combined short flags', function()
    local args = {'-abc', 'value'}
    local original = {'-abc', 'value'}
    local app = { commands = {} }
    local parsed = parser.parse_arguments(args, app)
    assert.are.same(original, args)
  end)

  it('still correctly parses expanded flags', function()
    local args = {'-abc'}
    local app = { commands = {} }
    local parsed = parser.parse_arguments(args, app)
    assert.is_not_nil(parsed.flags.a)
    assert.is_not_nil(parsed.flags.b)
    assert.is_not_nil(parsed.flags.c)
  end)
end)
