-- Lumos Help Renderer Module
-- Rich help text generation with colors, alignment, and metadata

local help_renderer = {}

local color
local function get_color()
    if not color then
        local ok, mod = pcall(require, "lumos.color")
        color = ok and mod or {
            cyan = function(s) return s end,
            yellow = function(s) return s end,
            green = function(s) return s end,
            red = function(s) return s end,
            dim = function(s) return s end,
            bold = function(s) return s end,
        }
    end
    return color
end

local function should_show(cmd_or_flag)
    if not cmd_or_flag._hidden then return true end
    return os.getenv("LUMOS_DEBUG") ~= nil
end

local function build_flag_text(flag_def)
    local parts = {}
    if flag_def.short then
        table.insert(parts, "-" .. flag_def.short)
    end
    if flag_def.long then
        table.insert(parts, "--" .. flag_def.long)
    elseif flag_def.short then
        table.insert(parts, "--" .. flag_def.short)
    end
    return table.concat(parts, ", ")
end

local function flag_meta(flag_def)
    local meta = {}
    if flag_def.required then
        table.insert(meta, "required")
    end
    if flag_def.default ~= nil then
        table.insert(meta, "default: " .. tostring(flag_def.default))
    end
    if flag_def.env then
        table.insert(meta, "env: " .. flag_def.env)
    end
    if flag_def.deprecated then
        table.insert(meta, "deprecated")
    end
    if #meta > 0 then
        return " [" .. table.concat(meta, ", ") .. "]"
    end
    return ""
end

local function print_aligned(items, indent)
    indent = indent or 2
    local prefix = string.rep(" ", indent)
    local max_left = 0
    for _, item in ipairs(items) do
        max_left = math.max(max_left, #item.left)
    end
    local term_width = 80
    local ok, terminal = pcall(require, "lumos.terminal")
    if ok then
        term_width = terminal.width() or 80
    end
    local right_start = math.min(max_left + 6, 40)
    for _, item in ipairs(items) do
        local left = prefix .. item.left
        local padding = math.max(right_start - #left, 1)
        local right_width = term_width - #left - padding - 2
        local right = item.right or ""
        if #right > right_width and right_width > 20 then
            right = right:sub(1, right_width - 3) .. "..."
        end
        print(left .. string.rep(" ", padding) .. right)
    end
end

-- Display help for the entire application
function help_renderer.show_help(app)
    local c = get_color()
    print(c.bold(app.name) .. c.dim(" v" .. app.version))
    print(app.description)
    print()
    print(c.dim("Usage: ") .. app.name .. " [command] [flags]")
    print()

    if #app.commands > 0 then
        -- Group commands by category
        local categorized = {}
        local uncategorized = {}
        for _, cmd in ipairs(app.commands) do
            if not should_show(cmd) then
                -- skip hidden commands unless LUMOS_DEBUG
            elseif cmd._category then
                categorized[cmd._category] = categorized[cmd._category] or {}
                table.insert(categorized[cmd._category], cmd)
            else
                table.insert(uncategorized, cmd)
            end
        end

        for category, cmds in pairs(categorized) do
            print(c.cyan(category .. " commands:"))
            local items = {}
            for _, cmd in ipairs(cmds) do
                local aliases = ""
                if cmd.aliases and #cmd.aliases > 0 then
                    aliases = c.dim(" (" .. table.concat(cmd.aliases, ", ") .. ")")
                end
                table.insert(items, {
                    left = cmd.name .. aliases,
                    right = cmd.description or ""
                })
            end
            print_aligned(items)
            print()
        end

        if #uncategorized > 0 then
            print(c.cyan("Available commands:"))
            local items = {}
            for _, cmd in ipairs(uncategorized) do
                local aliases = ""
                if cmd.aliases and #cmd.aliases > 0 then
                    aliases = c.dim(" (" .. table.concat(cmd.aliases, ", ") .. ")")
                end
                table.insert(items, {
                    left = cmd.name .. aliases,
                    right = cmd.description or ""
                })
            end
            print_aligned(items)
            print()
        end
    end

    print(c.cyan("Global flags:"))
    local global_items = {
        {left = "-h, --help", right = "Show help information"},
        {left = "-v, --version", right = "Show version information"},
    }

    -- Display app-level flags defined via app:flag()
    if app.global_flags then
        for flag_name, flag_def in pairs(app.global_flags) do
            if should_show(flag_def) then
                table.insert(global_items, {
                    left = build_flag_text(flag_def),
                    right = (flag_def.description or "") .. c.dim(flag_meta(flag_def))
                })
            end
        end
    end
    print_aligned(global_items)

    -- Display app-level persistent flags defined via app:persistent_flag()
    if app.persistent_flags and next(app.persistent_flags) then
        print()
        print(c.cyan("Persistent flags (inherited by all commands):"))
        local persistent_items = {}
        for flag_name, flag_def in pairs(app.persistent_flags) do
            if should_show(flag_def) then
                table.insert(persistent_items, {
                    left = build_flag_text(flag_def),
                    right = (flag_def.description or "") .. c.dim(flag_meta(flag_def))
                })
            end
        end
        print_aligned(persistent_items)
    end
end

-- Display help for a specific command
function help_renderer.show_command_help(app, cmd)
    local c = get_color()
    print(c.bold("Usage: ") .. app.name .. " " .. cmd.name .. " [flags] [arguments]")
    print()
    print(cmd.description or "No description available")
    print()

    if cmd.aliases and #cmd.aliases > 0 then
        print(c.dim("Aliases: ") .. table.concat(cmd.aliases, ", "))
        print()
    end

    if cmd.examples and type(cmd.examples) == "table" and #cmd.examples > 0 then
        print(c.cyan("Examples:"))
        for _, example in ipairs(cmd.examples) do
            print("  " .. c.dim("$") .. " " .. example)
        end
        print()
    end

    if cmd.args and #cmd.args > 0 then
        print(c.cyan("Arguments:"))
        local items = {}
        for _, arg in ipairs(cmd.args) do
            local meta = ""
            if arg.required then meta = meta .. " [required]" end
            if arg.default ~= nil then meta = meta .. " [default: " .. tostring(arg.default) .. "]" end
            table.insert(items, {
                left = arg.name,
                right = (arg.description or "") .. c.dim(meta)
            })
        end
        print_aligned(items)
        print()
    end

    local all_flags = {}
    if cmd.flags then
        for name, flag in pairs(cmd.flags) do
            if should_show(flag) then
                table.insert(all_flags, {left = build_flag_text(flag), right = (flag.description or "") .. c.dim(flag_meta(flag)), _sort = name})
            end
        end
    end
    if cmd.persistent_flags and next(cmd.persistent_flags) then
        for name, flag in pairs(cmd.persistent_flags) do
            if should_show(flag) then
                table.insert(all_flags, {left = build_flag_text(flag), right = (flag.description or "") .. c.dim(flag_meta(flag)) .. c.dim(" [persistent]"), _sort = name})
            end
        end
    end
    if #all_flags > 0 then
        table.sort(all_flags, function(a, b) return a._sort < b._sort end)
        print(c.cyan("Flags:"))
        print_aligned(all_flags)
        print()
    end

    if cmd.mutex_groups then
        for name, group in pairs(cmd.mutex_groups) do
            local flag_names = {}
            for _, flag in ipairs(group.flags) do
                table.insert(flag_names, "--" .. (flag.long or flag.short))
            end
            local meta = group.required and " (at least one required)" or ""
            print(c.yellow("Mutually exclusive") .. c.dim(": " .. table.concat(flag_names, ", ") .. meta))
        end
        print()
    end

    if cmd.subcommands and #cmd.subcommands > 0 then
        print(c.cyan("Subcommands:"))
        local items = {}
        for _, sub in ipairs(cmd.subcommands) do
            if should_show(sub) then
                table.insert(items, {
                    left = sub.name,
                    right = sub.description or ""
                })
            end
        end
        print_aligned(items)
        print()
    end
end

return help_renderer
