-- Lumos TOML Parser Module
-- Minimal TOML parser supporting nested tables, inline tables, arrays,
-- strings, numbers, and booleans.

local toml = {}

function toml.parse(content)
    local result = {}
    local section = nil       -- current dotted section path (string)
    local section_type = nil  -- "table" or "array"

    -- Helper: split a dotted path into parts
    local function split_path(path)
        local parts = {}
        for part in path:gmatch("[^.]+") do
            table.insert(parts, part)
        end
        return parts
    end

    -- Helper: ensure nested tables exist and return the deepest table + last key
    local function ensure_table(root, parts)
        local current = root
        for i = 1, #parts - 1 do
            local part = parts[i]
            if type(current[part]) ~= "table" then
                current[part] = {}
            end
            current = current[part]
        end
        return current, parts[#parts]
    end

    -- Helper: parse a TOML value (scalar, array, inline table)
    local function parse_value(val)
        val = val:match("^%s*(.-)%s*$")
        if val == "" then return nil end

        -- Inline table
        if val:match("^%{") then
            local obj = {}
            local inner = val:match("^%{(.*)%}$")
            if inner then
                inner = inner:match("^%s*(.-)%s*$")
                -- Simple split by comma at top level
                local depth = 0
                local current = ""
                local kv_pairs = {}
                for i = 1, #inner do
                    local c = inner:sub(i, i)
                    if c == "{" then
                        depth = depth + 1
                        current = current .. c
                    elseif c == "}" then
                        depth = depth - 1
                        current = current .. c
                    elseif c == "," and depth == 0 then
                        table.insert(kv_pairs, current)
                        current = ""
                    else
                        current = current .. c
                    end
                end
                if current ~= "" then
                    table.insert(kv_pairs, current)
                end
                for _, kv in ipairs(kv_pairs) do
                    local k, v = kv:match("^%s*([%w_%-]+)%s*=%s*(.*)$")
                    if k then
                        obj[k] = parse_value(v)
                    end
                end
            end
            return obj
        end

        -- Array
        if val:match("^%[") then
            local arr = {}
            local inner = val:match("^%[(.*)%]$") or ""
            local depth = 0
            local current = ""
            for i = 1, #inner do
                local c = inner:sub(i, i)
                if c == "[" then
                    depth = depth + 1
                    current = current .. c
                elseif c == "]" then
                    depth = depth - 1
                    current = current .. c
                elseif c == "," and depth == 0 then
                    if current:match("%S") then
                        table.insert(arr, parse_value(current))
                    end
                    current = ""
                else
                    current = current .. c
                end
            end
            if current:match("%S") then
                table.insert(arr, parse_value(current))
            end
            return arr
        end

        -- String
        local str = val:match('^"(.*)"$') or val:match("^'(.*)'$")
        if str then
            return str
        end

        -- Boolean
        local lower = val:lower()
        if lower == "true" then return true end
        if lower == "false" then return false end

        -- Number
        local num = tonumber(val)
        if num then return num end

        -- Raw string
        return val
    end

    -- Helper: set a value in result under current section
    local function set_key(key, value)
        local parts
        if section then
            parts = split_path(section .. "." .. key)
        else
            parts = split_path(key)
        end
        local tbl, last = ensure_table(result, parts)
        tbl[last] = value
    end

    for line in content:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and not line:match("^#") then
            -- Table array [[section]]
            local arr_sec = line:match("^%[%[(.-)%]%]$")
            if arr_sec then
                section = arr_sec:gsub("%s+", "")
                section_type = "array"
                local parts = split_path(section)
                local tbl, last = ensure_table(result, parts)
                if type(tbl[last]) ~= "table" then
                    tbl[last] = {}
                end
                local new_entry = {}
                table.insert(tbl[last], new_entry)
                section_type = "array_entry"
                result._toml_current_array_entry = new_entry
                result._toml_array_entry_depth = #parts
            else
                -- Section header [section] or [section.subsection]
                local sec = line:match("^%[([^%]]+)%]$")
                if sec then
                    section = sec:gsub("%s+", "")
                    section_type = "table"
                    result._toml_current_array_entry = nil
                    -- Ensure the table exists
                    local parts = split_path(section)
                    local tbl, last = ensure_table(result, parts)
                    if type(tbl[last]) ~= "table" then
                        tbl[last] = {}
                    end
                else
                    local key, value = line:match("^([%w_%-]+)%s*=%s*(.*)$")
                    if key and value then
                        -- Trim trailing comment (naive: everything after unquoted #)
                        local val_str = value:match("^(.-)%s*#.*$") or value
                        local parsed = parse_value(val_str)
                        if result._toml_current_array_entry and section_type == "array_entry" then
                            result._toml_current_array_entry[key] = parsed
                        else
                            set_key(key, parsed)
                        end
                    end
                end
            end
        end
    end

    -- Clean up internal markers
    result._toml_current_array_entry = nil
    result._toml_array_entry_depth = nil
    return result
end

return toml
