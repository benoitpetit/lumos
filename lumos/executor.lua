-- Lumos Executor Module
-- Command execution, hooks, and middleware chaining

local logger = require('lumos.logger')
local Error = require('lumos.error')
local parser = require('lumos.parser')
local validator = require('lumos.validator')
local help_renderer = require('lumos.help_renderer')

local executor = {}

-- Exit code constants
executor.EXIT_OK = 0
executor.EXIT_ERROR = 1
executor.EXIT_USAGE = 2

-- Run a list of hooks, returning false if any hook errors
local function run_hooks(hooks, context)
    if not hooks then return true end
    for _, hook in ipairs(hooks) do
        local ok, err = pcall(hook, context)
        if not ok then
            io.stderr:write("Error in hook: " .. tostring(err) .. "\n")
            return false
        end
    end
    return true
end

-- Execute action through middleware chain (app + command)
function executor.execute_action(app, cmd, context, action_fn)
    local Middleware = require("lumos.middleware")
    local chain = Middleware.new()

    if app.middleware_chain then
        for _, entry in ipairs(app.middleware_chain) do
            chain:use(entry.fn, entry.priority)
        end
    end

    if cmd and cmd.middleware_chain then
        for _, entry in ipairs(cmd.middleware_chain) do
            chain:use(entry.fn, entry.priority)
        end
    end

    return chain:execute(context, action_fn)
end

-- Execute the appropriate command with parsed arguments
function executor.execute_command(app, parsed_args)
    local cmd = parser.find_command(app, parsed_args.command)

    if not cmd then
        if parsed_args.command then
            logger.warn("Unknown command", {command = parsed_args.command})
            io.stderr:write("Error: Unknown command '" .. parsed_args.command .. "'\n")
            local suggestion = parser.suggest_command(app, parsed_args.command)
            if suggestion then
                io.stderr:write("Did you mean '" .. suggestion .. "'?\n")
            end
            help_renderer.show_help(app)
            return executor.EXIT_USAGE
        else
            help_renderer.show_help(app)
            return executor.EXIT_OK
        end
    end

    logger.debug("Executing command", {command = cmd.name, args = parsed_args.args})

    -- Handle subcommands if present
    if parsed_args.subcommand and cmd.subcommands then
        local subcmd = parser.find_subcommand(cmd, parsed_args.subcommand)
        if subcmd then
            -- Check for help flag on subcommand
            if parsed_args.flags.help or parsed_args.flags.h then
                help_renderer.show_command_help(app, subcmd)
                return executor.EXIT_OK
            end

            -- Validate args and flags for subcommand
            if rawget(subcmd, 'action') then
                local validated_args, arg_errors = validator.validate_args(subcmd, parsed_args)
                if #arg_errors > 0 then
                    logger.error("Subcommand argument validation failed", {errors = arg_errors})
                    for _, error in ipairs(arg_errors) do
                        io.stderr:write("Error: " .. error .. "\n")
                    end
                    return executor.EXIT_USAGE
                end

                local validated_flags, validation_errors = validator.validate_and_merge_flags(app, subcmd, parsed_args.flags)
                if #validation_errors > 0 then
                    logger.error("Subcommand flag validation failed", {errors = validation_errors})
                    for _, error in ipairs(validation_errors) do
                        io.stderr:write("Error: " .. error .. "\n")
                    end
                    return executor.EXIT_USAGE
                end

                -- Execute subcommand action
                local context = {
                    args = validated_args,
                    flags = validated_flags,
                    command = subcmd,
                    parent = cmd,
                    config = app.loaded_config,
                    env = app.loaded_env,
                    output_format = parsed_args.output_format or "table"
                }

                if not run_hooks(app.persistent_pre_runs, context) then return executor.EXIT_ERROR end
                if not run_hooks(cmd.persistent_pre_runs, context) then return executor.EXIT_ERROR end
                if not run_hooks(subcmd.pre_runs, context) then return executor.EXIT_ERROR end
                local success, result, middleware_err = xpcall(function()
                    return executor.execute_action(app, subcmd, context, function()
                        return subcmd.action(context)
                    end)
                end, function(err)
                    if debug and type(debug.traceback) == "function" then
                        return err .. "\n" .. debug.traceback("", 2)
                    end
                    return err
                end)
                run_hooks(subcmd.post_runs, {success = success, result = result, config = context.config, env = context.env, command = subcmd, parent = cmd, args = context.args, flags = context.flags})
                run_hooks(cmd.persistent_post_runs, {success = success, result = result, config = context.config, env = context.env, command = subcmd, parent = cmd, args = context.args, flags = context.flags})
                run_hooks(app.persistent_post_runs, {success = success, result = result, config = context.config, env = context.env, command = subcmd, parent = cmd, args = context.args, flags = context.flags})
                if not success then
                    logger.error("Command action failed", {command = subcmd.name, error = tostring(result)})
                    if os.getenv("LUMOS_DEBUG") then
                        io.stderr:write("Error executing command: " .. tostring(result) .. "\n")
                    else
                        local user_msg = tostring(result):match("^([^\n]+)") or tostring(result)
                        io.stderr:write("Error executing command: " .. user_msg .. "\n")
                    end
                    return executor.EXIT_ERROR
                end
                if middleware_err then
                    if Error.is_error(middleware_err) then
                        if middleware_err.exit_code ~= 0 then
                            io.stderr:write(middleware_err:format_user() .. "\n")
                        end
                        return middleware_err.exit_code
                    else
                        io.stderr:write("Error: " .. tostring(middleware_err) .. "\n")
                        return executor.EXIT_ERROR
                    end
                end
                -- Handle typed errors, success objects, and legacy booleans
                if Error.is_error(result) then
                    if result.exit_code ~= 0 then
                        io.stderr:write(result:format_user() .. "\n")
                    end
                    return result.exit_code
                elseif type(result) == "table" and result.success ~= nil then
                    return result.exit_code or (result.success and executor.EXIT_OK or executor.EXIT_ERROR)
                end
                return (result == false) and executor.EXIT_ERROR or executor.EXIT_OK
            else
                io.stderr:write("Error: No action defined for subcommand '" .. subcmd.name .. "'\n")
                return executor.EXIT_USAGE
            end
        else
            io.stderr:write("Error: Unknown subcommand '" .. parsed_args.subcommand .. "' for command '" .. cmd.name .. "'\n")
            local sub_suggestion = parser.suggest_subcommand(cmd, parsed_args.subcommand)
            if sub_suggestion then
                io.stderr:write("Did you mean '" .. sub_suggestion .. "'?\n")
            end
            return executor.EXIT_USAGE
        end
    end

    -- If command has subcommands but no subcommand was matched,
    -- check if the first positional arg looks like a typo of a subcommand
    if not parsed_args.subcommand and cmd.subcommands and #cmd.subcommands > 0 then
        local possible = parsed_args.args[1]
        if possible then
            local suggestion = parser.suggest_subcommand(cmd, possible)
            if suggestion then
                io.stderr:write("Error: Unknown subcommand '" .. possible .. "' for command '" .. cmd.name .. "'\n")
                io.stderr:write("Did you mean '" .. suggestion .. "'?\n")
                return executor.EXIT_USAGE
            end
        end
    end

    -- Check for help flag
    if parsed_args.flags.help or parsed_args.flags.h then
        help_renderer.show_command_help(app, cmd)
        return executor.EXIT_OK
    end

    -- Validate args and flags
    local validated_args, arg_errors = validator.validate_args(cmd, parsed_args)
    if #arg_errors > 0 then
        logger.error("Argument validation failed", {errors = arg_errors})
        for _, error in ipairs(arg_errors) do
            io.stderr:write("Error: " .. error .. "\n")
        end
        return executor.EXIT_USAGE
    end

    local validated_flags, validation_errors = validator.validate_and_merge_flags(app, cmd, parsed_args.flags)
    if #validation_errors > 0 then
        logger.error("Flag validation failed", {errors = validation_errors})
        for _, error in ipairs(validation_errors) do
            io.stderr:write("Error: " .. error .. "\n")
        end
        return executor.EXIT_USAGE
    end

    -- Execute the command action if it exists
    if rawget(cmd, 'action') then
        local context = {
            args = validated_args,
            flags = validated_flags,
            command = cmd,
            config = app.loaded_config,
            env = app.loaded_env,
            output_format = parsed_args.output_format or "table"
        }

        -- Execute with error handling.
        -- xpcall captures the traceback at the point of the actual error,
        -- not at the recovery site.  Guard against sandboxed Lua without debug lib.
        local function error_handler(err)
            if debug and type(debug.traceback) == "function" then
                return err .. "\n" .. debug.traceback("", 2)
            end
            return err
        end

        if not run_hooks(app.persistent_pre_runs, context) then return executor.EXIT_ERROR end
        if not run_hooks(cmd.persistent_pre_runs, context) then return executor.EXIT_ERROR end
        if not run_hooks(cmd.pre_runs, context) then return executor.EXIT_ERROR end
        local success, result, middleware_err = xpcall(function()
            return executor.execute_action(app, cmd, context, function()
                return cmd.action(context)
            end)
        end, error_handler)
        run_hooks(cmd.post_runs, {success = success, result = result, config = context.config, env = context.env, command = cmd, args = context.args, flags = context.flags})
        run_hooks(cmd.persistent_post_runs, {success = success, result = result, config = context.config, env = context.env, command = cmd, args = context.args, flags = context.flags})
        run_hooks(app.persistent_post_runs, {success = success, result = result, config = context.config, env = context.env, command = cmd, args = context.args, flags = context.flags})
        if not success then
            logger.error("Command action failed", {command = cmd.name, error = tostring(result)})
            if os.getenv("LUMOS_DEBUG") then
                io.stderr:write("Error executing command: " .. tostring(result) .. "\n")
            else
                -- Strip traceback from user-visible message when not in debug mode
                local user_msg = tostring(result):match("^([^\n]+)") or tostring(result)
                io.stderr:write("Error executing command: " .. user_msg .. "\n")
            end
            return executor.EXIT_ERROR
        end
        if middleware_err then
            if Error.is_error(middleware_err) then
                if middleware_err.exit_code ~= 0 then
                    io.stderr:write(middleware_err:format_user() .. "\n")
                end
                return middleware_err.exit_code
            else
                io.stderr:write("Error: " .. tostring(middleware_err) .. "\n")
                return executor.EXIT_ERROR
            end
        end
        -- Handle typed errors, success objects, and legacy booleans
        if Error.is_error(result) then
            if result.exit_code ~= 0 then
                io.stderr:write(result:format_user() .. "\n")
            end
            return result.exit_code
        elseif type(result) == "table" and result.success ~= nil then
            return result.exit_code or (result.success and executor.EXIT_OK or executor.EXIT_ERROR)
        end
        return (result == false) and executor.EXIT_ERROR or executor.EXIT_OK
    else
        -- If no action but has subcommands, show help
        if cmd.subcommands and #cmd.subcommands > 0 then
            help_renderer.show_command_help(app, cmd)
            return executor.EXIT_OK
        elseif app.no_args_is_help then
            help_renderer.show_command_help(app, cmd)
            return executor.EXIT_OK
        else
            logger.warn("No action defined for command", {command = cmd.name})
            io.stderr:write("Error: No action defined for command '" .. cmd.name .. "'\n")
            return executor.EXIT_USAGE
        end
    end
end

return executor
