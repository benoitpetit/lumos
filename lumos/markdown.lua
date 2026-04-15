-- Lumos Markdown Documentation Generation Module
local markdown = {}
local security = require('lumos.security')
local logger = require('lumos.logger')

-- Escape special markdown characters
local function escape_markdown(text)
    if not text then return "" end
    return text:gsub("[%*%_%[%]%(%)%#%`%\\]", "\\%1")
end

-- Generate table of contents
local function generate_toc(app)
    local toc = "## Table of Contents\n\n"
    toc = toc .. "- [Installation](#installation)\n"
    toc = toc .. "- [Usage](#usage)\n"
    toc = toc .. "- [Global Options](#global-options)\n"
    
    if #app.commands > 0 then
        toc = toc .. "- [Commands](#commands)\n"
        for _, cmd in ipairs(app.commands) do
            toc = toc .. string.format("  - [%s](#%s)\n", cmd.name, cmd.name:lower():gsub("_", "-"))
        end
    end
    
    toc = toc .. "- [Examples](#examples)\n"
    toc = toc .. "- [Shell Completion](#shell-completion)\n"
    
    return toc .. "\n"
end

-- Generate installation section
local function generate_installation(app)
    local repo_url = app.github_url or ("https://github.com/your-org/" .. app.name)
    return string.format([[## Installation

To install %s, download the binary from the releases page or build from source:

```bash
# Download binary
wget %s/releases/latest/download/%s
chmod +x %s
sudo mv %s /usr/local/bin/
```

Or build from source:

```bash
git clone %s.git
cd %s
# Build instructions here
```

]], app.name, repo_url, app.name, app.name, app.name, repo_url, app.name)
end

-- Generate usage section
local function generate_usage(app)
    local usage = "## Usage\n\n"
    usage = usage .. string.format("```\n%s [OPTIONS] [COMMAND] [ARGS...]\n```\n\n", app.name)
    usage = usage .. escape_markdown(app.description) .. "\n\n"
    
    return usage
end

-- Generate global options section
local function generate_global_options(app)
    local options = "## Global Options\n\n"
    
    -- Default options
    options = options .. "| Flag | Short | Description |\n"
    options = options .. "|------|-------|-------------|\n"
    options = options .. "| `--help` | `-h` | Show help information |\n"
    options = options .. "| `--version` | `-v` | Show version information |\n"
    
    -- Add persistent flags
    if app.persistent_flags and next(app.persistent_flags) then
        for flag_name, flag_def in pairs(app.persistent_flags) do
            local short = flag_def.short and ("`-" .. flag_def.short .. "`") or ""
            local desc = escape_markdown(flag_def.description or "")
            options = options .. string.format("| `--%s` | %s | %s |\n", flag_name, short, desc)
        end
    end
    
    return options .. "\n"
end

-- Generate command documentation
local function generate_command_docs(app, cmd)
    local docs = string.format("### %s\n\n", cmd.name)
    docs = docs .. escape_markdown(cmd.description or "") .. "\n\n"
    
    -- Add aliases
    if cmd.aliases and #cmd.aliases > 0 then
        docs = docs .. "**Aliases:** " .. table.concat(cmd.aliases, ", ") .. "\n\n"
    end
    
    -- Usage
    docs = docs .. "**Usage:**\n"
    docs = docs .. string.format("```\n%s %s [OPTIONS] [ARGS...]\n```\n\n", app.name, cmd.name)
    
    -- Command-specific options
    if cmd.flags and next(cmd.flags) then
        docs = docs .. "**Options:**\n\n"
        docs = docs .. "| Flag | Short | Type | Description |\n"
        docs = docs .. "|------|-------|------|-------------|\n"
        
        for flag_name, flag_def in pairs(cmd.flags) do
            local short = flag_def.short and ("`-" .. flag_def.short.. "`") or ""
            local flag_type = flag_def.type or "boolean"
            local desc = escape_markdown(flag_def.description or "")
            
            -- Add constraints to description
            if flag_def.min or flag_def.max then
                local constraints = {}
                if flag_def.min then table.insert(constraints, "min: " .. flag_def.min) end
                if flag_def.max then table.insert(constraints, "max: " .. flag_def.max) end
                desc = desc .. " (" .. table.concat(constraints, ", ") .. ")"
            end
            
            docs = docs .. string.format("| `--%s` | %s | %s | %s |\n", flag_name, short, flag_type, desc)
        end
        docs = docs .. "\n"
    end
    
    -- Persistent options
    if cmd.persistent_flags and next(cmd.persistent_flags) then
        docs = docs .. "**Persistent Options:**\n\n"
        docs = docs .. "| Flag | Short | Description |\n"
        docs = docs .. "|------|-------|-------------|\n"
        
        for flag_name, flag_def in pairs(cmd.persistent_flags) do
            local short = flag_def.short and ("`-" .. flag_def.short .. "`") or ""
            local desc = escape_markdown(flag_def.description or "")
            docs = docs .. string.format("| `--%s` | %s | %s |\n", flag_name, short, desc)
        end
        docs = docs .. "\n"
    end
    
    -- Subcommands
    if cmd.subcommands and #cmd.subcommands > 0 then
        docs = docs .. "**Subcommands:**\n\n"
        docs = docs .. "| Subcommand | Description |\n"
        docs = docs .. "|------------|-------------|\n"
        
        for _, subcmd in ipairs(cmd.subcommands) do
            local desc = escape_markdown(subcmd.description or "")
            docs = docs .. string.format("| `%s` | %s |\n", subcmd.name, desc)
        end
        docs = docs .. "\n"
    end
    
    -- Examples
    if cmd.examples and type(cmd.examples) == "table" and #cmd.examples > 0 then
        docs = docs .. "**Examples:**\n\n"
        for _, example in ipairs(cmd.examples) do
            docs = docs .. "```bash\n" .. example .. "\n```\n\n"
        end
    end
    
    return docs
end

-- Generate examples section
local function generate_examples(app)
    local examples = "## Examples\n\n"
    
    -- Basic usage
    examples = examples .. string.format("### Basic Usage\n\n```bash\n# Show help\n%s --help\n\n", app.name)
    examples = examples .. string.format("# Show version\n%s --version\n```\n\n", app.name)
    
    -- Command examples
    local has_command_examples = false
    for _, cmd in ipairs(app.commands) do
        if cmd.examples and type(cmd.examples) == "table" and #cmd.examples > 0 then
            if not has_command_examples then
                examples = examples .. "### Command Examples\n\n"
                has_command_examples = true
            end
            
            examples = examples .. string.format("#### %s\n\n", cmd.name)
            for _, example in ipairs(cmd.examples) do
                examples = examples .. "```bash\n" .. example .. "\n```\n\n"
            end
        end
    end
    
    return examples
end

-- Generate shell completion section
local function generate_shell_completion(app)
    return string.format([[## Shell Completion

%s supports shell completion for Bash, Zsh, and Fish.

### Bash

Add to your `~/.bashrc`:

```bash
source <(%s completion bash)
```

### Zsh

Add to your `~/.zshrc`:

```zsh
source <(%s completion zsh)
```

### Fish

```fish
%s completion fish | source
```

Or save to a file:

```fish
%s completion fish > ~/.config/fish/completions/%s.fish
```

]], app.name, app.name, app.name, app.name, app.name, app.name)
end

-- Generate main documentation
function markdown.generate_main(app)
    local content = string.format("# %s\n\n", app.name)
    content = content .. escape_markdown(app.description) .. "\n\n"
    content = content .. string.format("**Version:** %s\n\n", app.version)
    
    -- Table of contents
    content = content .. generate_toc(app)
    
    -- Installation
    content = content .. generate_installation(app)
    
    -- Usage
    content = content .. generate_usage(app)
    
    -- Global options
    content = content .. generate_global_options(app)
    
    -- Commands
    if #app.commands > 0 then
        content = content .. "## Commands\n\n"
        for _, cmd in ipairs(app.commands) do
            content = content .. generate_command_docs(app, cmd)
        end
    end
    
    -- Examples
    content = content .. generate_examples(app)
    
    -- Shell completion
    content = content .. generate_shell_completion(app)
    
    return content
end

-- Generate command-specific documentation
-- The standalone page uses H1 as the title, then H2 before the H3 sections
-- produced by generate_command_docs, keeping the heading hierarchy valid.
function markdown.generate_command(app, cmd)
    local content = string.format("# %s %s\n\n", app.name, cmd.name)
    content = content .. escape_markdown(cmd.description or "") .. "\n\n"
    content = content .. "## Reference\n\n"
    content = content .. generate_command_docs(app, cmd)
    
    return content
end

-- Generate all documentation
function markdown.generate_all(app, output_dir, verbose)
    output_dir = output_dir or "docs"
    if verbose == nil then verbose = true end
    
    -- Create output directory securely
    local success, err = security.safe_mkdir(output_dir)
    if not success then
        logger.error("Failed to create docs directory", {dir = output_dir, error = err})
        if verbose then
            print("Error: " .. (err or "Failed to create directory"))
        end
        return false
    end
    
    -- Generate main documentation
    local main_content = markdown.generate_main(app)
    local main_file, main_err = security.safe_open(output_dir .. "/README.md", "w")
    if main_file then
        main_file:write(main_content)
        main_file:close()
        if verbose then
            print("Generated: " .. output_dir .. "/README.md")
        end
    else
        logger.error("Failed to create main docs file", {error = main_err})
        return false
    end
    
    -- Generate command-specific documentation
    if #app.commands > 0 then
        local commands_dir = output_dir .. "/commands"
        local cmd_success, cmd_err = security.safe_mkdir(commands_dir)
        if not cmd_success then
            logger.warn("Failed to create commands directory", {error = cmd_err})
        else
            for _, cmd in ipairs(app.commands) do
                local cmd_content = markdown.generate_command(app, cmd)
                local cmd_file, cmd_file_err = security.safe_open(commands_dir .. "/" .. cmd.name .. ".md", "w")
                if cmd_file then
                    cmd_file:write(cmd_content)
                    cmd_file:close()
                    if verbose then
                        print("Generated: " .. commands_dir .. "/" .. cmd.name .. ".md")
                    end
                else
                    logger.error("Failed to create command doc", {command = cmd.name, error = cmd_file_err})
                end
            end
        end
    end
    
    return true
end

return markdown
