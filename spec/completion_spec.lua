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

        it("should filter hidden commands and flags", function()
            local app = lumos.new_app({name = "myapp"})
            app:command("visible", "Visible")
            app:command("secret", "Secret"):hidden(true)
            app:persistent_flag("--debug", "Debug"):hidden_flag(true)
            app:persistent_flag("--verbose -v", "Verbose")

            local script = app:generate_completion("bash")
            assert.matches("visible", script)
            assert.is_nil(script:match("secret"))
            assert.is_nil(script:match("%-%-debug"))
            assert.matches("%-%-verbose", script)
        end)

        it("should include global flags", function()
            local app = lumos.new_app({name = "myapp"})
            app:flag("-j --json", "JSON output")
            app:command("build", "Build")

            local script = app:generate_completion("bash")
            assert.matches("%-%-json", script)
            assert.matches("%-j", script)
        end)

        it("should include command-specific flags", function()
            local app = lumos.new_app({name = "myapp"})
            local deploy = app:command("deploy", "Deploy")
            deploy:flag("--env -e", "Environment")

            local script = app:generate_completion("bash")
            assert.matches("deploy", script)
            assert.matches("%-%-env", script)
            assert.matches("%-e", script)
        end)

        it("should include subcommands", function()
            local app = lumos.new_app({name = "myapp"})
            local deploy = app:command("deploy", "Deploy")
            deploy:subcommand("production", "Production deploy")

            local script = app:generate_completion("bash")
            assert.matches("production", script)
        end)

        it("should include enum choices for value completion", function()
            local app = lumos.new_app({name = "myapp"})
            app:persistent_flag_enum("--format -f", "Output format", {"json", "yaml", "table"})

            local script = app:generate_completion("bash")
            assert.matches("json yaml table", script)
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
            assert.is_nil(script:match("%%{%-%%v,%-%-version%%}"))
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

        it("should include command-specific flags in zsh", function()
            local app = lumos.new_app({name = "myapp"})
            local deploy = app:command("deploy", "Deploy")
            deploy:flag("--env -e", "Environment")

            local script = app:generate_completion("zsh")
            assert.matches("%-%-env", script)
            assert.matches("%-e", script)
        end)

        it("should include enum value completions in zsh", function()
            local app = lumos.new_app({name = "myapp"})
            app:persistent_flag_enum("--format -f", "Format", {"json", "yaml"})

            local script = app:generate_completion("zsh")
            assert.matches("json", script)
            assert.matches("yaml", script)
        end)

        it("should filter hidden commands in zsh", function()
            local app = lumos.new_app({name = "myapp"})
            app:command("visible", "Visible")
            app:command("secret", "Secret"):hidden(true)

            local script = app:generate_completion("zsh")
            assert.matches("visible", script)
            assert.is_nil(script:match("secret"))
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

        it("should include command-specific flags in fish", function()
            local app = lumos.new_app({name = "myapp"})
            local deploy = app:command("deploy", "Deploy")
            deploy:flag("--env -e", "Environment")

            local script = app:generate_completion("fish")
            assert.matches("__fish_seen_subcommand_from deploy", script)
            assert.matches("%-l env", script)
            assert.matches("%-s e", script)
        end)

        it("should include enum choices in fish", function()
            local app = lumos.new_app({name = "myapp"})
            app:persistent_flag_enum("--format -f", "Format", {"json", "yaml"})

            local script = app:generate_completion("fish")
            assert.matches("json yaml", script)
        end)
    end)

    describe("PowerShell Completion", function()
        it("should generate powershell completion script", function()
            local app = lumos.new_app({name = "myapp", version = "1.0.0"})
            app:command("deploy", "Deploy")
            app:persistent_flag("--verbose -v", "Verbose")

            local script = app:generate_completion("powershell")
            assert.is_string(script)
            assert.matches("Register%-ArgumentCompleter", script)
            assert.matches("myapp", script)
            assert.matches("deploy", script)
            assert.matches("%-%-verbose", script)
        end)

        it("should include enum values in powershell", function()
            local app = lumos.new_app({name = "myapp"})
            app:persistent_flag_enum("--format -f", "Format", {"json", "yaml"})

            local script = app:generate_completion("powershell")
            assert.matches("json", script)
            assert.matches("yaml", script)
        end)

        it("should include subcommands in powershell", function()
            local app = lumos.new_app({name = "myapp"})
            local deploy = app:command("deploy", "Deploy")
            deploy:subcommand("production", "Production")

            local script = app:generate_completion("powershell")
            assert.matches("production", script)
        end)
    end)
    
    describe("Error Handling", function()
        it("should error on unsupported shell", function()
            local app = lumos.new_app({name = "testapp"})
            
            assert.has_error(function()
                app:generate_completion("unknown")
            end, "Unsupported shell: unknown. Supported: bash, zsh, fish, powershell, all")
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
            
            local result = app:generate_completion("all", "/tmp/test-completions", false)
            assert.is_true(result)
        end)

        it("should return true from generate_all", function()
            local app = lumos.new_app({name = "testapp"})
            local completion = require('lumos.completion')
            local result = completion.generate_all(app, "/tmp/test-completions-2", false)
            assert.is_true(result)
        end)
    end)

    describe("App add_completion_command", function()
        it("should add a completion command to the app", function()
            local app = lumos.new_app({name = "myapp"})
            app:add_completion_command()

            assert.equals(1, #app.commands)
            assert.equals("completion", app.commands[1].name)
        end)

        it("should allow custom name and description", function()
            local app = lumos.new_app({name = "myapp"})
            app:add_completion_command({name = "complete", description = "Generate completions"})

            assert.equals("complete", app.commands[1].name)
            assert.equals("Generate completions", app.commands[1].description)
        end)
    end)

    describe("Flag complete() helper", function()
        it("should store completion choices on the last flag", function()
            local app = lumos.new_app({name = "myapp"})
            app:flag("--env", "Environment"):complete({"dev", "staging", "prod"})

            assert.is_table(app._last_flag.completion_choices)
            assert.equals("dev", app._last_flag.completion_choices[1])
        end)
    end)
end)
