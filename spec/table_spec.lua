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
end)
