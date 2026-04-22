#!/usr/bin/env lua

-- Middleware Resilience Demo
-- Demonstrates timeout and circuit breaker middleware

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local color = require('lumos.color')
local logger = require('lumos.logger')
local Middleware = require('lumos.middleware')

local app = lumos.new_app({
    name = "resilience_demo",
    version = require("lumos").version,
    description = "Resilience patterns demo"
})

-- Command protected by a 1-second timeout
-- Note: the timeout middleware is cooperative — it checks elapsed time
-- after the action finishes. If the action exceeds the limit, the
-- middleware returns a TIMEOUT error instead of the action result.
app:command("slow", "Simulate a slow operation")
    :use(Middleware.builtin.timeout({ seconds = 1 }))
    :action(function(ctx)
        logger.info("Starting slow operation...")
        local socket_ok, socket = pcall(require, "socket")
        local gettime = socket_ok and socket.gettime or os.clock
        local start = gettime()
        while gettime() - start < 2 do
            for _ = 1, 10000 do math.sqrt(12345.6789) end
        end
        print(color.yellow("Action finished, but middleware will reject it"))
        return true
    end)

-- Command protected by a circuit breaker
app:command("risky", "Simulate a failing API call")
    :use(Middleware.builtin.circuit_breaker({
        failure_threshold = 3,
        recovery_timeout = 10
    }))
    :flag("--fail", "Force failure")
    :action(function(ctx)
        if ctx.flags.fail then
            logger.error("API call failed!")
            return nil, require('lumos.error').new("EXECUTION_FAILED", "API returned 500")
        end
        print(color.green("API call succeeded"))
        return true
    end)

os.exit(app:run(arg))
