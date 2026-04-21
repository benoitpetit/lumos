-- Lumos Flags Module
local flags = {}

-- Safe require for lfs (used by path validator)
local lfs
local function get_lfs()
    if lfs == nil then
        local ok, mod = pcall(require, "lfs")
        lfs = ok and mod or false
    end
    return lfs
end

-- Platform helpers (minimal inline to avoid circular deps)
local PATH_SEP = package.config:sub(1, 1)
local IS_WINDOWS = PATH_SEP == "\\"

-- Trim whitespace
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Basic type validators (legacy compatibility)
local validators = {
    int = function(value)
        local num = tonumber(value)
        return num ~= nil and math.floor(num) == num, "must be an integer"
    end,

    number = function(value)
        local num = tonumber(value)
        return num ~= nil, "must be a number"
    end,

    email = function(value)
        local pattern = "^[A-Za-z0-9%.%+_%%-]+@[A-Za-z0-9%%-]+%.[A-Za-z]+"
        return value:match(pattern) ~= nil, "must be a valid email"
    end,

    url = function(value)
        local pattern = "^https?://[%w%.%-]+[%w%.%-/]*$"
        return value:match(pattern) ~= nil, "must be a valid URL"
    end,

    path = function(value)
        return value and value ~= "", "must be a valid path"
    end
}

-- Validate flag value based on type and constraints
function flags.validate_flag(flag_def, value)
    if not flag_def then
        return true, value
    end

    -- Required validation (early)
    if flag_def.required and (value == nil or value == "") then
        return false, "is required"
    end

    -- Skip further validation if value is nil and not required
    if value == nil then
        return true, value
    end

    -- Boolean passthrough (no explicit type or boolean type)
    if type(value) == "boolean" and (not flag_def.type or flag_def.type == "boolean") then
        return true, value
    end

    local flag_type = flag_def.type or "string"

    -- === FLOAT ===
    if flag_type == "float" then
        local num = tonumber(value)
        if num == nil then
            return false, "must be a number"
        end
        if flag_def.min and num < flag_def.min then
            return false, "must be >= " .. flag_def.min
        end
        if flag_def.max and num > flag_def.max then
            return false, "must be <= " .. flag_def.max
        end
        if flag_def.precision then
            local mult = 10 ^ flag_def.precision
            num = math.floor(num * mult + 0.5) / mult
        end
        return true, num
    end

    -- === ARRAY ===
    if flag_type == "array" then
        if type(value) == "table" then
            -- Already parsed (e.g. from config or env)
            return true, value
        end
        local str = tostring(value)
        local separator = flag_def.separator or ","
        local items = {}
        for item in str:gmatch("([^" .. separator .. "]+)") do
            item = trim(item)
            local parsed
            local item_type = flag_def.item_type or "string"
            if item_type == "string" then
                parsed = item
            elseif item_type == "int" then
                parsed = tonumber(item)
                if not parsed or parsed ~= math.floor(parsed) then
                    return false, "array item must be an integer: " .. item
                end
            elseif item_type == "float" then
                parsed = tonumber(item)
                if not parsed then
                    return false, "array item must be a number: " .. item
                end
            else
                parsed = item
            end
            table.insert(items, parsed)
        end
        if flag_def.min_items and #items < flag_def.min_items then
            return false, "must have at least " .. flag_def.min_items .. " items"
        end
        if flag_def.max_items and #items > flag_def.max_items then
            return false, "must have at most " .. flag_def.max_items .. " items"
        end
        if flag_def.unique then
            local seen = {}
            for _, item in ipairs(items) do
                if seen[item] then
                    return false, "duplicate item not allowed: " .. tostring(item)
                end
                seen[item] = true
            end
        end
        return true, items
    end

    -- === ENUM ===
    if flag_type == "enum" then
        local str = tostring(value)
        local choices = flag_def.choices or {}
        local case_sensitive = flag_def.case_sensitive or false
        local compare = case_sensitive and str or str:lower()
        for _, choice in ipairs(choices) do
            local c = case_sensitive and choice or choice:lower()
            if compare == c then
                return true, choice -- return original casing
            end
        end
        return false, "must be one of: " .. table.concat(choices, ", ")
    end

    -- === PATH (enriched) ===
    if flag_type == "path" then
        if value == "" then
            return false, "must be a valid path"
        end
        local path_val = tostring(value)
        if flag_def.resolve then
            local l = get_lfs()
            if l then
                path_val = l.currentdir() .. "/" .. path_val
            end
        end
        if flag_def.absolute then
            if not IS_WINDOWS then
                if path_val:sub(1, 1) ~= "/" then
                    local l = get_lfs()
                    if l then
                        path_val = l.currentdir() .. "/" .. path_val
                    end
                end
            else
                if not path_val:match("^%a:[/\\]") then
                    local l = get_lfs()
                    if l then
                        path_val = l.currentdir() .. "\\" .. path_val
                    end
                end
            end
        end
        if flag_def.must_exist then
            local l = get_lfs()
            if not l then
                return false, "cannot verify path existence (lfs not available)"
            end
            local attr = l.attributes(path_val)
            if not attr then
                return false, "path does not exist: " .. path_val
            end
            if attr.mode == "file" and flag_def.allow_file == false then
                return false, "file not allowed (directory expected)"
            end
            if attr.mode == "directory" and flag_def.allow_dir == false then
                return false, "directory not allowed (file expected)"
            end
            if flag_def.extensions and attr.mode == "file" then
                local ext = path_val:match("%.([^%.]+)$")
                local valid = false
                if ext then
                    ext = ext:lower()
                    for _, allowed in ipairs(flag_def.extensions) do
                        local normalized = tostring(allowed or "")
                        if normalized:sub(1, 1) == "." then
                            normalized = normalized:sub(2)
                        end
                        if normalized:lower() == ext then
                            valid = true
                            break
                        end
                    end
                end
                if not valid then
                    return false, "invalid extension. Expected: " .. table.concat(flag_def.extensions, ", ")
                end
            end
        end
        return true, path_val
    end

    -- === URL (enriched) ===
    if flag_type == "url" then
        local str = tostring(value)
        -- Lua patterns do not support optional captures. Use sequential matching.

        local scheme, rest = str:match("^([%a][%a%d+.-]*)://(.*)$")

        if not scheme or not rest or rest == "" then

            return false, "must be a valid URL"

        end

        -- Extract host, optional port, optional path

        local host, port, path_part

        host, port, path_part = rest:match("^([^/:]+):(%d+)(/.*)$")

        if not host then

            host, path_part = rest:match("^([^/:]+)(/.*)$")

        end

        if not host then

            host = rest:match("^([^/:]+)$")

        end

        if not host then

            return false, "must be a valid URL"

        end
        local schemes = flag_def.schemes or {"http", "https"}
        local valid_scheme = false
        for _, s in ipairs(schemes) do
            if scheme:lower() == s:lower() then
                valid_scheme = true
                break
            end
        end
        if not valid_scheme then
            return false, "invalid URL scheme. Expected: " .. table.concat(schemes, ", ")
        end
        if flag_def.require_host ~= false and not host then
            return false, "URL host is required"
        end
        if flag_def.require_path and not path_part then
            return false, "URL path is required"
        end
        if flag_def.allow_localhost == false and host then
            local h = host:lower()
            if h == "localhost" or h == "127.0.0.1" or h == "::1" then
                return false, "localhost is not allowed"
            end
        end
        return true, str
    end

    -- === EMAIL (enriched) ===
    if flag_type == "email" then
        local str = tostring(value)
        local pattern = flag_def.pattern or "^[A-Za-z0-9%.%+_%%-]+@[A-Za-z0-9%%-]+%.[A-Za-z]+"
        if not str:match(pattern) then
            return false, "must be a valid email"
        end
        return true, str
    end

    -- === STRING (with enrichments) ===
    if flag_type == "string" then
        local str = tostring(value)
        if flag_def.choices then
            local valid = false
            for _, choice in ipairs(flag_def.choices) do
                if str == choice then
                    valid = true
                    break
                end
            end
            if not valid then
                return false, "must be one of: " .. table.concat(flag_def.choices, ", ")
            end
        end
        if flag_def.min_length and #str < flag_def.min_length then
            return false, "must be at least " .. flag_def.min_length .. " characters"
        end
        if flag_def.max_length and #str > flag_def.max_length then
            return false, "must be at most " .. flag_def.max_length .. " characters"
        end
        if flag_def.pattern and not str:match(flag_def.pattern) then
            return false, "format is invalid"
        end
        return true, str
    end

    -- Legacy validators for int, number
    if flag_def.type and validators[flag_def.type] then
        local valid, error_msg = validators[flag_def.type](value)
        if not valid then
            return false, error_msg
        end
        if flag_def.type == "int" or flag_def.type == "number" then
            value = tonumber(value)
        end
    end

    -- Range validation (legacy numeric types)
    if flag_def.type == "int" or flag_def.type == "number" then
        if flag_def.min and value < flag_def.min then
            return false, "must be >= " .. flag_def.min
        end
        if flag_def.max and value > flag_def.max then
            return false, "must be <= " .. flag_def.max
        end
    end

    return true, value
end

-- Parse a single flag and return its name, value, and index
function flags.parse_single_flag(arg, args, start_index)
    local name, value
    local next_index = start_index + 1

    if arg:sub(1, 2) == "--" then
        -- Long flag
        name = arg:sub(3)
        local eq_pos = name:find("=")
        if eq_pos then
            value = name:sub(eq_pos + 1)
            name = name:sub(1, eq_pos - 1)
        elseif next_index <= #args and not args[next_index]:match("^%-%-?[%a_]") then
            -- Next token is a value; negative numbers (e.g. -5) are values, not flags
            value = args[next_index]
            next_index = next_index + 1
        else
            value = true  -- Boolean flag
        end
        -- Normalize hyphens to underscores so --dry-run → ctx.flags.dry_run
        name = name:gsub("-", "_")
    elseif arg:sub(1, 1) == "-" then
        -- Short flag
        name = arg:sub(2, 2)
        if #arg > 2 then
            value = arg:sub(3)
        elseif next_index <= #args and not args[next_index]:match("^%-%-?[%a_]") then
            -- Next token is a value; negative numbers (e.g. -5) are values, not flags
            value = args[next_index]
            next_index = next_index + 1
        else
            value = true
        end
    end

    return {name = name, value = value, next_index = next_index}
end

return flags
