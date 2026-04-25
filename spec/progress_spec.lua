local progress = require('lumos.progress')

local function mock_time()
  local start = os.time()
  local calls = 0
  return function()
    calls = calls + 1
    return start + calls
  end
end

local original_time = os.time

describe('Progress Module', function()
  local original_io_write = io.write
  local output = ""

  before_each(function()
    output = ""
    io.write = function(text)
      output = output .. text
    end
    os.time = mock_time()
  end)

  after_each(function()
    io.write = original_io_write
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

    it('tick is an alias for increment(1)', function()
      local bar = progress.new({total = 10})
      bar:tick()
      assert.are.equal(1, bar.current)
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

    it('reports completion state', function()
      local bar = progress.new({total = 10})
      assert.is_false(bar:is_complete())
      bar:update(10)
      assert.is_true(bar:is_complete())
    end)

    it('returns correct percentage', function()
      local bar = progress.new({total = 10})
      bar:update(3)
      assert.are.equal(30, bar:get_percentage())
    end)

    it('returns elapsed time', function()
      local bar = progress.new({total = 10})
      assert.are.equal(1, bar:get_elapsed())
    end)

    it('returns eta when calculable', function()
      local bar = progress.new({total = 100})
      bar:update(50)
      local eta = bar:get_eta()
      assert.is_number(eta)
      assert.are.equal(2, eta)
    end)

    it('returns nil eta when not calculable', function()
      local bar = progress.new({total = 100})
      local eta = bar:get_eta()
      assert.is_nil(eta)
    end)

    it('returns rate when calculable', function()
      local bar = progress.new({total = 100})
      bar:update(50)
      local rate = bar:get_rate()
      assert.is_number(rate)
      assert.are.equal(25, rate)
    end)

    it('resets to zero', function()
      local bar = progress.new({total = 10})
      bar:update(10)
      bar:reset()
      assert.are.equal(0, bar.current)
      assert.is_false(bar:is_complete())
    end)

    it('changes message on the fly', function()
      local bar = progress.new({total = 10, format = "{message} {percentage}%"})
      bar:set_message("Step 1")
      assert.is_not_nil(output:match("Step 1"))
      output = ""
      bar:set_message("Step 2")
      assert.is_not_nil(output:match("Step 2"))
    end)

    it('changes total on the fly', function()
      local bar = progress.new({total = 10})
      bar:update(5)
      bar:set_total(20)
      assert.are.equal(20, bar.total)
      assert.are.equal(25, bar:get_percentage())
    end)
  end)

  describe('iter wrapper', function()
    it('iterates over a table with auto progress', function()
      local items = {"a", "b", "c"}
      local collected = {}
      for item in progress.iter(items, {format = "{percentage}%"}) do
        table.insert(collected, item)
      end
      assert.are.same({"a", "b", "c"}, collected)
      assert.is_not_nil(output:match("100%%"))
    end)
  end)

  describe('run wrapper', function()
    it('executes function with auto progress', function()
      progress.run(3, function(bar)
        bar:tick()
        bar:tick()
        bar:tick()
      end, {format = "{percentage}%"})
      assert.is_not_nil(output:match("100%%"))
    end)

    it('re-raises errors after finishing bar', function()
      local ok, err = pcall(function()
        progress.run(3, function(bar)
          bar:tick()
          error("boom")
        end)
      end)
      assert.is_false(ok)
      assert.is_not_nil(err:match("boom"))
    end)
  end)

  describe('bytes helper', function()
    it('formats small bytes', function()
      assert.are.equal("512 B", progress.format_bytes(512))
    end)

    it('formats kilobytes', function()
      assert.are.equal("1.50 KB", progress.format_bytes(1536))
    end)

    it('formats megabytes', function()
      assert.are.equal("2.00 MB", progress.format_bytes(2 * 1024 * 1024))
    end)

    it('creates a bytes progress bar', function()
      local bar = progress.bytes(2048, {format = "{bytes_current}/{bytes_total}"})
      bar:update(1024)
      assert.is_not_nil(output:match("1.00 KB"))
      assert.is_not_nil(output:match("2.00 KB"))
    end)
  end)

  describe('Simple progress function', function()
    it('displays simple progress', function()
      progress.simple(1, 4)
      assert.is_not_nil(output:match("25%% %(1/4%)"))
    end)
  end)
end)
