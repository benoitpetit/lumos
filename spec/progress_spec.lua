local progress = require('lumos.progress')

local function mock_time()
  local start = os.time()
  return function()
    return start + 1  -- Increment time by 1 second each call
  end
end

local original_time = os.time



describe('Progress Module', function()
  local original_io_write = io.write
  local output = ""

  before_each(function()
    output = ""
    -- Mock io.write
    io.write = function(text)
      output = output .. text
    end
    -- Mock time
    os.time = mock_time()
  end)

  after_each(function()
    -- Restore original io.write
    io.write = original_io_write
    -- Restore original os.time
    os.time = original_time
  end)

  describe('ProgressBar functionality', function()
    it('initializes with default values', function()
      local bar = progress.new()
      assert.are.equal(0, bar.current)
      assert.are.equal(100, bar.total)
    end)

    it('updates correctly', function()
      local bar = progress.new({total = 10})
      bar:update(5)
      
      assert.are.equal(5, bar.current)
    end)

    it('increments correctly', function()
      local bar = progress.new({total = 10})
      bar:increment(2)
      
      assert.are.equal(2, bar.current)
      bar:increment(2)
      assert.are.equal(4, bar.current)
    end)

    it('renders correctly with updates', function()
      local bar = progress.new({total = 10, format = "{percentage}%"})
      bar:update(5)
      
      assert.is_not_nil(output:match("50%%"))
    end)

    it('renders correctly with increments', function()
      local bar = progress.new({total = 10, format = "{percentage}%"})
      bar:increment(2)
      
      assert.is_not_nil(output:match("20%%"))
    end)

    it('finishes and prints newline', function()
      local bar = progress.new({total = 10})
      bar:finish()
      
      assert.is_not_nil(output:match("100%%"))
      assert.is_not_nil(output:match("\n"))
    end)
  end)

  describe('Simple progress function', function()
    it('displays simple progress', function()
      progress.simple(1, 4)
      assert.is_not_nil(output:match("25%% %(1/4%)"))
    end)
  end)
end)
