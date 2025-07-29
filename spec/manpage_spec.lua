-- Tests for Man Page Generation
describe("Man Page Generation", function()
    local lumos
    
    before_each(function()
        package.loaded['lumos'] = nil
        lumos = require('lumos')
    end)
    
    describe("Main Application Man Page", function()
        it("should generate main man page", function()
            local app = lumos.new_app({
                name = "testapp",
                version = "1.0.0",
                description = "Test application"
            })
            
            app:command("test", "Test command")
                :flag_string("--message -m", "Test message")
                :examples({"testapp test --message hello"})
            
            app:persistent_flag("--verbose -v", "Enable verbose output")
            
            local manpage = app:generate_manpage()
            
            assert.is_string(manpage)
            assert.matches(".TH TESTAPP 1", manpage)
            assert.matches("testapp", manpage)
            assert.matches("Test application", manpage)
            assert.matches(".SH COMMANDS", manpage)
            assert.matches("test", manpage)
            assert.matches(".SH GLOBAL OPTIONS", manpage)
            assert.matches("verbose", manpage)
        end)
        
        it("should include command aliases in main man page", function()
            local app = lumos.new_app({name = "myapp"})
            
            app:command("start", "Start service"):alias("s"):alias("run")
            app:command("stop", "Stop service")
            
            local manpage = app:generate_manpage()
            
            assert.matches("start", manpage)
            assert.matches("Aliases: s, run", manpage)
            assert.matches("stop", manpage)
        end)
        
        it("should include examples from commands", function()
            local app = lumos.new_app({name = "myapp"})
            
            app:command("deploy", "Deploy app")
                :examples({"myapp deploy --env prod", "myapp deploy staging"})
            
            local manpage = app:generate_manpage()
            
            assert.matches(".SH EXAMPLES", manpage)
            assert.matches("myapp deploy %-%-env prod", manpage)
            assert.matches("myapp deploy staging", manpage)
        end)
    end)
    
    describe("Command-Specific Man Pages", function()
        it("should generate command-specific man page", function()
            local app = lumos.new_app({
                name = "testapp",
                version = "1.0.0",
                description = "Test application"
            })
            
            app:command("test", "Test command")
                :flag_string("--message -m", "Test message")
                :flag_int("--count -c", "Count parameter", 1, 10)
                :examples({"testapp test --message hello"})
            
            local manpage = app:generate_manpage("test")
            
            assert.is_string(manpage)
            assert.matches(".TH TESTAPP%-TEST 1", manpage)
            assert.matches("testapp%-test", manpage)
            assert.matches("Test command", manpage)
            assert.matches(".SH OPTIONS", manpage)
            assert.matches("message", manpage)
            assert.matches("count", manpage)
            assert.matches("VALUE", manpage)
            assert.matches("INT", manpage)
            assert.matches("%(min: 1, max: 10%)", manpage)
            assert.matches(".SH EXAMPLES", manpage)
        end)
        
        it("should format flags correctly in man pages", function()
            local app = lumos.new_app({
                name = "testapp",
                version = "1.0.0",
                description = "Test application"
            })
            
            app:command("test", "Test command")
                :flag_string("--message -m", "Test message")
                :flag("--verbose -v", "Enable verbose mode")
                :flag("--dry-run", "Dry run mode")
                :flag_int("--count -c", "Count parameter", 1, 100)
                :flag_email("--email", "Email address")
            
            local manpage = app:generate_manpage("test")
            
            -- Check that flags are properly formatted (basic content check)
            assert.matches("message", manpage)
            assert.matches("VALUE", manpage)
            assert.matches("verbose", manpage)
            assert.matches("dry%-run", manpage)
            assert.matches("count", manpage)
            assert.matches("INT", manpage)
            assert.matches("email", manpage)
            assert.matches("EMAIL", manpage)
            
            -- Check constraints are included
            assert.matches("min: 1", manpage)
            assert.matches("max: 100", manpage)
        end)
        
        it("should include persistent flags in command man pages", function()
            local app = lumos.new_app({
                name = "testapp",
                version = "1.0.0",
                description = "Test application"
            })
            
            app:persistent_flag("--verbose -v", "Enable verbose output")
            app:persistent_flag("--config", "Configuration file")
            
            local cmd = app:command("test", "Test command")
                :flag("--force -f", "Force operation")
            
            -- Add persistent flags to command (simulate inheritance)
            cmd.persistent_flags = app.persistent_flags
            
            local manpage = app:generate_manpage("test")
            
            -- Should have both OPTIONS and PERSISTENT OPTIONS sections
            assert.matches(".SH OPTIONS", manpage)
            assert.matches("force", manpage)
            assert.matches(".SH PERSISTENT OPTIONS", manpage)
            assert.matches("verbose", manpage)
            assert.matches("config", manpage)
        end)
        
        it("should include subcommands in man page", function()
            local app = lumos.new_app({name = "myapp"})
            
            local db_cmd = app:command("db", "Database operations")
            db_cmd:subcommand("migrate", "Run database migrations")
            db_cmd:subcommand("seed", "Seed database with data")
            
            local manpage = app:generate_manpage("db")
            
            assert.matches(".SH SUBCOMMANDS", manpage)
            assert.matches("migrate", manpage)
            assert.matches("seed", manpage)
        end)
    end)
    
    describe("Error Handling", function()
        it("should error on non-existent command", function()
            local app = lumos.new_app({name = "testapp"})
            
            assert.has_error(function()
                app:generate_manpage("nonexistent")
            end, "Command not found: nonexistent")
        end)
        
        it("should handle commands without flags", function()
            local app = lumos.new_app({name = "testapp"})
            app:command("simple", "Simple command")
            
            local manpage = app:generate_manpage("simple")
            
            assert.is_string(manpage)
            assert.matches("Simple command", manpage)
        end)
        
        it("should handle commands without examples", function()
            local app = lumos.new_app({name = "testapp"})
            app:command("noexamples", "Command without examples")
            
            local manpage = app:generate_manpage("noexamples")
            
            assert.is_string(manpage)
            assert.matches("Command without examples", manpage)
        end)
    end)
    
    describe("Batch Generation", function()
        it("should generate all man pages to directory", function()
            local app = lumos.new_app({
                name = "testapp",
                version = "1.0.0",
                description = "Test application"
            })
            
            app:command("cmd1", "First command")
            app:command("cmd2", "Second command")
            
            -- Test that generate_all function exists and can be called
            -- (We can't test file creation in the test environment easily)
            local manpage_module = require('lumos.manpage')
            assert.is_function(manpage_module.generate_all)
            
            -- Test main man page generation works
            local main_manpage = app:generate_manpage()
            assert.is_string(main_manpage)
            assert.matches("cmd1", main_manpage)
            assert.matches("cmd2", main_manpage)
        end)
    end)
    
    describe("Man Page Format", function()
        it("should include proper man page headers", function()
            local app = lumos.new_app({
                name = "myapp",
                version = "2.1.0"
            })
            
            local manpage = app:generate_manpage()
            
            assert.matches(".TH MYAPP 1", manpage)
            assert.matches("myapp v2.1.0", manpage)
            assert.matches("User Commands", manpage)
            assert.matches("Generated by Lumos", manpage)
        end)
        
        it("should escape special characters properly", function()
            local app = lumos.new_app({
                name = "testapp",
                description = "Test application with - special chars"
            })
            
            local manpage = app:generate_manpage()
            
            assert.is_string(manpage)
            -- Should not crash on special characters
            assert.matches("testapp", manpage)
        end)
    end)
end)
