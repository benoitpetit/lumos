-- Lumos Help Renderer Module
-- Help text generation

local help_renderer = {}

-- Display help for the entire application
function help_renderer.show_help(app)
    print(app.name .. " v" .. app.version)
    print(app.description)
    print()
    print("Usage: " .. app.name .. " [command] [flags]")
    print()
    
    if #app.commands > 0 then
        -- Group commands by category
        local categorized = {}
        local uncategorized = {}
        for _, cmd in ipairs(app.commands) do
            if cmd._category then
                categorized[cmd._category] = categorized[cmd._category] or {}
                table.insert(categorized[cmd._category], cmd)
            else
                table.insert(uncategorized, cmd)
            end
        end
        
        for category, cmds in pairs(categorized) do
            print(category .. " commands:")
            for _, cmd in ipairs(cmds) do
                print("  " .. cmd.name .. "\t" .. (cmd.description or ""))
            end
            print()
        end
        
        if #uncategorized > 0 then
            print("Available commands:")
            for _, cmd in ipairs(uncategorized) do
                print("  " .. cmd.name .. "\t" .. (cmd.description or ""))
            end
            print()
        end
    end
    
    print("Global flags:")
    print("  -h, --help    Show help information")
    print("  -v, --version Show version information")

    -- Display app-level flags defined via app:flag()
    if app.global_flags and next(app.global_flags) then
        for flag_name, flag_def in pairs(app.global_flags) do
            local flag_text = "  "
            if flag_def.short then
                flag_text = flag_text .. "-" .. flag_def.short .. ", "
            end
            flag_text = flag_text .. "--" .. flag_name
            if flag_def.description then
                flag_text = flag_text .. "\t" .. flag_def.description
            end
            print(flag_text)
        end
    end

    -- Display app-level persistent flags defined via app:persistent_flag()
    if app.persistent_flags and next(app.persistent_flags) then
        print()
        print("Persistent flags (inherited by all commands):")
        for flag_name, flag_def in pairs(app.persistent_flags) do
            local flag_text = "  "
            if flag_def.short then
                flag_text = flag_text .. "-" .. flag_def.short .. ", "
            end
            flag_text = flag_text .. "--" .. flag_name
            if flag_def.description then
                flag_text = flag_text .. "\t" .. flag_def.description
            end
            print(flag_text)
        end
    end
end

-- Display help for a specific command
function help_renderer.show_command_help(app, cmd)
    print("Usage: " .. app.name .. " " .. cmd.name .. " [flags] [arguments]")
    print()
    print(cmd.description or "No description available")
    print()
    
    if cmd.examples and type(cmd.examples) == "table" and #cmd.examples > 0 then
        print("Examples:")
        for _, example in ipairs(cmd.examples) do
            print("  " .. example)
        end
        print()
    end
    
    if cmd.flags and next(cmd.flags) then
        print("Flags:")
        for name, flag in pairs(cmd.flags) do
            local flag_text = "  "
            if flag.short then
                flag_text = flag_text .. "-" .. flag.short .. ", "
            end
            flag_text = flag_text .. "--" .. name
            if flag.description then
                flag_text = flag_text .. "\t" .. flag.description
            end
            print(flag_text)
        end
    end
end

return help_renderer
