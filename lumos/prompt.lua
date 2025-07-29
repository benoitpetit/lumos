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
function prompt.select(message, options, default)
    print(message)
    for i, option in ipairs(options) do
        local marker = (default == i) and ">" or " "
        print(string.format("%s %d) %s", marker, i, option))
    end
    
    while true do
        io.write("Choose an option")
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
            print(color.red("Invalid choice. Please enter a number between 1 and " .. #options))
        end
    end
end

-- Multi-selection prompt
function prompt.multiselect(message, options)
    print(message)
    print("(Use space to select/deselect, enter to confirm)")
    
    local selected = {}
    for i = 1, #options do
        selected[i] = false
    end
    
    local current = 1
    
    -- This is a simplified version - a full implementation would require
    -- terminal manipulation for real-time updates
    while true do
        -- Display options
        for i, option in ipairs(options) do
            local marker = selected[i] and "[x]" or "[ ]"
            local pointer = (i == current) and ">" or " "
            print(string.format("%s %s %s", pointer, marker, option))
        end
        
        print("\nControls: [space] toggle, [enter] confirm, [q] quit")
        io.write("Command: ")
        io.flush()
        
        local input = io.read("*l"):lower()
        
        if input == "" then
            -- Return selected items
            local result = {}
            for i, sel in ipairs(selected) do
                if sel then
                    table.insert(result, {index = i, value = options[i]})
                end
            end
            return result
        elseif input == " " or input == "space" then
            selected[current] = not selected[current]
        elseif input == "q" or input == "quit" then
            return {}
        elseif tonumber(input) then
            local choice = tonumber(input)
            if choice >= 1 and choice <= #options then
                selected[choice] = not selected[choice]
            end
        end
        
        -- Clear screen (simple version)
        print(string.rep("\n", 10))
    end
end

-- Simple validation function
function prompt.validate(input, validator, error_message)
    if validator(input) then
        return true, input
    else
        return false, error_message or "Invalid input"
    end
end

return prompt
