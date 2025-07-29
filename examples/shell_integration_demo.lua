#!/usr/bin/env lua

-- Lumos Shell Integration Demo
-- Demonstrates auto-completion, man page generation, and documentation generation
package.path = package.path .. ";../?.lua;../?/init.lua;"
local lumos = require('lumos')

-- Create a sample application with rich commands
local app = lumos.new_app({
    name = "gitlike",
    version = "1.0.0",
    description = "A Git-like CLI tool demonstrating Lumos shell integration features"
})

-- Add persistent flags (inherited by all commands)
app:persistent_flag("--verbose -v", "Enable verbose output")
app:persistent_flag("--config", "Path to configuration file")

-- Add a "commit" command with comprehensive options
app:command("commit", "Create a new commit")
    :alias("ci")
    :flag_string("--message -m", "Commit message")
    :flag_string("--author", "Override commit author")
    :flag("--all -a", "Stage all modified files")
    :flag("--dry-run", "Show what would be committed")
    :flag_email("--email", "Author email address")
    :examples({
        "gitlike commit -m 'Initial commit'",
        "gitlike commit --all --message 'Update all files'",
        "gitlike ci -a -m 'Quick commit'"
    })
    :action(function(ctx)
        print("Committing with message: " .. (ctx.flags.message or "No message"))
        if ctx.flags.all then
            print("Staging all modified files...")
        end
        if ctx.flags["dry-run"] then
            print("DRY RUN: Would create commit")
            return true
        end
        print("Commit created successfully!")
        return true
    end)

-- Add a "push" command with subcommands
local push_cmd = app:command("push", "Push commits to remote repository")
    :alias("p")
    :flag_string("--remote -r", "Remote name (default: origin)")
    :flag("--force -f", "Force push")
    :flag_int("--jobs -j", "Number of parallel jobs", 1, 10)
    :examples({
        "gitlike push origin main",
        "gitlike push --force",
        "gitlike p -r upstream main"
    })

-- Add subcommand to push
push_cmd:subcommand("origin", "Push to origin remote")
    :action(function(ctx)
        print("Pushing to origin...")
        return true
    end)

push_cmd:action(function(ctx)
    local remote = ctx.flags.remote or "origin"
    print("Pushing to remote: " .. remote)
    if ctx.flags.force then
        print("WARNING: Force pushing!")
    end
    return true
end)

-- Add a "status" command
app:command("status", "Show working tree status")
    :alias("st")
    :alias("stat")
    :flag("--short -s", "Show short format")
    :flag("--porcelain", "Machine-readable output")
    :examples({
        "gitlike status",
        "gitlike st -s",
        "gitlike status --porcelain"
    })
    :action(function(ctx)
        print("On branch main")
        print("Your branch is up to date with 'origin/main'.")
        if ctx.flags.short then
            print("M  examples/phase3_demo.lua")
        else
            print("modified:   examples/phase3_demo.lua")
        end
        return true
    end)

-- Add a "completion" command for generating shell completions
app:command("completion", "Generate shell completion scripts")
    :flag_string("--shell", "Shell type (bash, zsh, fish)")
    :flag_string("--output -o", "Output directory")
    :examples({
        "gitlike completion --shell bash",
        "gitlike completion --shell zsh --output /usr/local/share/zsh/site-functions",
        "source <(gitlike completion --shell bash)"
    })
    :action(function(ctx)
        local shell = ctx.flags.shell or "bash"
        local output_dir = ctx.flags.output
        
        if shell == "all" then
            app:generate_completion("all", output_dir)
        else
            local script = app:generate_completion(shell)
            if script then
                print(script)
            end
        end
        return true
    end)

-- Add a "docs" command for generating documentation
app:command("docs", "Generate documentation")
    :flag_string("--format", "Documentation format (markdown)")
    :flag_string("--output -o", "Output directory")
    :examples({
        "gitlike docs --format markdown",
        "gitlike docs --output ./docs"
    })
    :action(function(ctx)
        local format = ctx.flags.format or "markdown"
        local output_dir = ctx.flags.output
        
        if output_dir then
            app:generate_docs(format, output_dir)
        else
            local doc = app:generate_docs(format)
            if doc then
                print(doc)
            end
        end
        return true
    end)

-- Add a "manpage" command for generating man pages
app:command("manpage", "Generate man pages")
    :flag_string("--command", "Generate man page for specific command")
    :flag_string("--output -o", "Output directory")
    :examples({
        "gitlike manpage",
        "gitlike manpage --command commit",
        "gitlike manpage --output ./man"
    })
    :action(function(ctx)
        local command = ctx.flags.command
        local output_dir = ctx.flags.output
        
        if output_dir then
            app:generate_manpage(nil, output_dir)
        else
            local manpage = app:generate_manpage(command)
            if manpage then
                print(manpage)
            end
        end
        return true
    end)

-- Demo function to show shell integration capabilities
local function demo_shell_integration()
    print("=== Lumos Shell Integration Demo ===\n")
    
    print("1. Application Structure:")
    print("   - Name: " .. app.name)
    print("   - Version: " .. app.version)
    print("   - Commands: " .. #app.commands)
    print()
    
    print("2. Available commands with aliases:")
    for _, cmd in ipairs(app.commands) do
        local aliases = cmd.aliases and #cmd.aliases > 0 and 
                       (" (aliases: " .. table.concat(cmd.aliases, ", ") .. ")") or ""
        print("   - " .. cmd.name .. aliases)
    end
    print()
    
    print("3. Generating completion scripts...")
    
    -- Generate Bash completion
    print("\n--- Bash Completion (first 10 lines) ---")
    local bash_completion = app:generate_completion("bash")
    local lines = {}
    for line in bash_completion:gmatch("[^\r\n]+") do
        table.insert(lines, line)
        if #lines >= 10 then break end
    end
    for _, line in ipairs(lines) do
        print(line)
    end
    print("... [truncated]")
    
    print("\n4. Generating documentation...")
    
    -- Generate markdown documentation (first few lines)
    print("\n--- Markdown Documentation (first 15 lines) ---")
    local markdown_doc = app:generate_docs("markdown")
    local lines = {}
    for line in markdown_doc:gmatch("[^\r\n]+") do
        table.insert(lines, line)
        if #lines >= 15 then break end
    end
    for _, line in ipairs(lines) do
        print(line)
    end
    print("... [truncated]")
    
    print("\n5. Generating man page...")
    
    -- Generate man page (first few lines)
    print("\n--- Man Page (first 10 lines) ---")
    local manpage = app:generate_manpage()
    local lines = {}
    for line in manpage:gmatch("[^\r\n]+") do
        table.insert(lines, line)
        if #lines >= 10 then break end
    end
    for _, line in ipairs(lines) do
        print(line)
    end
    print("... [truncated]")
    
    print("\n=== Shell Integration Demo Complete ===")
    print("\nTry these commands:")
    print("  lua examples/shell_integration_demo.lua completion --shell bash")
    print("  lua examples/shell_integration_demo.lua docs --format markdown")
    print("  lua examples/shell_integration_demo.lua manpage --command commit")
    print("  lua examples/shell_integration_demo.lua --help")
end

-- If run with no arguments, show demo
if #arg == 0 then
    demo_shell_integration()
else
    -- Otherwise, run the application normally
    app:run(arg)
end
