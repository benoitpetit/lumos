-- Lumos Prompt Module
-- Provides interactive prompts for user input

local color = require('lumos.color')

local prompt = {}

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
    
    -- Try to disable echo (Unix-like systems)
    local success = os.execute("stty -echo 2>/dev/null")
    local input = io.read("*l")
    
    if success then
        os.execute("stty echo 2>/dev/null")
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
        
        local input = io.read("*l"):lower()
        
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

-- Selection prompt from a list of options
-- Interactive select with arrow keys
function prompt.select(message, options, default)
    print(message)
    local current = default or 1
    local function render_menu()
        io.write(message .. "\n")
        for i, option in ipairs(options) do
            local marker = (i == current) and ">" or " "
            io.write(string.format("%s %d) %s\n", marker, i, option))
        end
        io.write("Use ↑/↓ to navigate, Enter to confirm.\n")
        io.flush()
    end
    local function update_selection()
        -- Remonte le curseur de n+1 lignes (n options + instructions)
        io.write(string.format("\27[%dA", #options + 1))
        for i, option in ipairs(options) do
            local marker = (i == current) and ">" or " "
            io.write(string.format("\r%s %d) %s\27[K\n", marker, i, option))
        end
        io.write("\rUse ↑/↓ to navigate, Enter to confirm.\27[K\n")
        io.flush()
    end
    os.execute("stty -icanon -echo")
    io.write("\27[?25l") -- hide cursor
    render_menu()
    local result = nil
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
    io.write("\27[?25h") -- show cursor
    os.execute("stty sane")
    io.write("\n")
    return result[1], result[2]
end

-- Multi-selection prompt
-- Interactive multiselect with arrow keys and space
function prompt.multiselect(message, options)
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
        io.write("Use ↑/↓ to navigate, Space to select, Enter to confirm, q to quit.\n")
        io.flush()
    end
    local function update_selection()
        io.write(string.format("\27[%dA", #options + 1))
        for i, option in ipairs(options) do
            local marker = selected[i] and "[x]" or "[ ]"
            local pointer = (i == current) and ">" or " "
            io.write(string.format("\r%s %s %s\27[K\n", pointer, marker, option))
        end
        io.write("\rUse ↑/↓ to navigate, Space to select, Enter to confirm, q to quit.\27[K\n")
        io.flush()
    end
    os.execute("stty -icanon -echo")
    io.write("\27[?25l") -- hide cursor
    render_menu()
    local done = false
    local quit = false
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
    io.write("\27[?25h") -- affiche le curseur
    os.execute("stty sane")
    io.write("\n")
    if quit then return {} end
    local result = {}
    for i, sel in ipairs(selected) do
        if sel then table.insert(result, {index = i, value = options[i]}) end
    end
    return result
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

return prompt
