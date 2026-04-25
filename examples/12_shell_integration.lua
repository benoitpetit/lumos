#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")

local app = lumos.new_app({
    name = "shell_demo",
    version = "1.0.0",
    description = "Shell integration (completion, man pages, docs)"
})

-- Global flags
app:flag("-j --json", "JSON output")
app:flag("-o --output", "Output directory"):default("./dist")

-- Add built-in completion command (bash, zsh, fish, powershell)
app:add_completion_command()

-- Generate all completions to a directory
local all_completion = app:command("all-completion", "Generate all completions")
all_completion:action(function(ctx)
    print(color.bold("=== All Shell Completions ===\n"))

    local shells = {"bash", "zsh", "fish", "powershell"}
    local output_dir = ctx.flags.output or "./completions"

    print("Generating for: " .. color.cyan(table.concat(shells, ", ")))
    print("Output dir: " .. color.yellow(output_dir))

    app:generate_completion("all", output_dir, true)

    print(color.green("\n✓ All completions generated"))
    return true
end)

-- Command with subcommands and typed flags to demonstrate rich completion
local deploy = app:command("deploy", "Deploy application")
deploy:flag_enum("--env -e", "Environment", {"dev", "staging", "production"})
deploy:flag_string("--region -r", "Region"):complete({"us-east", "eu-west", "ap-south"})

deploy:subcommand("production", "Deploy to production")
deploy:subcommand("staging", "Deploy to staging")

-- Man page generation
local manpage = app:command("man", "Generate man page")
manpage:action(function(ctx)
    print(color.bold("=== Man Page Generation ===\n"))

    local man_content = app:generate_manpage()
    print(color.green("✓ Generated man page content"))

    print("\nMan page preview (first 20 lines):")
    print(color.dim("---"))
    local lines = {}
    for line in man_content:gmatch("[^\n]+") do
        table.insert(lines, line)
        if #lines >= 20 then break end
    end
    print(table.concat(lines, "\n"))
    print(color.dim("---"))

    return true
end)

-- Markdown docs generation
local docs = app:command("docs", "Generate documentation")
docs:action(function(ctx)
    print(color.bold("=== Markdown Documentation ===\n"))

    local md_content = app:generate_docs("markdown")
    print(color.green("✓ Generated markdown documentation"))

    print("\nDocumentation preview (first 30 lines):")
    print(color.dim("---"))
    local lines = {}
    for line in md_content:gmatch("[^\n]+") do
        table.insert(lines, line)
        if #lines >= 30 then break end
    end
    print(table.concat(lines, "\n"))
    print(color.dim("---"))

    return true
end)

os.exit(app:run(arg))
