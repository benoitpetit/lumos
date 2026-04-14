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

    it('encodes nil as null', function()
      assert.are.equal('null', json.encode(nil))
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

    it('encodes nested tables', function()
      local result = json.encode({a = {b = 1}})
      assert.is_not_nil(result:match('"a"'))
      assert.is_not_nil(result:match('"b"'))
      assert.is_not_nil(result:match('1'))
    end)
  end)

  describe('decode function', function()
    it('decodes a JSON string', function()
      local result = json.decode('"hello"')
      assert.are.equal("hello", result)
    end)

    it('decodes a JSON number (integer)', function()
      local result = json.decode('42')
      assert.are.equal(42, result)
    end)

    it('decodes a JSON float', function()
      local result = json.decode('3.14')
      assert.are.equal(3.14, result)
    end)

    it('decodes JSON true and false', function()
      assert.is_true(json.decode('true'))
      assert.is_false(json.decode('false'))
    end)

    it('decodes JSON null as nil', function()
      local result = json.decode('null')
      assert.is_nil(result)
    end)

    it('decodes a JSON array', function()
      local result = json.decode('[1,2,3]')
      assert.is_table(result)
      assert.are.equal(1, result[1])
      assert.are.equal(2, result[2])
      assert.are.equal(3, result[3])
    end)

    it('decodes a JSON object', function()
      local result = json.decode('{"name":"Bob","age":25}')
      assert.is_table(result)
      assert.are.equal("Bob", result.name)
      assert.are.equal(25, result.age)
    end)

    it('decodes nested JSON objects', function()
      local result = json.decode('{"user":{"id":1,"active":true}}')
      assert.is_table(result.user)
      assert.are.equal(1, result.user.id)
      assert.is_true(result.user.active)
    end)

    it('decodes escaped quotes in strings', function()
      local result = json.decode('"hello \\"world\\""')
      assert.are.equal('hello "world"', result)
    end)

    it('decodes an empty object', function()
      local result = json.decode('{}')
      assert.is_table(result)
    end)

    it('decodes an empty array', function()
      local result = json.decode('[]')
      assert.is_table(result)
    end)

    it('raises an error on invalid JSON', function()
      local ok, err = pcall(function()
        json.decode('{not valid}')
      end)
      assert.is_false(ok)
    end)

    it('roundtrips encode then decode correctly', function()
      local original = {name = "lumos", version = "0.1.0", active = true, count = 3}
      local encoded  = json.encode(original)
      local decoded  = json.decode(encoded)
      assert.are.equal(original.name,    decoded.name)
      assert.are.equal(original.version, decoded.version)
      assert.are.equal(original.active,  decoded.active)
      assert.are.equal(original.count,   decoded.count)
    end)
  end)
end)

