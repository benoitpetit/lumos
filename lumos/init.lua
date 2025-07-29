-- Main Lumos Entry Point
-- This module provides the public API for the Lumos CLI framework

local app = require('lumos.app')
local core = require('lumos.core')
local flags = require('lumos.flags')

-- Export the main interface
return {
    new_app = app.new_app,
    version = "0.1.0"
}
