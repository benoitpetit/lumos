local format = require('lumos.format')

describe('Lumos Format Module', function()
  describe('basic formatting', function()
    it('applies bold formatting', function()
      local result = format.bold("test")
      assert.is_string(result)
      -- When formatting is enabled, it should contain ANSI codes
      if format.is_enabled() then
        assert.matches("\27%[1m", result)
        assert.matches("\27%[0m", result)
      end
    end)

    it('applies italic formatting', function()
      local result = format.italic("test")
      assert.is_string(result)
      if format.is_enabled() then
        assert.matches("\27%[3m", result)
      end
    end)

    it('applies underline formatting', function()
      local result = format.underline("test")
      assert.is_string(result)
      if format.is_enabled() then
        assert.matches("\27%[4m", result)
      end
    end)

    it('applies strikethrough formatting', function()
      local result = format.strikethrough("test")
      assert.is_string(result)
      if format.is_enabled() then
        assert.matches("\27%[9m", result)
      end
    end)

    it('applies dim formatting', function()
      local result = format.dim("test")
      assert.is_string(result)
      if format.is_enabled() then
        assert.matches("\27%[2m", result)
      end
    end)

    it('applies reverse formatting', function()
      local result = format.reverse("test")
      assert.is_string(result)
      if format.is_enabled() then
        assert.matches("\27%[7m", result)
      end
    end)
  end)

  describe('template formatting', function()
    it('processes template with formatting codes', function()
      local template = "{bold}Hello{reset} {italic}World{reset}"
      local result = format.format(template)
      assert.is_string(result)
    end)

    it('strips formatting codes when disabled', function()
      format.disable()
      local template = "{bold}Hello{reset} {italic}World{reset}"
      local result = format.format(template)
      assert.are.equal("Hello World", result)
      format.enable()
    end)
  end)

  describe('text truncation', function()
    it('truncates long text with ellipsis', function()
      local result = format.truncate("this is a very long text", 10)
      assert.are.equal("this is...", result)
    end)

    it('keeps short text unchanged', function()
      local result = format.truncate("short", 10)
      assert.are.equal("short", result)
    end)

    it('uses custom ellipsis', function()
      local result = format.truncate("long text", 6, ">>")
      assert.are.equal("long>>", result)
    end)
  end)

  describe('word wrapping', function()
    it('wraps text to specified width', function()
      local lines = format.wrap("this is a long line that should be wrapped", 10)
      assert.is_table(lines)
      assert.is_true(#lines > 1)
      
      for _, line in ipairs(lines) do
        assert.is_true(#line <= 10)
      end
    end)

    it('handles single words longer than width', function()
      local lines = format.wrap("supercalifragilisticexpialidocious", 10)
      assert.is_table(lines)
      assert.are.equal(1, #lines)
    end)

    it('handles empty text', function()
      local lines = format.wrap("", 10)
      assert.is_table(lines)
      assert.are.equal(0, #lines)
    end)
  end)

  describe('case transformations', function()
    it('converts to title case', function()
      local result = format.title_case("hello world")
      assert.are.equal("Hello World", result)
    end)

    it('converts to camel case', function()
      local result = format.camel_case("hello_world_test")
      assert.are.equal("helloWorldTest", result)
    end)

    it('converts to snake case', function()
      local result = format.snake_case("HelloWorldTest")
      assert.are.equal("hello_world_test", result)
    end)

    it('converts to kebab case', function()
      local result = format.kebab_case("HelloWorldTest")
      assert.are.equal("hello-world-test", result)
    end)
  end)

  describe('format combining', function()
    it('combines multiple string formats', function()
      local result = format.combine("test", "bold", "underline")
      assert.is_string(result)
    end)

    it('combines function formats', function()
      local result = format.combine("test", format.bold, format.italic)
      assert.is_string(result)
    end)
  end)

  describe('enable/disable', function()
    it('can disable and enable formatting', function()
      local original_state = format.is_enabled()
      
      format.disable()
      assert.is_false(format.is_enabled())
      
      format.enable()
      assert.is_true(format.is_enabled())
      
      -- Restore original state
      if original_state then
        format.enable()
      else
        format.disable()
      end
    end)

    it('returns plain text when disabled', function()
      format.disable()
      local result = format.bold("test")
      assert.are.equal("test", result)
      format.enable()
    end)
  end)
end)
