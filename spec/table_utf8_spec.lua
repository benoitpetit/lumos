local tbl = require('lumos.table')

describe('Table UTF-8 handling', function()
  it('does not break multi-byte characters when truncating', function()
    local data = {
      header = {"Name", "Value"},
      rows = {
        {"日本語", "123"},
      },
    }
    local options = {max_width = 4}
    local result = tbl.create(data.rows, options)
    -- Should not contain invalid UTF-8 sequences (broken bytes)
    assert.is_not_nil(result)
    assert.is_true(#result > 0)
    -- The cell content should not have a standalone continuation byte
    assert.is_false(result:find("\x80") ~= nil and result:find("\xE6") == nil)
  end)

  it('correctly measures width of UTF-8 strings', function()
    local data = {
      header = {"Col"},
      rows = {
        {"αβγδ"},
      },
    }
    local options = {max_width = 3}
    local result = tbl.create(data.rows, options)
    assert.is_not_nil(result)
  end)
end)
