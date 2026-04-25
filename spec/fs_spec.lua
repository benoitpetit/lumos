local fs = require('lumos.fs')

describe('FS Module', function()
  describe('without lfs fallback', function()
    it('path_exists returns true for existing file', function()
      local exists = fs.path_exists("spec/fs_spec.lua")
      assert.is_true(exists)
    end)

    it('path_exists returns false for missing file', function()
      local exists = fs.path_exists("/tmp/nonexistent_lumos_test_12345")
      assert.is_false(exists)
    end)

    it('is_file returns true for files', function()
      assert.is_true(fs.is_file("spec/fs_spec.lua"))
    end)

    it('is_file returns false for directories', function()
      assert.is_false(fs.is_file("spec"))
    end)

    it('is_dir returns true for directories', function()
      assert.is_true(fs.is_dir("spec"))
    end)

    it('is_dir returns false for files', function()
      assert.is_false(fs.is_dir("spec/fs_spec.lua"))
    end)

    it('read_file returns content', function()
      local content = fs.read_file("spec/fs_spec.lua")
      assert.is_not_nil(content)
      assert.is_true(#content > 0)
    end)

    it('write_file writes and reads back', function()
      local test_path = os.tmpname()
      local ok = fs.write_file(test_path, "hello lumos")
      assert.is_true(ok)
      local content = fs.read_file(test_path)
      assert.are.equal("hello lumos", content)
      os.remove(test_path)
    end)

    it('mkdir_p creates nested dirs', function()
      local base = os.tmpname() .. "_dir"
      local nested = base .. "/a/b/c"
      local ok = fs.mkdir_p(nested)
      assert.is_true(ok)
      assert.is_true(fs.is_dir(nested))
      fs.rmdir_p(base)
    end)

    it('rmdir_p removes recursively', function()
      local base = os.tmpname() .. "_dir"
      fs.mkdir_p(base .. "/sub")
      fs.write_file(base .. "/sub/file.txt", "x")
      local ok = fs.rmdir_p(base)
      assert.is_true(ok)
      assert.is_false(fs.path_exists(base))
    end)
  end)
end)
