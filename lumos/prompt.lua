-- Lumos Prompt Module
-- Provides interactive prompts for user input

local color = require('lumos.color')

local prompt = {}

-- Detect if running on Windows
local function is_windows()
    return package.config:sub(1,1) == '\\'
end

-- Check if stty is available (Unix-like only)
local function has_stty()
    if is_windows() then return false end
    local ok = os.execute("stty size >/dev/null 2>&1")
    return ok == 0 or ok == true
end

-- Basic text input prompt
function prompt.input(message, default)
    io.write(message)
    if default then
        io.write(" [" .. default .. "]")
    end
    io.write(": ")
    io.flush()
    
    local input = io.read("*l")
    if input == "" and default then
        return default
    end
    return input
end

-- Password input (attempts to hide input)
function prompt.password(message)
    io.write(message .. ": ")
    io.flush()
    
    local input
    if not is_windows() and has_stty() then
        -- Unix-like systems: disable echo
        os.execute("stty -echo 2>/dev/null")
        input = io.read("*l")
        os.execute("stty echo 2>/dev/null")
    else
        -- Fallback: read normally (Windows or no stty)
        input = io.read("*l")
    end
    
    io.write("\n")
    return input
end

-- Confirmation prompt (y/n)
function prompt.confirm(message, default)
    local default_text = ""
    if default ~= nil then
        default_text = default and " [Y/n]" or " [y/N]"
    else
        default_text = " [y/n]"
    end
    
    while true do
        io.write(message .. default_text .. ": ")
        io.flush()
        
        local input = io.read("*l")
        -- Handle EOF gracefully
        if input == nil then
            return default ~= nil and default or false
        end
        input = input:lower()
        
        if input == "" and default ~= nil then
            return default
        elseif input == "y" or input == "yes" then
            return true
        elseif input == "n" or input == "no" then
            return false
        else
            print("Please enter 'y' or 'n'")
        end
    end
end

-- Simple selection prompt for Windows/environments without terminal controls
function prompt.simple_select(message, options, default)
    print(message)
    for i, option in ipairs(options) do
        print(string.format("  %d) %s", i, option))
    end
    
    while true do
        io.write("Select an option")
        if default then
            io.write(" [" .. default .. "]")
        end
        io.write(": ")
        io.flush()
        
        local input = io.read("*l")
        if input == "" and default then
            return default, options[default]
        end
        
        local choice = tonumber(input)
        if choice and choice >= 1 and choice <= #options then
            return choice, options[choice]
        else
            print("Please enter a valid number between 1 and " .. #options)
        end
    end
end

-- Selection prompt from a list of options
-- Interactive select with arrow keys
function prompt.select(message, options, default)
    -- Use simple select on Windows or if terminal controls aren't available
    if is_windows() or not has_stty() then
        return prompt.simple_select(message, options, default)
    end
    local current = default or 1
    local function render_menu()
        io.write(message .. "\n")
        for i, option in ipairs(options) do
            local marker = (i == current) and ">" or " "
            io.write(string.format("%s %d) %s\n", marker, i, option))
        end
        io.write("Use up/down to navigate, Enter to confirm.\n")
        io.flush()
    end
    local function update_selection()
        -- Move cursor up by n+1 lines (n options + instructions)
        io.write(string.format("\27[%dA", #options + 1))
        for i, option in ipairs(options) do
            local marker = (i == current) and ">" or " "
            io.write(string.format("\r%s %d) %s\27[K\n", marker, i, option))
        end
        io.write("\rUse up/down to navigate, Enter to confirm.\27[K\n")
        io.flush()
    end
    os.execute("stty -icanon -echo")
    io.write("\27[?25l") -- hide cursor
    render_menu()
    local result = nil
    local ok, err = pcall(function()
        while not result do
            local c = io.read(1)
            if c == "\27" then -- escape
                local c2 = io.read(1)
                if c2 == "[" then
                    local c3 = io.read(1)
                    if c3 == "A" then -- up
                        current = current > 1 and current - 1 or #options
                        update_selection()
                    elseif c3 == "B" then -- down
                        current = current < #options and current + 1 or 1
                        update_selection()
                    end
                end
            elseif c == "\r" or c == "\n" then -- enter
                result = {current, options[current]}
            end
        end
    end)
    io.write("\27[?25h") -- show cursor
    os.execute("stty sane")
    io.write("\n")
    if not ok then error(err, 2) end
    return result[1], result[2]
end

-- Multi-selection prompt
-- Interactive multiselect with arrow keys and space
function prompt.multiselect(message, options)
    if is_windows() or not has_stty() then
        -- Fallback on Windows or no stty: return empty (interactive not possible)
        print(message)
        print("(Interactive multi-selection not available on this platform)")
        return {}
    end
    print(message)
    local selected = {}
    for i = 1, #options do selected[i] = false end
    local current = 1
    local function render_menu()
        io.write(message .. "\n")
        for i, option in ipairs(options) do
            local marker = selected[i] and "[x]" or "[ ]"
            local pointer = (i == current) and ">" or " "
            io.write(string.format("%s %s %s\n", pointer, marker, option))
        end
        io.write("Use up/down to navigate, Space to select, Enter to confirm, q to quit.\n")
        io.flush()
    end
    local function update_selection()
        io.write(string.format("\27[%dA", #options + 1))
        for i, option in ipairs(options) do
            local marker = selected[i] and "[x]" or "[ ]"
            local pointer = (i == current) and ">" or " "
            io.write(string.format("\r%s %s %s\27[K\n", pointer, marker, option))
        end
        io.write("\rUse up/down to navigate, Space to select, Enter to confirm, q to quit.\27[K\n")
        io.flush()
    end
    os.execute("stty -icanon -echo")
    io.write("\27[?25l") -- hide cursor
    render_menu()
    local done = false
    local quit = false
    local ok, err = pcall(function()
        while not done and not quit do
            local c = io.read(1)
            if c == "\27" then -- escape
                local c2 = io.read(1)
                if c2 == "[" then
                    local c3 = io.read(1)
                    if c3 == "A" then -- up
                        current = current > 1 and current - 1 or #options
                        update_selection()
                    elseif c3 == "B" then -- down
                        current = current < #options and current + 1 or 1
                        update_selection()
                    end
                end
            elseif c == " " then -- space
                selected[current] = not selected[current]
                update_selection()
            elseif c == "q" then
                quit = true
            elseif c == "\r" or c == "\n" then -- enter
                done = true
            end
        end
    end)
    io.write("\27[?25h") -- show cursor
    os.execute("stty sane")
    io.write("\n")
    if not ok then error(err, 2) end
    if quit then return {} end
    local result = {}
    for i, sel in ipairs(selected) do
        if sel then table.insert(result, {index = i, value = options[i]}) end
    end
    return result
end

-- Number input with optional min/max constraints
function prompt.number(message, min, max, default)
    local hint = ""
    if min and max then
        hint = string.format(" (%d-%d)", min, max)
    elseif min then
        hint = string.format(" (>= %d)", min)
    elseif max then
        hint = string.format(" (<= %d)", max)
    end
    while true do
        io.write(message .. hint)
        if default ~= nil then
            io.write(" [" .. tostring(default) .. "]")
        end
        io.write(": ")
        io.flush()
        local input = io.read("*l")
        if input == "" and default ~= nil then
            return default
        end
        local num = tonumber(input)
        if num == nil then
            print("Please enter a valid number")
        elseif min and num < min then
            print("Value must be >= " .. tostring(min))
        elseif max and num > max then
            print("Value must be <= " .. tostring(max))
        else
            return num
        end
    end
end

-- Input that loops until validation passes
function prompt.required_input(message, validator, error_message)
    while true do
        local input = prompt.input(message)
        if input and input ~= "" then
            local ok, err = prompt.validate(input, validator or function() return true end, error_message)
            if ok then
                return input
            else
                print(err)
            end
        else
            print("This field is required")
        end
    end
end

-- Autocomplete input with prefix matching from a list of options
function prompt.autocomplete(message, options, default)
    io.write(message)
    if default then
        io.write(" [" .. default .. "]")
    end
    io.write(" (type prefix, Enter to match)")
    if #options <= 10 then
        io.write(":\n  Options: " .. table.concat(options, ", ") .. "\n> ")
    else
        io.write(": ")
    end
    io.flush()
    local input = io.read("*l")
    if input == "" and default then
        return default
    end
    -- Simple prefix matching suggestion
    local matches = {}
    for _, opt in ipairs(options) do
        if opt:lower():sub(1, #input) == input:lower() then
            table.insert(matches, opt)
        end
    end
    if #matches == 1 then
        return matches[1]
    elseif #matches > 1 then
        print("Multiple matches: " .. table.concat(matches, ", "))
        local _, choice = prompt.simple_select("Select one", matches)
        return choice
    end
    return input
end

-- Searchable/select from a list with simple filter
function prompt.search(message, options)
    print(message)
    print("Type to filter, empty to show all, Enter to select by number:")
    while true do
        io.write("Filter: ")
        io.flush()
        local input = io.read("*l") or ""
        local filter = input:lower()
        local filtered = {}
        for _, opt in ipairs(options) do
            if filter == "" or opt:lower():find(filter, 1, true) then
                table.insert(filtered, opt)
            end
        end
        if #filtered == 0 then
            print("No matches found for '" .. input .. "'. Try again or press Enter to show all.")
        else
            return prompt.simple_select("Select", filtered)
        end
    end
end

-- Open $EDITOR for multi-line input
function prompt.editor(message, default)
    local editor = os.getenv("EDITOR") or os.getenv("VISUAL") or "vi"
    local tmpfile = os.tmpname()
    local f = io.open(tmpfile, "w")
    if not f then
        error("Could not create temporary file for editor")
    end
    if default then
        f:write(default)
    end
    f:close()
    local ok = os.execute(editor .. " " .. tmpfile)
    if ok ~= 0 and ok ~= true then
        os.remove(tmpfile)
        error("Editor exited with error")
    end
    f = io.open(tmpfile, "r")
    if not f then
        os.remove(tmpfile)
        error("Could not read temporary file")
    end
    local content = f:read("*all")
    f:close()
    os.remove(tmpfile)
    -- Strip trailing newline for convenience
    content = content:gsub("\n$", "")
    return content
end

-- Multi-field form builder
-- fields: array of {name="field_name", type="input|number|password|select|confirm", ...}
function prompt.form(title, fields)
    if title then
        print(title)
    end
    local result = {}
    for _, field in ipairs(fields) do
        local value
        local msg = field.label or field.name
        if field.type == "number" then
            value = prompt.number(msg, field.min, field.max, field.default)
        elseif field.type == "password" then
            if field.required then
                while true do
                    value = prompt.password(msg)
                    if value and value ~= "" then break end
                    print("This field is required")
                end
            else
                value = prompt.password(msg)
            end
        elseif field.type == "confirm" then
            value = prompt.confirm(msg, field.default)
        elseif field.type == "select" then
            local _, choice = prompt.select(msg, field.options, field.default)
            value = choice
        elseif field.type == "autocomplete" then
            if field.required then
                while true do
                    value = prompt.autocomplete(msg, field.options, field.default)
                    if value and value ~= "" then break end
                    print("This field is required")
                end
            else
                value = prompt.autocomplete(msg, field.options, field.default)
            end
        elseif field.type == "editor" then
            if field.required then
                while true do
                    value = prompt.editor(msg, field.default)
                    if value and value ~= "" then break end
                    print("This field is required")
                end
            else
                value = prompt.editor(msg, field.default)
            end
        else
            if field.required then
                value = prompt.required_input(msg, field.validate, field.error_message)
            else
                value = prompt.input(msg, field.default)
                if field.validate and value ~= "" then
                    local ok, err = prompt.validate(value, field.validate, field.error_message)
                    if not ok then
                        print(err)
                        value = prompt.input(msg, field.default)
                    end
                end
            end
        end
        result[field.name] = value
    end
    return result
end

-- Multi-step wizard builder
-- steps: array of {title="Step 1", fields={...}}
function prompt.wizard(title, steps)
    if title then
        print("=== " .. title .. " ===")
    end
    local results = {}
    for i, step in ipairs(steps) do
        print(string.format("\n[%d/%d] %s", i, #steps, step.title))
        if step.description then
            print(step.description)
        end
        local step_data = prompt.form(nil, step.fields or {})
        for k, v in pairs(step_data) do
            results[k] = v
        end
        if step.action then
            local ok, err = pcall(step.action, step_data, results)
            if not ok then
                print("Error in step: " .. tostring(err))
                return nil, err
            end
        end
    end
    return results
end

-- Simple validation function
function prompt.validate(input, validator, error_message)
    if validator(input) then
        return true, input
    else
        return false, error_message or "Invalid input"
    end
end

-- Predefined validators
prompt.validators = {}

function prompt.validators.email(input)
    local pattern = "^[A-Za-z0-9%.%+_%%-]+@[A-Za-z0-9%-]+%.[A-Za-z]+$"
    return input:match(pattern) ~= nil
end

function prompt.validators.number(input)
    return tonumber(input) ~= nil
end

function prompt.validators.integer(input)
    local n = tonumber(input)
    return n ~= nil and math.floor(n) == n
end

function prompt.validators.url(input)
    local pattern = "^https?://[%w%.%-%_]+%.[A-Za-z]+"
    return input:match(pattern) ~= nil
end

function prompt.validators.non_empty(input)
    return input ~= nil and input ~= ""
end

function prompt.validators.one_of(options)
    return function(input)
        for _, opt in ipairs(options) do
            if opt == input then
                return true
            end
        end
        return false
    end
end

function prompt.validators.regex(pattern)
    return function(input)
        return input:match(pattern) ~= nil
    end
end

return prompt
