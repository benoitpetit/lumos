local loader = require('lumos.loader')

describe('Loader Module', function()
  local original_io_write = io.write
  local original_io_flush = io.flush
  local written_output = ""

  before_each(function()
    written_output = ""
    -- Mock io.write and io.flush to capture output
    io.write = function(text)
      written_output = written_output .. text
    end
    io.flush = function() end
  end)

  after_each(function()
    -- Stop any active loader while mocks are still active
    if loader and type(loader.stop) == 'function' then
      loader.stop()
    end
    -- Clear the captured output so it doesn't leak
    written_output = ""
    -- Restore original functions
    io.write = original_io_write
    io.flush = original_io_flush
  end)

  describe('loader lifecycle', function()
    it('starts with default message and style', function()
      loader.start()

      assert.is_not_nil(written_output:match("Loading"))
      assert.is_not_nil(written_output:match("[|/%-\\]"))  -- Should contain spinner chars
    end)

    it('starts with custom message', function()
      loader.start("Custom loading")

      assert.is_not_nil(written_output:match("Custom loading"))
    end)

    it('starts with custom style', function()
      loader.start("Loading", "dots")

      assert.is_not_nil(written_output:match("Loading"))
      -- Should use dots style instead of standard
    end)

    it('stops loader with STOP message', function()
      loader.start("Test")
      written_output = ""  -- Clear previous output

      loader.stop()

      assert.is_not_nil(written_output:match("%[STOP%]"))
    end)

    it('completes with success message', function()
      loader.start("Test")
      written_output = ""

      loader.success()

      assert.is_not_nil(written_output:match("%[OK%]"))
    end)

    it('completes with fail message', function()
      loader.start("Test")
      written_output = ""

      loader.fail()

      assert.is_not_nil(written_output:match("%[FAIL%]"))
    end)
  end)

  describe('spinner animation', function()
    it('cycles through spinner characters', function()
      loader.start("Test")
      local initial_output = written_output
      written_output = ""

      -- Call next multiple times
      loader.next()
      local first_next = written_output
      written_output = ""

      loader.next()
      local second_next = written_output

      -- Should show different spinner characters
      assert.is_not.equal(first_next, second_next)
    end)

    it('does not animate when not active', function()
      -- Don't start loader
      loader.next()

      -- Should not produce any output
      assert.are.equal("", written_output)
    end)

    it('step is an alias for next', function()
      loader.start("Test")
      written_output = ""

      loader.step()

      assert.is_not.equal("", written_output)
    end)
  end)

  describe('multiple start/stop cycles', function()
    it('handles multiple start/stop cycles', function()
      loader.start("First")
      loader.stop()

      written_output = ""
      loader.start("Second")

      assert.is_not_nil(written_output:match("Second"))
    end)

    it('handles stop when not started', function()
      -- Should not crash or produce unwanted output
      loader.stop()
      assert.are.equal("", written_output)
    end)
  end)

  describe('status helpers', function()
    it('produces warning output', function()
      loader.start("Test")
      written_output = ""

      loader.warning("Disk low")

      assert.is_not_nil(written_output:match("%[WARN%]"))
      assert.is_not_nil(written_output:match("Disk low"))
    end)

    it('produces info output', function()
      loader.start("Test")
      written_output = ""

      loader.info("Step 2")

      assert.is_not_nil(written_output:match("%[INFO%]"))
      assert.is_not_nil(written_output:match("Step 2"))
    end)

    it('clears the line without marker', function()
      loader.start("Test")
      written_output = ""

      loader.clear()

      -- Should clear line (write spaces + carriage return)
      assert.is_true(#written_output > 0)
      assert.is_nil(written_output:match("%[OK%]"))
      assert.is_nil(written_output:match("%[FAIL%]"))
    end)
  end)

  describe('inspection and mutation', function()
    it('reports active state', function()
      assert.is_false(loader.is_active())
      loader.start("Test")
      assert.is_true(loader.is_active())
      loader.stop()
      assert.is_false(loader.is_active())
    end)

    it('updates message while running', function()
      loader.start("Old")
      written_output = ""

      loader.update("New")

      assert.is_not_nil(written_output:match("New"))
    end)

    it('returns a sorted list of styles', function()
      local names = loader.get_styles()
      assert.is_true(#names > 3)
      assert.is_not_nil(names[1])
      -- Verify sorted order
      for i = 2, #names do
        assert.is_true(names[i] > names[i - 1])
      end
    end)

    it('changes style on the fly', function()
      loader.start("Test", "standard")
      written_output = ""

      loader.set_style("dots")
      assert.is_not_nil(written_output:match("Test"))
      -- Dots style uses periods instead of standard spinner chars
      assert.is_not_nil(written_output:match("%."))
    end)

    it('ignores unknown style names', function()
      loader.start("Test")
      loader.set_style("nonexistent")
      -- Should keep current style and not crash
      assert.is_true(loader.is_active())
    end)
  end)

  describe('run wrapper', function()
    it('calls success when fn succeeds', function()
      written_output = ""
      local result = loader.run(function()
        return 42
      end, "Working")

      assert.are.equal(42, result)
      assert.is_not_nil(written_output:match("%[OK%]"))
    end)

    it('calls fail when fn errors', function()
      written_output = ""
      local ok, err = pcall(function()
        loader.run(function()
          error("boom")
        end, "Working")
      end)

      assert.is_false(ok)
      assert.is_not_nil(written_output:match("%[FAIL%]"))
    end)
  end)
end)
