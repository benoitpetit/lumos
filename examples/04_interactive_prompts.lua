#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")
local prompt = require("lumos.prompt")

local app = lumos.new_app({
    name = "interactive_demo",
    version = "1.0.0",
    description = "Interactive CLI with prompts"
})

local survey = app:command("survey", "Interactive survey")

survey:action(function(ctx)
    print(color.bold("\n=== Interactive Survey ===\n"))

    local name = prompt.input("Your name", "Anonymous")
    print("Hello, " .. color.green(name) .. "!\n")

    local valid_email = false
    local email
    repeat
        email = prompt.input("Your email address")
        valid_email, _ = prompt.validate(email, prompt.validators.email, "Invalid email format")
        if not valid_email then
            print(color.red("Please enter a valid email address"))
        end
    until valid_email

    local age do
        local input_age
        repeat
            input_age = prompt.input("Your age")
            valid_email, _ = prompt.validate(input_age, prompt.validators.number, "Age must be a number")
            if not valid_email then
                print(color.red("Please enter a valid number"))
            end
        until valid_email
        age = tonumber(input_age)
    end

    local subscribe = prompt.confirm("Subscribe to newsletter?", false)

    local languages = {"Lua", "Python", "JavaScript", "Go", "Rust", "C", "Ruby"}
    print("\nSelect your favorite language:")
    local idx, lang = prompt.select("Language", languages, 1)

    print("\nSelect your skills (space to select):")
    local skills = {"Backend", "Frontend", "DevOps", "Data Science", "Mobile", "AI/ML"}
    local selected = prompt.multiselect("Skills", skills)

    print(color.bold("\n=== Summary ==="))
    print("Name: " .. color.cyan(name))
    print("Email: " .. color.cyan(email))
    print("Age: " .. color.cyan(tostring(age)))
    print("Newsletter: " .. (subscribe and color.green("Yes") or color.red("No")))
    print("Favorite: " .. color.yellow(lang))

    local skill_names = {}
    for _, s in ipairs(selected) do
        table.insert(skill_names, s.value)
    end
    print("Skills: " .. color.magenta(table.concat(skill_names, ", ")))

    return true
end)

local form_demo = app:command("form", "Multi-field form demo")

form_demo:action(function(ctx)
    print(color.bold("\n=== User Registration Form ===\n"))

    local result = prompt.form("Complete the form:", {
        {name = "username", type = "input", label = "Username", required = true,
         validate = prompt.validators.non_empty, error_message = "Username is required"},
        {name = "email", type = "input", label = "Email", required = true},
        {name = "age", type = "number", label = "Age", min = 13, max = 120},
        {name = "password", type = "password", label = "Password", required = true},
        {name = "notifications", type = "confirm", label = "Enable notifications", default = true},
        {name = "theme", type = "select", label = "Theme",
         options = {"light", "dark", "auto"}, default = 2}
    })

    print(color.bold("\n=== Submitted Data ==="))
    for k, v in pairs(result) do
        print(string.format("  %s: %s", k, tostring(v)))
    end
    return true
end)

local wizard = app:command("wizard", "Step-by-step wizard")

wizard:action(function(ctx)
    local result = prompt.wizard("Project Setup", {
        {
            title = "Project Info",
            description = "Enter basic project information",
            fields = {
                {name = "project_name", type = "input", label = "Project Name", required = true},
                {name = "description", type = "input", label = "Description", default = ""}
            }
        },
        {
            title = "Configuration",
            description = "Configure project settings",
            fields = {
                {name = "port", type = "number", label = "Port", default = 8080, min = 1, max = 65535},
                {name = "debug", type = "confirm", label = "Enable debug mode", default = false}
            }
        },
        {
            title = "Final Step",
            description = "Review and confirm",
            fields = {
                {name = "confirm", type = "confirm", label = "Start project?", default = true}
            }
        }
    })

    if result then
        print(color.green("\n✓ Wizard completed!"))
        for k, v in pairs(result) do
            print(string.format("  %s: %s", k, tostring(v)))
        end
    end
    return true
end)

os.exit(app:run(arg))