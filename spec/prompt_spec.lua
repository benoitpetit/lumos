local prompt = require('lumos.prompt')

describe('Prompt Module', function()
  local original_io_write = io.write
  local original_io_read = io.read
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
  end)

  after_each(function()
    -- Restore original functions
    io.write = original_io_write
    io.read = original_io_read
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
      read_responses = {"invalid", "y"}
      
      local result = prompt.confirm("Continue?")
      
      assert.is_true(result)
      -- Should have prompted twice due to invalid input
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
end)
