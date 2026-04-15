local prompt = require('lumos.prompt')

describe('Prompt Module', function()
  local original_io_write = io.write
  local original_io_read = io.read
  local original_os_execute = os.execute
  local original_print = _G.print
  local original_io_open = io.open
  local original_os_getenv = os.getenv
  local written_output = ""
  local read_responses = {}
  local read_index = 1

  before_each(function()
    written_output = ""
    read_responses = {}
    read_index = 1

    -- Mock io.write
    io.write = function(text)
      written_output = written_output .. text
    end

    -- Mock io.read
    io.read = function(pattern)
      local response = read_responses[read_index]
      read_index = read_index + 1
      return response or ""
    end

    -- Mock os.execute to avoid stty commands and editor calls
    -- Return false for stty size so has_stty() returns false,
    -- forcing select/multiselect to fall back to simple_select.
    os.execute = function(cmd)
      if type(cmd) == "string" and cmd:match("stty size") then
        return false
      end
      return true
    end

    -- Mock print to capture output
    print = function(text)
      written_output = written_output .. (text or "") .. "\n"
    end

    -- Default io.open and os.getenv mocks (can be overridden in tests)
    io.open = original_io_open
    os.getenv = original_os_getenv
  end)

  after_each(function()
    -- Restore original functions
    io.write = original_io_write
    io.read = original_io_read
    os.execute = original_os_execute
    _G.print = original_print
    io.open = original_io_open
    os.getenv = original_os_getenv
  end)

  describe('input function', function()
    it('prompts for input without default', function()
      read_responses = {"test input"}

      local result = prompt.input("Enter value")

      assert.is_not_nil(written_output:match("Enter value: "))
      assert.are.equal("test input", result)
    end)

    it('prompts for input with default', function()
      read_responses = {""}  -- Empty input should use default

      local result = prompt.input("Enter value", "default")

      assert.is_not_nil(written_output:match("Enter value %[default%]: "))
      assert.are.equal("default", result)
    end)

    it('uses user input over default when provided', function()
      read_responses = {"user input"}

      local result = prompt.input("Enter value", "default")

      assert.are.equal("user input", result)
    end)
  end)

  describe('confirm function', function()
    it('returns true for yes responses', function()
      read_responses = {"y"}

      local result = prompt.confirm("Continue?")

      assert.is_true(result)
    end)

    it('returns false for no responses', function()
      read_responses = {"n"}

      local result = prompt.confirm("Continue?")

      assert.is_false(result)
    end)

    it('accepts full word responses', function()
      read_responses = {"yes"}

      local result = prompt.confirm("Continue?")

      assert.is_true(result)
    end)

    it('uses default value for empty input', function()
      read_responses = {""}

      local result = prompt.confirm("Continue?", true)

      assert.is_true(result)
    end)

    it('handles invalid input by reprompting', function()
      read_responses = {"maybe", "y"}

      local result = prompt.confirm("Continue?")

      assert.is_true(result)
    end)
  end)

  describe('validate function', function()
    it('returns true for valid input', function()
      local validator = function(input) return #input > 3 end

      local valid, result = prompt.validate("valid", validator)

      assert.is_true(valid)
      assert.are.equal("valid", result)
    end)

    it('returns false for invalid input', function()
      local validator = function(input) return #input > 3 end

      local valid, result = prompt.validate("no", validator, "Too short")

      assert.is_false(valid)
      assert.are.equal("Too short", result)
    end)

    it('uses default error message', function()
      local validator = function(input) return false end

      local valid, result = prompt.validate("test", validator)

      assert.is_false(valid)
      assert.are.equal("Invalid input", result)
    end)
  end)

  describe('Input Validation', function()
    it('validates email addresses', function()
      assert.is_true(prompt.validators.email('test@example.com'))
      assert.is_false(prompt.validators.email('invalid-email'))
    end)

    it('validates numbers', function()
      assert.is_true(prompt.validators.number('12345'))
      assert.is_false(prompt.validators.number('abc'))
    end)
  end)

  describe('number function', function()
    it('returns a valid number', function()
      read_responses = {"42"}
      local result = prompt.number("Enter a number")
      assert.are.equal(42, result)
    end)

    it('uses default for empty input', function()
      read_responses = {""}
      local result = prompt.number("Enter a number", nil, nil, 7)
      assert.are.equal(7, result)
    end)

    it('reprompts for non-numeric input', function()
      read_responses = {"abc", "10"}
      local result = prompt.number("Enter a number")
      assert.are.equal(10, result)
    end)

    it('enforces min constraint', function()
      read_responses = {"2", "5"}
      local result = prompt.number("Enter a number", 3, nil)
      assert.are.equal(5, result)
    end)

    it('enforces max constraint', function()
      read_responses = {"100", "50"}
      local result = prompt.number("Enter a number", nil, 60)
      assert.are.equal(50, result)
    end)
  end)

  describe('required_input function', function()
    it('returns input when provided', function()
      read_responses = {"hello"}
      local result = prompt.required_input("Required field")
      assert.are.equal("hello", result)
    end)

    it('reprompts for empty input', function()
      read_responses = {"", "value"}
      local result = prompt.required_input("Required field")
      assert.are.equal("value", result)
    end)

    it('reprompts for invalid input', function()
      read_responses = {"ab", "yes"}
      local result = prompt.required_input("Required field", function(v) return #v >= 3 end, "Too short")
      assert.are.equal("yes", result)
    end)
  end)

  describe('autocomplete function', function()
    it('returns exact match when unique', function()
      read_responses = {"app"}
      local result = prompt.autocomplete("Choose", {"apple", "banana", "apricot"})
      assert.are.equal("apple", result)
    end)

    it('prompts to select when ambiguous', function()
      read_responses = {"ba", "1"}
      local result = prompt.autocomplete("Choose", {"banana", "bandana", "apple"})
      assert.are.equal("banana", result)
    end)

    it('uses default for empty input', function()
      read_responses = {""}
      local result = prompt.autocomplete("Choose", {"a", "b"}, "b")
      assert.are.equal("b", result)
    end)
  end)

  describe('search function', function()
    it('filters options and returns selected', function()
      -- "Filter: ba", then select "1" for banana
      read_responses = {"ba", "1"}
      local _, result = prompt.search("Choose", {"apple", "banana", "cherry"})
      assert.are.equal("banana", result)
    end)

    it('loops until a match is found', function()
      read_responses = {"zz", "", "1"}
      local _, result = prompt.search("Choose", {"apple", "banana"})
      assert.are.equal("apple", result)
    end)
  end)

  describe('editor function', function()
    it('reads content from temporary file', function()
      os.getenv = function(var)
        if var == "EDITOR" or var == "VISUAL" then
          return "cat"
        end
        return nil
      end
      -- default content will be written to tmp file
      local result = prompt.editor("Edit", "hello world")
      assert.are.equal("hello world", result)
    end)
  end)

  describe('form function', function()
    it('collects values from multiple fields', function()
      read_responses = {"Alice", "25", "secret", "1"}
      local result = prompt.form("User Info", {
        {name="name", label="Name", type="input"},
        {name="age", label="Age", type="number"},
        {name="pass", label="Password", type="password"},
        {name="role", label="Role", type="select", options={"admin", "user"}},
      })
      assert.are.equal("Alice", result.name)
      assert.are.equal(25, result.age)
      assert.are.equal("secret", result.pass)
      assert.are.equal("admin", result.role)
    end)

    it('supports autocomplete field', function()
      read_responses = {"app"}
      local result = prompt.form(nil, {
        {name="fruit", label="Fruit", type="autocomplete", options={"apple", "banana"}}
      })
      assert.are.equal("apple", result.fruit)
    end)

    it('supports editor field', function()
      os.getenv = function(var)
        if var == "EDITOR" then return "cat" end
        return nil
      end
      local result = prompt.form(nil, {
        {name="bio", label="Bio", type="editor", default="hello"}
      })
      assert.are.equal("hello", result.bio)
    end)

    it('enforces required fields without a validator', function()
      read_responses = {"", "Alice"}
      local result = prompt.form(nil, {
        {name="name", label="Name", type="input", required=true}
      })
      assert.are.equal("Alice", result.name)
    end)

    it('enforces required password fields', function()
      read_responses = {"", "secret"}
      local result = prompt.form(nil, {
        {name="pass", label="Password", type="password", required=true}
      })
      assert.are.equal("secret", result.pass)
    end)
  end)

  describe('wizard function', function()
    it('collects data across multiple steps', function()
      read_responses = {"Bob", "yes"}
      local result = prompt.wizard("Setup", {
        {title="Profile", fields={
          {name="username", label="Username", type="input"}
        }},
        {title="Confirm", fields={
          {name="ok", label="Continue?", type="confirm", default=true}
        }},
      })
      assert.are.equal("Bob", result.username)
      assert.is_true(result.ok)
    end)

    it('executes step actions and returns nil on error', function()
      read_responses = {"x"}
      local result, err = prompt.wizard("Setup", {
        {title="Step 1", fields={
          {name="val", label="Value", type="input"}
        }, action=function()
          error("boom")
        end},
      })
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)
  end)

  describe('Additional validators', function()
    it('validates integers', function()
      assert.is_true(prompt.validators.integer("42"))
      assert.is_false(prompt.validators.integer("3.14"))
      assert.is_false(prompt.validators.integer("abc"))
    end)

    it('validates urls', function()
      assert.is_true(prompt.validators.url("https://example.com"))
      assert.is_true(prompt.validators.url("http://example.org"))
      assert.is_false(prompt.validators.url("ftp://example.com"))
      assert.is_false(prompt.validators.url("not a url"))
    end)

    it('validates non_empty', function()
      assert.is_true(prompt.validators.non_empty("hello"))
      assert.is_false(prompt.validators.non_empty(""))
      assert.is_false(prompt.validators.non_empty(nil))
    end)

    it('validates one_of', function()
      local validator = prompt.validators.one_of({"a", "b", "c"})
      assert.is_true(validator("b"))
      assert.is_false(validator("z"))
    end)

    it('validates regex', function()
      local validator = prompt.validators.regex("^[A-Z]+$")
      assert.is_true(validator("HELLO"))
      assert.is_false(validator("hello"))
    end)
  end)
end)
