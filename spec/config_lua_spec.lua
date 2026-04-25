local config = require('lumos.config')

describe('Config Lua support', function()
  it('loads a .lua config file that returns a table', function()
    local tmp = os.tmpname() .. ".lua"
    local f = io.open(tmp, "w")
    f:write("return { name = 'test', count = 42, enabled = true }")
    f:close()

    local result, err = config.load_file(tmp)
    assert.is_nil(err)
    assert.are.equal("test", result.name)
    assert.are.equal(42, result.count)
    assert.is_true(result.enabled)

    os.remove(tmp)
  end)

  it('returns error for .lua that does not return a table', function()
    local tmp = os.tmpname() .. ".lua"
    local f = io.open(tmp, "w")
    f:write("print('hello')")
    f:close()

    local result, err = config.load_file(tmp)
    assert.is_nil(result)
    assert.is_not_nil(err)
    -- With sandbox, print is nil so it raises an execution error;
    -- without sandbox it would be "Lua config must return a table"
    assert.is_true(err:find("Lua config must return a table") ~= nil or err:find("nil value") ~= nil)

    os.remove(tmp)
  end)

  it('returns error for invalid .lua syntax', function()
    local tmp = os.tmpname() .. ".lua"
    local f = io.open(tmp, "w")
    f:write("function bad( return end")
    f:close()

    local result, err = config.load_file(tmp)
    assert.is_nil(result)
    assert.is_not_nil(err)
    assert.is_true(err:find("Invalid Lua") ~= nil)

    os.remove(tmp)
  end)
end)
