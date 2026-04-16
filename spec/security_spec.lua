-- Security Module Tests
local security = require('lumos.security')

describe('Security Module', function()
    describe('shell_escape', function()
        it('should escape single quotes', function()
            local result = security.shell_escape("hello'world")
            assert.are.equal("'hello'\\''world'", result)
        end)
        
        it('should wrap simple strings in quotes', function()
            local result = security.shell_escape("hello")
            assert.are.equal("'hello'", result)
        end)
        
        it('should handle empty strings', function()
            local result = security.shell_escape("")
            assert.are.equal("''", result)
        end)
        
        it('should handle nil values', function()
            local result = security.shell_escape(nil)
            assert.are.equal("''", result)
        end)
        
        it('should prevent command injection', function()
            local result = security.shell_escape("test; rm -rf /")
            -- Le résultat doit être entre quotes
            assert.is_true(result:match("^'.*'$") ~= nil)
            -- Vérifier que c'est bien échappé
            assert.are.equal("'test; rm -rf /'", result)
        end)
    end)
    
    describe('sanitize_path', function()
        it('should accept valid paths', function()
            local result, err = security.sanitize_path("/home/user/file.txt")
            assert.is_not_nil(result)
            assert.is_nil(err)
        end)
        
        it('should reject path traversal attempts', function()
            local result, err = security.sanitize_path("../../../etc/passwd")
            assert.is_nil(result)
            assert.are.equal("Path traversal detected", err)
        end)
        
        it('should remove dangerous characters', function()
            local result, err = security.sanitize_path("/home/user/file;rm -rf.txt")
            assert.is_not_nil(result)
            assert.is_false(result:match(";") ~= nil)
        end)
        
        it('should reject empty paths', function()
            local result, err = security.sanitize_path("")
            assert.is_nil(result)
            assert.are.equal("Empty path", err)
        end)
        
        it('should normalize multiple slashes', function()
            local result, err = security.sanitize_path("/home///user//file.txt")
            assert.are.equal("/home/user/file.txt", result)
        end)
        
        it('should remove trailing slash except for root', function()
            local result1, _ = security.sanitize_path("/home/user/")
            assert.are.equal("/home/user", result1)
            
            local result2, _ = security.sanitize_path("/")
            assert.are.equal("/", result2)
        end)
    end)
    
    describe('validate_email', function()
        it('should accept valid emails', function()
            local valid, err = security.validate_email("test@example.com")
            assert.is_true(valid)
            assert.is_nil(err)
        end)
        
        it('should accept emails with dots', function()
            local valid, err = security.validate_email("first.last@example.com")
            assert.is_true(valid)
        end)
        
        it('should accept emails with plus', function()
            local valid, err = security.validate_email("user+tag@example.com")
            assert.is_true(valid)
        end)
        
        it('should reject emails without @', function()
            local valid, err = security.validate_email("notanemail.com")
            assert.is_false(valid)
            assert.are.equal("Invalid email format", err)
        end)
        
        it('should reject emails with multiple @', function()
            local valid, err = security.validate_email("test@@example.com")
            assert.is_false(valid)
        end)
        
        it('should reject emails without domain', function()
            local valid, err = security.validate_email("test@")
            assert.is_false(valid)
        end)
        
        it('should reject too long emails', function()
            local long_email = string.rep("a", 250) .. "@example.com"
            local valid, err = security.validate_email(long_email)
            assert.is_false(valid)
            assert.are.equal("Email too long", err)
        end)
        
        it('should reject too long local part', function()
            local long_local = string.rep("a", 70) .. "@example.com"
            local valid, err = security.validate_email(long_local)
            assert.is_false(valid)
            assert.are.equal("Email local part too long", err)
        end)
    end)
    
    describe('validate_url', function()
        it('should accept valid HTTP URLs', function()
            local valid, err = security.validate_url("http://example.com")
            assert.is_true(valid)
        end)
        
        it('should accept valid HTTPS URLs', function()
            local valid, err = security.validate_url("https://example.com/path")
            assert.is_true(valid)
        end)
        
        it('should reject FTP URLs', function()
            local valid, err = security.validate_url("ftp://example.com")
            assert.is_false(valid)
        end)
        
        it('should reject URLs with @', function()
            local valid, err = security.validate_url("http://user@example.com")
            assert.is_false(valid)
            -- Le message peut varier mais doit indiquer le rejet
            assert.is_not_nil(err)
        end)
        
        it('should reject URLs without protocol', function()
            local valid, err = security.validate_url("example.com")
            assert.is_false(valid)
        end)
    end)
    
    describe('validate_integer', function()
        it('should accept valid integers', function()
            local valid, num = security.validate_integer(42)
            assert.is_true(valid)
            assert.are.equal(42, num)
        end)
        
        it('should accept string integers', function()
            local valid, num = security.validate_integer("123")
            assert.is_true(valid)
            assert.are.equal(123, num)
        end)
        
        it('should reject floats', function()
            local valid, err = security.validate_integer(3.14)
            assert.is_false(valid)
            assert.are.equal("Must be an integer", err)
        end)
        
        it('should enforce minimum', function()
            local valid, err = security.validate_integer(5, 10, 20)
            assert.is_false(valid)
            assert.are.equal("Must be >= 10", err)
        end)
        
        it('should enforce maximum', function()
            local valid, err = security.validate_integer(25, 10, 20)
            assert.is_false(valid)
            assert.are.equal("Must be <= 20", err)
        end)
        
        it('should accept values in range', function()
            local valid, num = security.validate_integer(15, 10, 20)
            assert.is_true(valid)
            assert.are.equal(15, num)
        end)
    end)
    
    describe('sanitize_command_name', function()
        it('should accept valid command names', function()
            local result, err = security.sanitize_command_name("my-command")
            assert.are.equal("my-command", result)
            assert.is_nil(err)
        end)
        
        it('should accept underscores', function()
            local result, err = security.sanitize_command_name("my_command")
            assert.are.equal("my_command", result)
        end)
        
        it('should reject special characters', function()
            local result, err = security.sanitize_command_name("my;command")
            assert.is_nil(result)
            assert.is_not_nil(err)
        end)
        
        it('should reject spaces', function()
            local result, err = security.sanitize_command_name("my command")
            assert.is_nil(result)
        end)
        
        it('should reject too long names', function()
            local long_name = string.rep("a", 70)
            local result, err = security.sanitize_command_name(long_name)
            assert.is_nil(result)
            assert.are.equal("Command name too long", err)
        end)
    end)
    
    describe('sanitize_output', function()
        it('should remove control characters', function()
            local text = "Hello" .. string.char(1) .. string.char(2) .. "World"
            local result = security.sanitize_output(text)
            assert.are.equal("HelloWorld", result)
        end)
        
        it('should preserve newlines', function()
            local text = "Line1\nLine2"
            local result = security.sanitize_output(text)
            assert.are.equal("Line1\nLine2", result)
        end)
        
        it('should preserve tabs', function()
            local text = "Col1\tCol2"
            local result = security.sanitize_output(text)
            assert.are.equal("Col1\tCol2", result)
        end)
        
        it('should handle nil', function()
            local result = security.sanitize_output(nil)
            assert.are.equal("", result)
        end)
    end)
    
    describe('rate_limit', function()
        it('should allow calls within limit', function()
            local key = "test_op_" .. os.time()
            local allowed, err = security.rate_limit(key, 5, 60)
            assert.is_true(allowed)
            assert.is_nil(err)
        end)
        
        it('should block calls exceeding limit', function()
            local key = "test_limit_" .. os.time()
            
            -- Make max calls
            for i = 1, 10 do
                security.rate_limit(key, 10, 60)
            end
            
            -- Next call should be blocked
            local allowed, err = security.rate_limit(key, 10, 60)
            assert.is_false(allowed)
            assert.are.equal("Rate limit exceeded", err)
        end)
    end)

    describe('safe_open', function()
        it('should open a valid file for reading', function()
            local tmp = os.tmpname()
            local f = io.open(tmp, "w")
            f:write("hello")
            f:close()
            
            local sf, err = security.safe_open(tmp, "r")
            assert.is_not_nil(sf)
            assert.is_nil(err)
            sf:close()
            os.remove(tmp)
        end)

        it('should reject writing to system directories', function()
            local sf, err = security.safe_open("/etc/test_lumos.txt", "w")
            assert.is_nil(sf)
            assert.are.equal("Cannot write to system directory", err)
        end)
    end)

    describe('safe_mkdir', function()
        it('should create nested directories', function()
            local base = os.tmpname()
            os.remove(base)
            local path = base .. "/a/b/c"
            
            local ok, err = security.safe_mkdir(path)
            assert.is_true(ok)
            assert.is_nil(err)
            
            -- Cleanup
            os.remove(path)
            os.remove(base .. "/a/b")
            os.remove(base .. "/a")
            os.remove(base)
        end)
    end)

    describe('is_elevated', function()
        it('should return a boolean', function()
            local result = security.is_elevated()
            assert.is_boolean(result)
        end)
    end)

    describe('sanitize_path regression', function()
        it('should accept legitimate paths containing double dots', function()
            local result, err = security.sanitize_path("foo..bar.txt")
            assert.is_not_nil(result)
            assert.is_nil(err)
            assert.are.equal("foo..bar.txt", result)
        end)
    end)
end)
