local json = require('lumos.json')

describe('JSON Module', function()
  describe('encode function', function()
    it('encodes strings correctly', function()
      local result = json.encode("hello")
      assert.are.equal('"hello"', result)
    end)

    it('encodes numbers correctly', function()
      local result = json.encode(42)
      assert.are.equal('42', result)
    end)

    it('encodes booleans correctly', function()
      assert.are.equal('true', json.encode(true))
      assert.are.equal('false', json.encode(false))
    end)

    it('encodes arrays correctly', function()
      local result = json.encode({1, 2, 3})
      assert.are.equal('[1,2,3]', result)
    end)

    it('encodes objects correctly', function()
      local result = json.encode({name = "Alice", age = 30})
      -- Order may vary, so check both possibilities
      local expected1 = '{"name":"Alice","age":30}'
      local expected2 = '{"age":30,"name":"Alice"}'
      assert.is_true(result == expected1 or result == expected2)
    end)

    it('escapes special characters in strings', function()
      local result = json.encode('hello "world"')
      assert.are.equal('"hello \\"world\\""', result)
    end)
  end)
end)
