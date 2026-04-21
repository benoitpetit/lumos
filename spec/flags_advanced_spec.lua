local flags = require('lumos.flags')

describe('Advanced Flags Module', function()
    describe('Flag validation', function()
        it('validates integer flags correctly', function()
            local flag_def = {type = "int", min = 1, max = 100}
            
            local valid, result = flags.validate_flag(flag_def, "50")
            assert.is_true(valid)
            assert.are.equal(50, result)
            
            local invalid, error_msg = flags.validate_flag(flag_def, "abc")
            assert.is_false(invalid)
            assert.are.equal("must be an integer", error_msg)
        end)
        
        it('validates number ranges', function()
            local flag_def = {type = "int", min = 10, max = 20}
            
            local valid, result = flags.validate_flag(flag_def, "15")
            assert.is_true(valid)
            assert.are.equal(15, result)
            
            local invalid_low, error_low = flags.validate_flag(flag_def, "5")
            assert.is_false(invalid_low)
            assert.are.equal("must be >= 10", error_low)
            
            local invalid_high, error_high = flags.validate_flag(flag_def, "25")
            assert.is_false(invalid_high)
            assert.are.equal("must be <= 20", error_high)
        end)
        
        it('validates email format', function()
            local flag_def = {type = "email"}
            
            local valid, result = flags.validate_flag(flag_def, "test@example.com")
            assert.is_true(valid)
            assert.are.equal("test@example.com", result)
            
            local invalid, error_msg = flags.validate_flag(flag_def, "invalid-email")
            assert.is_false(invalid)
            assert.are.equal("must be a valid email", error_msg)
        end)
        
        it('validates URL format', function()
            local flag_def = {type = "url"}
            
            local valid, result = flags.validate_flag(flag_def, "https://example.com")
            assert.is_true(valid)
            assert.are.equal("https://example.com", result)
            
            local invalid, error_msg = flags.validate_flag(flag_def, "not-a-url")
            assert.is_false(invalid)
            assert.are.equal("must be a valid URL", error_msg)
        end)
        
        it('validates required flags', function()
            local flag_def = {required = true}
            
            local invalid_nil, error_nil = flags.validate_flag(flag_def, nil)
            assert.is_false(invalid_nil)
            assert.are.equal("is required", error_nil)
            
            local invalid_empty, error_empty = flags.validate_flag(flag_def, "")
            assert.is_false(invalid_empty)
            assert.are.equal("is required", error_empty)
            
            local valid, result = flags.validate_flag(flag_def, "value")
            assert.is_true(valid)
            assert.are.equal("value", result)
        end)

        it('validates float flags with precision', function()
            local flag_def = {type = "float", min = 0, max = 1, precision = 2}
            local valid, result = flags.validate_flag(flag_def, "0.7555")
            assert.is_true(valid)
            assert.are.equal(0.76, result)

            local invalid, err = flags.validate_flag(flag_def, "abc")
            assert.is_false(invalid)
            assert.are.equal("must be a number", err)

            local too_low, err_low = flags.validate_flag(flag_def, "-0.5")
            assert.is_false(too_low)
            assert.are.equal("must be >= 0", err_low)
        end)

        it('validates array flags', function()
            local flag_def = {type = "array", separator = ",", item_type = "int", min_items = 2, max_items = 4, unique = true}
            local valid, result = flags.validate_flag(flag_def, "1,2,3")
            assert.is_true(valid)
            assert.same({1, 2, 3}, result)

            local too_few, err = flags.validate_flag(flag_def, "1")
            assert.is_false(too_few)
            assert.truthy(err:find("at least"))

            local dup, err_dup = flags.validate_flag(flag_def, "1,1,2")
            assert.is_false(dup)
            assert.truthy(err_dup:find("duplicate"))
        end)

        it('validates enum flags', function()
            local flag_def = {type = "enum", choices = {"debug", "info", "warn"}}
            local valid, result = flags.validate_flag(flag_def, "INFO")
            assert.is_true(valid)
            assert.are.equal("info", result)

            local invalid, err = flags.validate_flag(flag_def, "fatal")
            assert.is_false(invalid)
            assert.truthy(err:find("must be one of"))
        end)

        it('validates string flags with pattern and length', function()
            local flag_def = {type = "string", pattern = "^[a-z]+$", min_length = 2, max_length = 5}
            local valid, result = flags.validate_flag(flag_def, "abc")
            assert.is_true(valid)
            assert.are.equal("abc", result)

            local invalid_pat, err = flags.validate_flag(flag_def, "ABC")
            assert.is_false(invalid_pat)
            assert.truthy(err:find("format"))

            local too_long, err_long = flags.validate_flag(flag_def, "abcdef")
            assert.is_false(too_long)
            assert.truthy(err_long:find("at most"))
        end)

        it('validates enriched URL flags', function()
            local flag_def = {type = "url", schemes = {"https"}, require_path = true, allow_localhost = false}
            local valid, result = flags.validate_flag(flag_def, "https://example.com/path")
            assert.is_true(valid)

            local bad_scheme, err = flags.validate_flag(flag_def, "http://example.com/path")
            assert.is_false(bad_scheme)
            assert.truthy(err:find("scheme"))

            local no_path, err2 = flags.validate_flag(flag_def, "https://example.com")
            assert.is_false(no_path)
            assert.truthy(err2:find("path"))

            local localh, err3 = flags.validate_flag(flag_def, "https://localhost/path")
            assert.is_false(localh)
            assert.truthy(err3:find("localhost"))
        end)

        it('validates enriched path flags', function()
            local flag_def = {type = "path", must_exist = false, absolute = false}
            local valid, result = flags.validate_flag(flag_def, "./foo/bar.lua")
            assert.is_true(valid)
            assert.truthy(result:find("foo"))
        end)

        it('accepts path extensions with leading dot', function()
            local tmp = os.tmpname() .. ".lua"
            local f = io.open(tmp, "w")
            assert.is_not_nil(f)
            if f then
                f:write("print('ok')\n")
                f:close()
            end

            local flag_def = {type = "path", must_exist = true, extensions = {".lua"}}
            local valid, result = flags.validate_flag(flag_def, tmp)
            assert.is_true(valid)
            assert.are.equal(tmp, result)

            os.remove(tmp)
        end)
    end)
end)
