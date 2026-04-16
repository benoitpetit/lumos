#!/usr/bin/env lua

-- Table Pagination Demo
-- Demonstrates tbl.paginate() and tbl.page() combined with table rendering

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local tbl = require('lumos.table')
local color = require('lumos.color')

local logger = require('lumos.logger')
local app = lumos.new_app({
    name = "table_paging_demo",
    version = require("lumos").version,
    description = "Demonstrates table pagination with rendered tables"
})

local PAGE_SIZE = 10

local function build_rows()
    local rows = {}
    for i = 1, 25 do
        table.insert(rows, {
            ID = i,
            Name = "Item " .. i,
            Status = i % 2 == 0 and "Active" or "Pending"
        })
    end
    return rows
end

app:command("demo", "Run the pagination demo")
    :flag_int("--page", "Display a specific page only", 1, 3)
    :action(function(ctx)
        local rows = build_rows()
        local requested_page = ctx.flags.page or 0

        if requested_page and requested_page > 0 then
            local result = tbl.page(rows, requested_page, PAGE_SIZE)
            print(color.bold("Page " .. result.page .. "/" .. result.total_pages))
            print()
            print(tbl.create(result.data, { headers = { "ID", "Name", "Status" } }))
            print()

            local info = {
                { Field = "Total rows", Value = tostring(result.total_rows) },
                { Field = "Page size", Value = tostring(result.page_size) },
                { Field = "Has next", Value = tostring(result.has_next) },
                { Field = "Has prev", Value = tostring(result.has_prev) },
            }
            print(tbl.create(info, { headers = { "Field", "Value" } }))
            return true
        end

        -- Default: show all pages
        local pages = tbl.paginate(rows, PAGE_SIZE)
        print(color.bold("Total pages: " .. #pages))
        print()

        for i, page in ipairs(pages) do
            print(color.cyan("Page " .. i .. ":"))
            print(tbl.create(page, { headers = { "ID", "Name", "Status" } }))
            print()
        end

        local result = tbl.page(rows, 2, PAGE_SIZE)
        print(color.bold("Page info:"))
        local info = {
            { Field = "Current page", Value = result.page .. "/" .. result.total_pages },
            { Field = "Total rows", Value = tostring(result.total_rows) },
            { Field = "Page size", Value = tostring(result.page_size) },
            { Field = "Has next", Value = tostring(result.has_next) },
            { Field = "Has prev", Value = tostring(result.has_prev) },
        }
        print(tbl.create(info, { headers = { "Field", "Value" } }))

        return true
    end)

os.exit(app:run(arg))
