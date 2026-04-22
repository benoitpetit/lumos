-- Lumos YAML Module
-- Minimal YAML parser for configuration files.
-- Supports: scalars, sequences (arrays), mappings (objects),
-- booleans, null, numbers, and quoted strings.

local yaml = {}

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function parse_scalar(value)
    value = trim(value)
    if value == "" or value == "~" or value == "null" or value == "Null" or value == "NULL" then
        return nil
    end
    if value == "true" or value == "True" or value == "TRUE" then
        return true
    end
    if value == "false" or value == "False" or value == "FALSE" then
        return false
    end
    -- Number
    local num = tonumber(value)
    if num then
        return num
    end
    -- Quoted string
    local quoted = value:match('^"(.*)"$') or value:match("^'(.*)'$")
    if quoted then
        return quoted
    end
    -- Unquoted string
    return value
end

local function count_indent(line)
    local spaces = line:match("^( *)")
    return #spaces
end

local function unescape_double_quoted(s)
    return s:gsub('\\(.)', function(c)
        if c == 'n' then return '\n'
        elseif c == 't' then return '\t'
        elseif c == 'r' then return '\r'
        elseif c == 'b' then return '\b'
        elseif c == 'f' then return '\f'
        elseif c == '\\' then return '\\'
        elseif c == '"' then return '"'
        else return c end
    end)
end

-- Tokenize lines into a flat structure we can parse
local function tokenize(content)
    local lines = {}
    -- Use a pattern that captures the line content including empty lines
    for line in content:gmatch("([^\r\n]*)\r?\n") do
        table.insert(lines, line)
    end
    -- Capture the last line if it doesn't end with a newline
    local last = content:match("[^\r\n]+$")
    if last then
        -- Only insert if it wasn't already captured (content didn't end with newline)
        local ends_with_newline = content:sub(-1) == "\n" or content:sub(-1) == "\r"
        if not ends_with_newline then
            table.insert(lines, last)
        end
    end
    return lines
end

-- Check if line is a comment-only or empty line
local function is_blank_or_comment(line)
    return trim(line) == "" or trim(line):match("^#")
end

-- Extract tag, anchor, and content from a scalar string
local function extract_metadata(s)
    local tag, anchor, alias, content
    -- Tag
    content = s
    local t = content:match("^!(%S+)%s+")
    if t then
        tag = t
        content = content:sub(#t + 3)
    end
    -- Anchor (with trailing space or end of string)
    local a = content:match("^&(%S+)%s+") or content:match("^&(%S+)$")
    if a then
        anchor = a
        local with_space = content:match("^&" .. a .. "%s+")
        if with_space then
            content = content:sub(#a + 3)
        else
            content = content:sub(#a + 2)
        end
    end
    -- Alias
    local al = content:match("^%*(%S+)$")
    if al then
        alias = al
    end
    return tag, anchor, alias, content
end

-- Deep copy a value (for alias resolution)
local function deep_copy(obj)
    if type(obj) ~= "table" then return obj end
    local copy = {}
    for k, v in pairs(obj) do
        copy[k] = deep_copy(v)
    end
    return copy
end

-- Internal recursive parser (no anchor storage)
local function _parse_value_impl(lines, idx, base_indent, anchors)
    anchors = anchors or {}
    local line = lines[idx]
    if not line then return nil, idx end

    local trimmed = trim(line)

    -- Extract metadata (tag, anchor, alias) from the trimmed line
    local tag, anchor_name, alias, content = extract_metadata(trimmed)
    if alias then
        local resolved = anchors[alias]
        if resolved == nil then
            error("Unknown alias: *" .. alias)
        end
        return deep_copy(resolved), idx + 1
    end
    -- Re-assign trimmed to content (without tag/anchor prefix) for further parsing
    if content and content ~= trimmed then
        trimmed = content
    end

    -- Handle multi-line block scalars | (literal) and > (folded)
    local block_match = trimmed:match("^(.-)%s*([|>])([+-]?)(%d*)$")
    if block_match then
        local prefix, block_type, chomp, indent_hint = block_match, trimmed:match("^(.-)%s*([|>])([+-]?)(%d*)$")
        -- Need more robust matching
        local block_pattern = "^(.-)%s*([|>])([+-]?)(%d*)$"
        local prefix_text, btype, bchomp, hind = trimmed:match(block_pattern)
        if prefix_text and btype then
            -- Determine the actual block content indentation from the first non-empty line
            local block_lines = {}
            idx = idx + 1
            local content_indent = nil
            if hind and hind ~= "" then
                content_indent = base_indent + tonumber(hind)
            end
            while idx <= #lines do
                local next_line = lines[idx]
                local next_trimmed = trim(next_line)
                if next_trimmed == "" or next_trimmed:match("^#") then
                    -- blank/comment inside block: keep if literal, skip if folded? Keep for literal
                    if btype == "|" then
                        table.insert(block_lines, "")
                    end
                    idx = idx + 1
                else
                    local next_indent = count_indent(next_line)
                    if content_indent == nil then
                        content_indent = next_indent
                    end
                    if next_indent < content_indent then
                        break
                    end
                    local content = next_line:sub(content_indent + 1)
                    table.insert(block_lines, content)
                    idx = idx + 1
                end
            end
            local result
            if btype == "|" then
                result = table.concat(block_lines, "\n")
            else -- folded
                local folded = {}
                local current_para = {}
                for _, bl in ipairs(block_lines) do
                    if bl == "" then
                        if #current_para > 0 then
                            table.insert(folded, table.concat(current_para, " "))
                            current_para = {}
                        end
                        table.insert(folded, "")
                    else
                        table.insert(current_para, bl)
                    end
                end
                if #current_para > 0 then
                    table.insert(folded, table.concat(current_para, " "))
                end
                result = table.concat(folded, "\n")
            end
            -- Chomp handling: strip trailing newline
            if bchomp == "-" then
                result = result:gsub("\n+$", "")
            elseif bchomp == "+" then
                -- keep all
            else
                -- clip: keep one trailing newline if present
                result = result:gsub("\n+$", "\n")
            end
            if anchor_name then anchors[anchor_name] = result end
            return result, idx
        end
    end

    -- Sequence (array) entry at this indent
    if trimmed:match("^%-%s") or trimmed == "-" then
        local arr = {}
        while idx <= #lines do
            local curr_line = lines[idx]
            local curr_trimmed = trim(curr_line)
            if is_blank_or_comment(curr_line) then
                idx = idx + 1
            else
                local curr_indent = count_indent(curr_line)
                if curr_indent < base_indent then
                    break
                end
                if curr_trimmed:match("^%-%s") or curr_trimmed == "-" then
                    local dash_indent = count_indent(curr_line)
                    -- Value can be inline after dash, or indented below
                    local after_dash = curr_trimmed:match("^%-%s*(.*)$")
                    if after_dash and after_dash ~= "" then
                        -- inline value or inline mapping
                        if after_dash:match("^%{") then
                            -- inline object
                            local obj, next_idx = _parse_value_impl({after_dash}, 1, 0, anchors)
                            table.insert(arr, obj)
                            idx = idx + 1
                        elseif after_dash:match("^%[") then
                            local obj, next_idx = _parse_value_impl({after_dash}, 1, 0, anchors)
                            table.insert(arr, obj)
                            idx = idx + 1
                        else
                            -- Check if it's a key: value pair (mapping within sequence)
                            if after_dash:match("^([^:]+):%s") or after_dash:match("^([^:]+):$") then
                                -- It's a mapping, need to parse subsequent lines with same indent
                                local map = {}
                                local key, rest = after_dash:match("^([^:]+):%s*(.*)$")
                                if rest and rest ~= "" then
                                    map[key] = _parse_value_impl({rest}, 1, 0, anchors)
                                else
                                    map[key] = nil
                                end
                                idx = idx + 1
                                -- Look for more keys at the same indent level as the dash + 2
                                local child_base = dash_indent + 2
                                while idx <= #lines do
                                    local nl = lines[idx]
                                    if is_blank_or_comment(nl) then
                                        idx = idx + 1
                                    else
                                        local ni = count_indent(nl)
                                        if ni < child_base then
                                            break
                                        end
                                        local nt = trim(nl)
                                        if nt:match("^([^:]+):%s") or nt:match("^([^:]+):$") then
                                            local k, v = nt:match("^([^:]+):%s*(.*)$")
                                            if v and v ~= "" then
                                                map[k] = parse_scalar(v)
                                            else
                                                -- Need to parse nested value
                                                local nested_val, next_i = _parse_value_impl(lines, idx + 1, ni + 2, anchors)
                                                if nested_val == nil and next_i == idx + 1 then
                                                    -- No nested value found
                                                    map[k] = nil
                                                    idx = idx + 1
                                                else
                                                    map[k] = nested_val
                                                    idx = next_i
                                                end
                                            end
                                        else
                                            break
                                        end
                                    end
                                end
                                table.insert(arr, map)
                            else
                                table.insert(arr, parse_scalar(after_dash))
                                idx = idx + 1
                            end
                        end
                    else
                        -- value on next lines
                        idx = idx + 1
                        local val, next_i = _parse_value_impl(lines, idx, dash_indent + 2, anchors)
                        if val == nil and next_i == idx then
                            table.insert(arr, nil)
                        else
                            table.insert(arr, val)
                            idx = next_i
                        end
                    end
                else
                    break
                end
            end
        end
        if anchor_name then anchors[anchor_name] = arr end
        return arr, idx
    end

    -- Inline sequence [ ... ]
    if trimmed:match("^%[") then
        local content = trimmed:match("^%[(.*)%]$")
        if not content then
            return trimmed, idx + 1
        end
        local arr = {}
        -- Simple CSV-like parsing
        local current = ""
        local depth = 0
        for i = 1, #content do
            local c = content:sub(i, i)
            if c == "[" then
                depth = depth + 1
                current = current .. c
            elseif c == "]" then
                depth = depth - 1
                current = current .. c
            elseif c == "," and depth == 0 then
                table.insert(arr, parse_scalar(current))
                current = ""
            else
                current = current .. c
            end
        end
        if trim(current) ~= "" then
            table.insert(arr, parse_scalar(current))
        end
        if anchor_name then anchors[anchor_name] = arr end
        return arr, idx + 1
    end

    -- Inline mapping { ... }
    if trimmed:match("^%{") then
        local content = trimmed:match("^%{(.*)%}$")
        if not content then
            return trimmed, idx + 1
        end
        local obj = {}
        local current = ""
        local depth = 0
        local parts = {}
        for i = 1, #content do
            local c = content:sub(i, i)
            if c == "{" then
                depth = depth + 1
                current = current .. c
            elseif c == "}" then
                depth = depth - 1
                current = current .. c
            elseif c == "," and depth == 0 then
                table.insert(parts, current)
                current = ""
            else
                current = current .. c
            end
        end
        if trim(current) ~= "" then
            table.insert(parts, current)
        end
        for _, part in ipairs(parts) do
            local k, v = part:match("^%s*['\"]?(.-)['\"]?%s*:%s*(.*)$")
            if k then
                obj[k] = parse_scalar(trim(v))
            end
        end
        if anchor_name then anchors[anchor_name] = obj end
        return obj, idx + 1
    end

    -- Mapping (object)
    if trimmed:match("^([^:]+):%s") or trimmed:match("^([^:]+):$") then
        local obj = {}
        while idx <= #lines do
            local curr_line = lines[idx]
            if is_blank_or_comment(curr_line) then
                idx = idx + 1
            else
                local curr_indent = count_indent(curr_line)
                if curr_indent < base_indent then
                    break
                end
                local curr_trimmed = trim(curr_line)
                local key, rest = curr_trimmed:match("^([^:]+):%s*(.*)$")
                if key then
                    if rest and rest ~= "" then
                        -- Check if rest is only an anchor (value continues on next lines)
                        local rtag, ranchor, ralias, rcontent = extract_metadata(rest)
                        local inline_val
                        if ranchor and (not rcontent or trim(rcontent) == "") then
                            -- Anchor-only: value is on subsequent lines
                            idx = idx + 1
                            local val, next_i = _parse_value_impl(lines, idx, curr_indent + 2, anchors)
                            if val == nil and next_i == idx then
                                inline_val = nil
                            else
                                inline_val = val
                                idx = next_i
                            end
                            if ranchor then anchors[ranchor] = inline_val end
                        else
                            inline_val = _parse_value_impl({rest}, 1, 0, anchors)
                            idx = idx + 1
                        end
                        obj[key] = inline_val
                    else
                        idx = idx + 1
                        local val, next_i = _parse_value_impl(lines, idx, curr_indent + 2, anchors)
                        if val == nil and next_i == idx then
                            obj[key] = nil
                        else
                            obj[key] = val
                            idx = next_i
                        end
                    end
                else
                    break
                end
            end
        end
        if anchor_name then anchors[anchor_name] = obj end
        return obj, idx
    end

    -- Plain scalar
    local result = parse_scalar(trimmed)
    if anchor_name then anchors[anchor_name] = result end
    return result, idx + 1
end

-- Public internal parser that handles anchors
local function parse_value(lines, idx, base_indent, anchors)
    return _parse_value_impl(lines, idx, base_indent, anchors)
end

function yaml.decode(content)
    if type(content) ~= "string" then
        error("yaml.decode expects a string, got " .. type(content))
    end
    content = content:gsub("^%s+", ""):gsub("%s+$", "")
    if content == "" then
        error("yaml.decode cannot parse empty string")
    end

    local lines = tokenize(content)
    local result, idx = parse_value(lines, 1, 0)
    return result
end

function yaml.encode(obj, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    local t = type(obj)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return obj and "true" or "false"
    elseif t == "number" then
        return tostring(obj)
    elseif t == "string" then
        -- Check if needs quoting
        if obj:match("^[%s#%[%{\"'%:!@]") or obj:match("[%s#:]$") or obj == "" then
            return '"' .. obj:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
        end
        return obj
    elseif t == "table" then
        local is_array = true
        local max_index = 0
        for k, _ in pairs(obj) do
            if type(k) ~= "number" or k <= 0 or k ~= math.floor(k) then
                is_array = false
                break
            end
            max_index = math.max(max_index, k)
        end
        if is_array and max_index > 0 then
            local lines = {}
            for i = 1, max_index do
                local v = yaml.encode(obj[i], indent + 1)
                if type(obj[i]) == "table" then
                    table.insert(lines, prefix .. "- " .. v:gsub("^%s+", ""))
                else
                    table.insert(lines, prefix .. "- " .. v)
                end
            end
            return table.concat(lines, "\n")
        else
            local lines = {}
            for k, v in pairs(obj) do
                local key = tostring(k)
                if key:match("[%s:#\"']") then
                    key = '"' .. key:gsub('"', '\\"') .. '"'
                end
                local val = yaml.encode(v, indent + 1)
                if type(v) == "table" then
                    table.insert(lines, prefix .. key .. ":")
                    table.insert(lines, val)
                else
                    table.insert(lines, prefix .. key .. ": " .. val)
                end
            end
            return table.concat(lines, "\n")
        end
    end
    return tostring(obj)
end

return yaml
