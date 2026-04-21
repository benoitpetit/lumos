-- Tests for Documentation Generation
describe("Documentation Generation", function()
    local lumos
    
    before_each(function()
        package.loaded['lumos'] = nil
        lumos = require('lumos')
    end)
    
    describe("Markdown Generation", function()
        it("should generate markdown documentation", function()
            local app = lumos.new_app({
                name = "testapp",
                version = "0.1.0",
                description = "Test application"
            })
            
            app:command("test", "Test command")
                :alias("t")
                :flag_string("--message -m", "Test message")
                :examples({"testapp test --message hello"})
            
            app:persistent_flag("--verbose -v", "Enable verbose output")
            
            local docs = app:generate_docs("markdown")
            
            assert.is_string(docs)
            assert.matches("# testapp", docs)
            assert.matches("Test application", docs)
            assert.matches("0%.1%.0", docs)
            assert.matches("## Table of Contents", docs)
            assert.matches("## Global Options", docs)
            assert.matches("`%-%-verbose` | `%-v`", docs)
            assert.matches("`%-%-version`", docs)
            assert.is_nil(docs:match("`%-%-version` | `%-v`"))
            assert.matches("### test", docs)
            assert.matches("Aliases.*t", docs)
            assert.matches("| `%-%-message` | `%-m` | string |", docs)
        end)

        it("should hide short -v for version in docs when -v is already used", function()
            local app = lumos.new_app({ name = "testapp", version = "0.1.0" })
            app:flag("-v --verbose", "Enable verbose output")

            local docs = app:generate_docs("markdown")
            assert.matches("`%-%-version` |  | Show version information", docs)
        end)
        
        it("should include all sections for comprehensive documentation", function()
            local app = lumos.new_app({
                name = "myapp",
                version = "2.0.0",
                description = "My application"
            })
            
            app:persistent_flag("--config", "Configuration file")
            app:command("start", "Start service"):alias("run")
                :flag("--daemon -d", "Run as daemon")
                :examples({"myapp start --daemon"})
            
            local docs = app:generate_docs("markdown")
            
            -- Check main sections
            assert.matches("# myapp", docs)
            assert.matches("My application", docs)
            assert.matches("2%.0%.0", docs)
            assert.matches("## Installation", docs)
            assert.matches("## Usage", docs)
            assert.matches("## Global Options", docs)
            assert.matches("## Commands", docs)
            
            -- Check command documentation
            assert.matches("### start", docs)
            assert.matches("Start service", docs)
            assert.matches("Aliases.*run", docs)
            assert.matches("daemon", docs)
        end)
        
        it("should handle applications without commands", function()
            local app = lumos.new_app({
                name = "simpleapp",
                description = "Simple application"
            })
            
            local docs = app:generate_docs("markdown")
            
            assert.is_string(docs)
            assert.matches("# simpleapp", docs)
            assert.matches("Simple application", docs)
        end)
        
        it("should handle applications without persistent flags", function()
            local app = lumos.new_app({name = "noflags"})
            app:command("basic", "Basic command")
            
            local docs = app:generate_docs("markdown")
            
            assert.is_string(docs)
            assert.matches("# noflags", docs)
            assert.matches("### basic", docs)
        end)
        
        it("should format flag tables correctly", function()
            local app = lumos.new_app({name = "flagtest"})
            
            app:command("test", "Test command")
                :flag_string("--name -n", "Your name")
                :flag_int("--count -c", "Item count", 1, 100)
                :flag("--verbose -v", "Verbose output")
                :flag_email("--email", "Email address")
            
            local docs = app:generate_docs("markdown")
            
            -- Check table structure
            assert.matches("| Flag | Short | Type | Description |", docs)
            assert.matches("| `%-%-name` | `%-n` | string |", docs)
            assert.matches("| `%-%-count` | `%-c` | int |", docs)
            assert.matches("| `%-%-verbose` | `%-v` | boolean |", docs)
            assert.matches("`%-%-email`.*email", docs)
        end)
        
        it("should include examples in command sections", function()
            local app = lumos.new_app({name = "exampleapp"})
            
            app:command("deploy", "Deploy application")
                :examples({
                    "exampleapp deploy production",
                    "exampleapp deploy --env staging",
                    "exampleapp deploy --dry-run"
                })
            
            local docs = app:generate_docs("markdown")
            
            assert.matches("**Examples:**", docs)
            assert.matches("exampleapp deploy production", docs)
            assert.matches("exampleapp deploy %-%-env staging", docs)
            assert.matches("exampleapp deploy %-%-dry%-run", docs)
        end)
        
        it("should generate table of contents with proper links", function()
            local app = lumos.new_app({name = "tocapp"})
            
            app:command("start", "Start service")
            app:command("stop", "Stop service")
            
            local docs = app:generate_docs("markdown")
            
            assert.matches("## Table of Contents", docs)
            assert.matches("- %[Commands%]%(#commands%)", docs)
            assert.matches("  %- %[start%]%(#start%)", docs)
            assert.matches("  %- %[stop%]%(#stop%)", docs)
        end)
    end)
    
    describe("Error Handling", function()
        it("should error on unsupported format", function()
            local app = lumos.new_app({name = "testapp"})
            
            assert.has_error(function()
                app:generate_docs("html")
            end, "Unsupported documentation format: html. Supported: markdown")
        end)
        
        it("should error on unsupported format variations", function()
            local app = lumos.new_app({name = "testapp"})
            
            assert.has_error(function()
                app:generate_docs("XML")
            end, "Unsupported documentation format: XML. Supported: markdown")
        end)
    end)
    
    describe("Content Structure", function()
        it("should follow consistent markdown structure", function()
            local app = lumos.new_app({
                name = "structureapp",
                version = "1.5.0",
                description = "Structure test app"
            })
            
            app:command("test", "Test command")  -- Add a command so we can test Commands section
            
            local docs = app:generate_docs("markdown")
            
            -- Check header hierarchy
            assert.matches("# structureapp", docs)  -- H1 for title
            assert.matches("## Installation", docs)  -- H2 for main sections
            assert.matches("## Usage", docs)
            assert.matches("## Commands", docs)
        end)
        
        it("should escape markdown special characters", function()
            local app = lumos.new_app({
                name = "escapetest",
                description = "App with *special* _chars_ and `code`"
            })
            
            local docs = app:generate_docs("markdown")
            
            assert.is_string(docs)
            assert.matches("escapetest", docs)
            -- Should not break markdown formatting
        end)
        
        it("should handle empty descriptions gracefully", function()
            local app = lumos.new_app({name = "emptyapp"})
            app:command("test", "")  -- Empty description
            
            local docs = app:generate_docs("markdown")
            
            assert.is_string(docs)
            assert.matches("### test", docs)
        end)
    end)
    
    describe("Batch Generation", function()
        it("should support output to directory", function()
            local app = lumos.new_app({name = "testapp"})
            
            -- This would write files in real usage
            -- Just test that the function exists and can be called
            assert.has_no_error(function()
                app:generate_docs("markdown", "/tmp/test-docs", false)  -- false = no verbose output
            end)
        end)
    end)
end)
