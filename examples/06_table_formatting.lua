#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")
local tbl = require("lumos.table")

local app = lumos.new_app({
    name = "table_demo",
    version = "1.0.0",
    description = "Table formatting demonstrations"
})

local basic = app:command("basic", "Basic table")

basic:action(function(ctx)
    print(color.bold("=== Basic Table ===\n"))

    local data = {
        {name = "Alice", age = 30, city = "Paris"},
        {name = "Bob", age = 25, city = "London"},
        {name = "Charlie", age = 35, city = "Berlin"}
    }

    print(tbl.create(data, {
        headers = {"name", "age", "city"},
        align = {"left", "right", "left"}
    }))

    return true
end)

local boxed = app:command("boxed", "Boxed list items")

boxed:action(function(ctx)
    print(color.bold("=== Boxed Items ===\n"))

    local items = {
        "First item",
        "Second item",
        "Third item",
        "Fourth item"
    }

    for _, item in ipairs(items) do
        print(tbl.boxed({item}, {align = "center"}))
    end

    return true
end)

local key_value = app:command("kv", "Key-value table")

key_value:action(function(ctx)
    print(color.bold("=== Key-Value Table ===\n"))

    local config = {
        database_host = "localhost",
        database_port = "5432",
        database_name = "production",
        max_connections = "100",
        timeout = "30s"
    }

    print(tbl.key_value(config))
    print()

    print(color.dim("Simple format:"))
    print(tbl.key_value(config, {simple = true}))

    return true
end)

local pagination = app:command("paginate", "Table pagination demo")

pagination:action(function(ctx)
    print(color.bold("=== Pagination Demo ===\n"))

    local all_rows = {}
    for i = 1, 50 do
        table.insert(all_rows, {
            id = i,
            name = string.format("User-%03d", i),
            email = string.format("user%d@example.com", i),
            status = (i % 3 == 0) and "active" or "pending"
        })
    end

    print(color.cyan("Total rows: " .. #all_rows .. "\n"))

    for page_num = 1, 3 do
        local page = tbl.page(all_rows, page_num, 10)

        print(color.bold(string.format("\n--- Page %d/%d ---", page.page, page.total_pages)))

        local page_data = {}
        for _, row in ipairs(page.data) do
            table.insert(page_data, {
                id = row.id,
                name = row.name,
                status = row.status
            })
        end

        print(tbl.create(page_data, {
            headers = {"id", "name", "status"}
        }))

        print(string.format("Showing %d-%d of %d rows\n",
            (page_num - 1) * 10 + 1,
            math.min(page_num * 10, #all_rows),
            #all_rows))
    end

    return true
end)

local align = app:command("align", "Alignment options")

align:action(function(ctx)
    print(color.bold("=== Alignment Options ===\n"))

    local data = {
        {name = "Short", value = 100, ratio = 0.5},
        {name = "Medium length", value = 2000, ratio = 0.75},
        {name = "Much longer name", value = 30000, ratio = 0.99}
    }

    print(color.dim("Left aligned (default):"))
    print(tbl.create(data, {headers = {"name", "value", "ratio"}}))
    print()

    print(color.dim("Center aligned:"))
    print(tbl.create(data, {
        headers = {"name", "value", "ratio"},
        align = {"center", "center", "center"}
    }))
    print()

    print(color.dim("Right aligned numbers:"))
    print(tbl.create(data, {
        headers = {"name", "value", "ratio"},
        align = {"left", "right", "right"}
    }))

    return true
end)

os.exit(app:run(arg))