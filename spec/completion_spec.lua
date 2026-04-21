-- Tests for Shell Completion Generation
describe("Shell Completion Generation", function()
    local lumos
    
    before_each(function()
        package.loaded['lumos'] = nil
        lumos = require('lumos')
    end)
    
    describe("Bash Completion", function()
        it("should generate bash completion script", function()
            local app = lumos.new_app({
                name = "testapp",
                version = "0.1.0",
                description = "Test application"
            })
            
            app:command("test", "Test command"):alias("t")
            app:persistent_flag("--verbose -v", "Enable verbose output")
            
            local completion = app:generate_completion("bash")
            
            assert.is_string(completion)
            assert.matches("testapp", completion)
            assert.matches("_testapp_completions", completion)
            assert.matches("test t", completion) -- Commands with aliases
            assert.matches("%-%-verbose %-v", completion) -- Flags
            assert.matches("%-%-version", completion)
            assert.is_nil(completion:match("%-%-version %-v"))
        end)

        it("should omit short version flag when -v is already used", function()
            local app = lumos.new_app({name = "testapp"})
            app:flag("-v --verbose", "Verbose")

            local script = app:generate_completion("bash")
            assert.matches("%-%-version", script)
            assert.is_nil(script:match("%-%-version %-v"))
        end)
        
        it("should include all commands and aliases in bash completion", function()
            local app = lumos.new_app({name = "myapp"})
            
            app:command("start", "Start service"):alias("s")
            app:command("stop", "Stop service"):alias("halt")
            app:command("restart", "Restart service")
            
            local completion = app:generate_completion("bash")
            
            assert.matches("start s stop halt restart", completion)
        end)
    end)
    
    describe("Zsh Completion", function()
        it("should generate zsh completion script", function()
            local app = lumos.new_app({
                name = "testapp",
                version = "0.1.0",
                description = "Test application"
            })
            
            app:command("test", "Test command"):alias("t")
            
            local completion = app:generate_completion("zsh")
            
            assert.is_string(completion)
            assert.matches("#compdef testapp", completion)
            assert.matches("_testapp", completion)
            assert.matches("'test:Test command'", completion)
            assert.matches("'t:Test command'", completion) -- Alias
        end)

        it("should omit -v in zsh version option when already claimed", function()
            local app = lumos.new_app({name = "testapp"})
            app:flag("-v --verbose", "Verbose")

            local script = app:generate_completion("zsh")
            assert.matches("%-%-version", script)
            assert.is_nil(script:match("%{%-%v,%-%-version%}"))
        end)
        
        it("should format commands correctly for zsh", function()
            local app = lumos.new_app({name = "myapp"})
            
            app:command("deploy", "Deploy application")
            app:command("build", "Build project"):alias("b")
            
            local completion = app:generate_completion("zsh")
            
            assert.matches("'deploy:Deploy application'", completion)
            assert.matches("'build:Build project'", completion)
            assert.matches("'b:Build project'", completion)
        end)
    end)
    
    describe("Fish Completion", function()
        it("should generate fish completion script", function()
            local app = lumos.new_app({
                name = "testapp",
                version = "0.1.0",
                description = "Test application"
            })
            
            app:command("test", "Test command"):alias("t")
            
            local completion = app:generate_completion("fish")
            
            assert.is_string(completion)
            assert.matches("# Fish completion for testapp", completion)
            assert.matches("__testapp_complete_commands", completion)
            assert.matches("echo 'test\\tTest command'", completion)
            assert.matches("echo 't\\tTest command'", completion) -- Alias
        end)

        it("should omit -v in fish version completion when already claimed", function()
            local app = lumos.new_app({name = "testapp"})
            app:flag("-v --verbose", "Verbose")

            local script = app:generate_completion("fish")
            assert.matches("%-l version", script)
            assert.is_nil(script:match("%-l version %-s v"))
        end)
        
        it("should handle special characters in descriptions", function()
            local app = lumos.new_app({name = "myapp"})
            
            app:command("test", "Test with 'quotes' and special chars")
            
            local completion = app:generate_completion("fish")
            
            assert.is_string(completion)
            assert.matches("test", completion)
        end)
    end)
    
    describe("Error Handling", function()
        it("should error on unsupported shell", function()
            local app = lumos.new_app({name = "testapp"})
            
            assert.has_error(function()
                app:generate_completion("powershell")
            end, "Unsupported shell: powershell. Supported: bash, zsh, fish, all")
        end)
        
        it("should handle empty application", function()
            local app = lumos.new_app({name = "emptyapp"})
            
            local completion = app:generate_completion("bash")
            
            assert.is_string(completion)
            assert.matches("emptyapp", completion)
        end)
    end)
    
    describe("All Shells Generation", function()
        it("should support 'all' option for multiple shells", function()
            local app = lumos.new_app({name = "testapp"})
            app:command("test", "Test command")
            
            -- This would generate files in real usage, but we can't test file creation easily
            -- Just verify the function doesn't error
            assert.has_no_error(function()
                app:generate_completion("all", "/tmp/test-completions", false)  -- false = no verbose output
            end)
        end)
    end)
end)
