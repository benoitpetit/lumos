local config_cache = require('lumos.config_cache')

describe('Config Cache', function()
    it('loads and caches a config file', function()
        local tmp = os.tmpname() .. ".json"
        local f = io.open(tmp, "w")
        f:write('{"key": "value"}')
        f:close()

        local data1, err1 = config_cache.load(tmp)
        assert.is_nil(err1)
        assert.are.equal("value", data1.key)

        -- Second load should return cached data
        local data2, err2 = config_cache.load(tmp)
        assert.is_nil(err2)
        assert.are.equal("value", data2.key)

        os.remove(tmp)
        config_cache.invalidate(tmp)
    end)

    it('returns error for nonexistent file', function()
        local data, err = config_cache.load("/nonexistent/path/config.json")
        assert.is_nil(data)
        assert.is_string(err)
    end)

    it('supports forced reload', function()
        local tmp = os.tmpname() .. ".json"
        local f = io.open(tmp, "w")
        f:write('{"version": 1}')
        f:close()

        local data1 = config_cache.load(tmp)
        assert.are.equal(1, data1.version)

        -- Modify file
        f = io.open(tmp, "w")
        f:write('{"version": 2}')
        f:close()

        -- Without reload, might still return cached version
        -- With reload, should return new version
        local data2 = config_cache.load(tmp, {reload = true})
        assert.are.equal(2, data2.version)

        os.remove(tmp)
        config_cache.invalidate(tmp)
    end)

    it('invalidates cache entries', function()
        local tmp = os.tmpname() .. ".json"
        local f = io.open(tmp, "w")
        f:write('{"test": true}')
        f:close()

        config_cache.load(tmp)
        config_cache.invalidate(tmp)

        -- After invalidate, internal cache entry should be gone
        -- (We can't directly verify, but no error should occur on re-load)
        local data, err = config_cache.load(tmp)
        assert.is_nil(err)
        assert.is_true(data.test)

        os.remove(tmp)
        config_cache.invalidate(tmp)
    end)
end)
