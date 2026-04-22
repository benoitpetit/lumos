-- YAML module tests
local yaml = require('lumos.yaml')

describe("YAML Module", function()
    describe("decode", function()
        it("parses simple scalar strings", function()
            assert.are.equal("hello", yaml.decode("hello"))
        end)

        it("parses booleans", function()
            assert.is_true(yaml.decode("true"))
            assert.is_true(yaml.decode("True"))
            assert.is_false(yaml.decode("false"))
            assert.is_nil(yaml.decode("null"))
            assert.is_nil(yaml.decode("~"))
        end)

        it("parses numbers", function()
            assert.are.equal(42, yaml.decode("42"))
            assert.are.equal(3.14, yaml.decode("3.14"))
            assert.are.equal(-10, yaml.decode("-10"))
        end)

        it("parses quoted strings", function()
            assert.are.equal("hello", yaml.decode('"hello"'))
            assert.are.equal("hello", yaml.decode("'hello'"))
        end)

        it("parses sequences (arrays)", function()
            local result = yaml.decode([[
- one
- two
- three
]])
            assert.are.same({"one", "two", "three"}, result)
        end)

        it("parses mappings (objects)", function()
            local result = yaml.decode([[
name: Alice
age: 30
active: true
]])
            assert.are.equal("Alice", result.name)
            assert.are.equal(30, result.age)
            assert.is_true(result.active)
        end)

        it("parses nested mappings", function()
            local result = yaml.decode([[
person:
  name: Bob
  age: 25
]])
            assert.are.equal("Bob", result.person.name)
            assert.are.equal(25, result.person.age)
        end)

        it("parses inline sequences", function()
            local result = yaml.decode("[1, 2, 3]")
            assert.are.same({1, 2, 3}, result)
        end)

        it("parses inline mappings", function()
            local result = yaml.decode("{a: 1, b: 2}")
            assert.are.equal(1, result.a)
            assert.are.equal(2, result.b)
        end)

        it("parses block literal scalars", function()
            local result = yaml.decode("|\n  line one\n  line two\n")
            assert.are.equal("line one\nline two", result)
        end)

        it("parses block folded scalars", function()
            local result = yaml.decode(">\n  line one\n  line two\n")
            assert.are.equal("line one line two", result)
        end)

        it("errors on empty string", function()
            assert.has_error(function() yaml.decode("") end)
        end)

        it("errors on non-string input", function()
            assert.has_error(function() yaml.decode(123) end)
        end)

        it("parses scalar anchors and aliases", function()
            local result = yaml.decode([[
foo: &bar "hello"
baz: *bar
]])
            assert.are.equal("hello", result.foo)
            assert.are.equal("hello", result.baz)
        end)

        it("parses array anchors and aliases", function()
            local result = yaml.decode([[
items: &list
  - a
  - b
  - c

copy: *list
]])
            assert.are.equal(3, #result.items)
            assert.are.equal("a", result.copy[1])
            assert.are.equal("b", result.copy[2])
            assert.are.equal("c", result.copy[3])
        end)

        it("parses nested anchors and aliases", function()
            local result = yaml.decode([[
defaults:
  adapter: &adapt "postgres"
  host: localhost

test:
  adapter: *adapt
]])
            assert.are.equal("postgres", result.defaults.adapter)
            assert.are.equal("postgres", result.test.adapter)
        end)
    end)

    describe("encode", function()
        it("encodes plain strings without quotes when safe", function()
            assert.are.equal("hello", yaml.encode("hello"))
        end)

        it("encodes strings that need quoting with double quotes", function()
            assert.are.equal('":hello"', yaml.encode(":hello"))
        end)

        it("encodes numbers", function()
            assert.are.equal("42", yaml.encode(42))
            assert.are.equal("3.14", yaml.encode(3.14))
        end)

        it("encodes booleans", function()
            assert.are.equal("true", yaml.encode(true))
            assert.are.equal("false", yaml.encode(false))
        end)

        it("encodes nil", function()
            assert.are.equal("null", yaml.encode(nil))
        end)

        it("encodes arrays", function()
            local encoded = yaml.encode({"a", "b", "c"})
            assert.is_truthy(encoded:find("- a"))
            assert.is_truthy(encoded:find("- b"))
            assert.is_truthy(encoded:find("- c"))
        end)

        it("encodes objects", function()
            local encoded = yaml.encode({name = "Alice", age = 30})
            assert.is_truthy(encoded:find("name: Alice"))
            assert.is_truthy(encoded:find("age: 30"))
        end)

        it("encodes nested tables", function()
            local encoded = yaml.encode({person = {name = "Bob"}})
            assert.is_truthy(encoded:find("person:"))
            assert.is_truthy(encoded:find("name: Bob"))
        end)
    end)

    describe("roundtrip", function()
        it("preserves simple values", function()
            local data = {name = "test", count = 5, active = true, empty = nil}
            local encoded = yaml.encode(data)
            local decoded = yaml.decode(encoded)
            assert.are.equal("test", decoded.name)
            assert.are.equal(5, decoded.count)
            assert.is_true(decoded.active)
        end)
    end)
end)
