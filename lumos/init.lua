-- Main Lumos Entry Point
-- This module provides the public API for the Lumos CLI framework

local app = require('lumos.app')
local core = require('lumos.core')
local flags = require('lumos.flags')
local color = require('lumos.color')
local loader = require('lumos.loader')
local progress = require('lumos.progress')
local prompt = require('lumos.prompt')
local lumos_table = require('lumos.table')

-- Export the main interface
return {
    new_app = app.new_app,
    app = app,
    core = core,
    flags = flags,
    color = color,
    loader = loader,
    progress = progress,
    prompt = prompt,
    table = lumos_table,
    version = "0.1.0"
}
