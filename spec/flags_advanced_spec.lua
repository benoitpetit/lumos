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
    end)
end)
