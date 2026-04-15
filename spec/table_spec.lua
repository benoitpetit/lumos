local tbl = require('lumos.table')

describe('Table Module', function()
  describe('boxed function', function()
    it('creates a simple boxed table', function()
      local items = {"Item1", "Item2"}
      local result = tbl.boxed(items)
      
      assert.is_not_nil(result:match("┌"))
      assert.is_not_nil(result:match("└"))
      assert.is_not_nil(result:match("│ Item1 │"))
      assert.is_not_nil(result:match("│ Item2 │"))
    end)

    it('handles empty items list', function()
      local items = {}
      local result = tbl.boxed(items)
      
      assert.is_not_nil(result:match("┌"))
      assert.is_not_nil(result:match("└"))
    end)

    it('handles single item', function()
      local items = {"SingleItem"}
      local result = tbl.boxed(items)
      
      assert.is_not_nil(result:match("│ SingleItem │"))
    end)

    it('calculates width based on longest item', function()
      local items = {"Short", "Very Long Item Name"}
      local result = tbl.boxed(items)
      
      -- Both items should have same padding
      assert.is_not_nil(result:match("│ Short"))
      assert.is_not_nil(result:match("│ Very Long Item Name │"))
    end)

    it('supports header option', function()
      local items = {"Item1", "Item2"}
      local result = tbl.boxed(items, {header = "Header"})
      
      assert.is_not_nil(result:match("│ Header │"))
      assert.is_not_nil(result:match("├"))  -- separator line
    end)

    it('supports footer option', function()
      local items = {"Item1", "Item2"}
      local result = tbl.boxed(items, {footer = "Footer"})
      
      assert.is_not_nil(result:match("│ Footer │"))
      assert.is_not_nil(result:match("├"))  -- separator line
    end)

    it('supports center alignment', function()
      local items = {"X"}  -- Single character to test centering
      local result = tbl.boxed(items, {align = "center"})
      
      -- Should have equal padding on both sides
      assert.is_not_nil(result:match("│ X │"))
    end)

    it('supports right alignment', function()
      local items = {"Test"}
      local result = tbl.boxed(items, {align = "right"})
      
      -- Should be right-aligned
      assert.is_not_nil(result:match("│ Test │"))
    end)

    it('converts non-string items to strings', function()
      local items = {42, true, false}
      local result = tbl.boxed(items)
      
      assert.is_not_nil(result:match("│ 42"))
      assert.is_not_nil(result:match("│ true"))
      assert.is_not_nil(result:match("│ false"))
    end)

    it('converts table items to string representation', function()
      local items = {{name = "test", value = 42}}
      local result = tbl.boxed(items)
      
      -- Should contain some representation of the table
      assert.is_true(result:match("name:") ~= nil or result:match("value:") ~= nil)
    end)
  end)

  describe('paginate function', function()
    it('splits rows into pages of given size', function()
      local rows = {1, 2, 3, 4, 5}
      local pages = tbl.paginate(rows, 2)
      assert.are.equal(3, #pages)
      assert.are.same({1, 2}, pages[1])
      assert.are.same({3, 4}, pages[2])
      assert.are.same({5}, pages[3])
    end)

    it('defaults to page size of 10', function()
      local rows = {}
      for i = 1, 12 do table.insert(rows, i) end
      local pages = tbl.paginate(rows)
      assert.are.equal(2, #pages)
      assert.are.equal(10, #pages[1])
      assert.are.equal(2, #pages[2])
    end)

    it('returns empty table for empty input', function()
      local pages = tbl.paginate({}, 5)
      assert.are.equal(0, #pages)
    end)
  end)

  describe('page function', function()
    it('returns correct page metadata', function()
      local rows = {1, 2, 3, 4, 5, 6, 7}
      local result = tbl.page(rows, 2, 3)
      assert.are.same({4, 5, 6}, result.data)
      assert.are.equal(2, result.page)
      assert.are.equal(3, result.total_pages)
      assert.are.equal(7, result.total_rows)
      assert.is_true(result.has_next)
      assert.is_true(result.has_prev)
    end)

    it('clamps page number to valid range', function()
      local rows = {1, 2}
      local result = tbl.page(rows, 99, 5)
      assert.are.equal(1, result.page)
      assert.are.same({1, 2}, result.data)
      assert.is_false(result.has_next)
    end)

    it('returns empty data for empty input', function()
      local result = tbl.page({}, 1, 5)
      assert.are.same({}, result.data)
      assert.are.equal(1, result.total_pages)
      assert.are.equal(0, result.total_rows)
    end)
  end)
end)
