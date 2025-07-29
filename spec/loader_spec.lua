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
    -- Restore original functions
    io.write = original_io_write
    io.flush = original_io_flush
    -- Stop any active loader
    loader.stop()
  end)

  describe('loader lifecycle', function()
    it('starts with default message and style', function()
      loader.start()
      
      assert.is_not_nil(written_output:match("Chargement"))
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
end)
