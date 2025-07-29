local core = require('lumos.core')
local app = require('lumos.app')

describe('Advanced Core Module', function()
    describe('Command aliases', function()
        it('finds commands by alias', function()
            local test_app = app.new_app()
            local cmd = test_app:command('create', 'Create something')
            cmd:alias('c'):alias('new')
            
            local found_by_name = core.find_command(test_app, 'create')
            local found_by_alias1 = core.find_command(test_app, 'c')
            local found_by_alias2 = core.find_command(test_app, 'new')
            
            assert.are.equal(cmd, found_by_name)
            assert.are.equal(cmd, found_by_alias1)
            assert.are.equal(cmd, found_by_alias2)
        end)
        
        it('returns nil for unknown command or alias', function()
            local test_app = app.new_app()
            test_app:command('test', 'Test command')
            
            local not_found = core.find_command(test_app, 'unknown')
            assert.is_nil(not_found)
        end)
    end)
    
    describe('Flag validation and merging', function()
        it('validates and merges flags correctly', function()
            local test_app = app.new_app()
            test_app.persistent_flags = {
                verbose = {type = "boolean", persistent = true}
            }
            
            local cmd = test_app:command('test', 'Test command')
            cmd.flags = {
                count = {type = "int", min = 1, max = 10}
            }
            
            local parsed_flags = {
                verbose = true,
                count = "5"
            }
            
            local merged, errors = core.validate_and_merge_flags(test_app, cmd, parsed_flags)
            
            assert.are.equal(0, #errors)
            assert.is_true(merged.verbose)
            assert.are.equal(5, merged.count)
        end)
        
        it('reports validation errors', function()
            local test_app = app.new_app()
            local cmd = test_app:command('test', 'Test command')
            cmd.flags = {
                count = {type = "int", min = 1, max = 10}
            }
            
            local parsed_flags = {
                count = "15"  -- exceeds max
            }
            
            local merged, errors = core.validate_and_merge_flags(test_app, cmd, parsed_flags)
            
            assert.are.equal(1, #errors)
            assert.matches("must be <= 10", errors[1])
        end)
    end)
end)
