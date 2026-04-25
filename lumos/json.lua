-- Lumos JSON Module
-- JSON encoding and decoding without external dependencies

local json = {}

-- Escape string for JSON
local function escape_string(str)
    -- Escape backslash and double-quote first
    str = str:gsub('\\', '\\\\')
              :gsub('"', '\\"')
    -- Escape all control characters (0x00–0x1F)
    str = str:gsub('%c', function(c)
        local b = string.byte(c)
        if     b ==  8 then return '\\b'
        elseif b ==  9 then return '\\t'
        elseif b == 10 then return '\\n'
        elseif b == 12 then return '\\f'
        elseif b == 13 then return '\\r'
        else return string.format('\\u%04X', b)
        end
    end)
    return str
end

-- Encode table to JSON
function json.encode(obj)
    local function encode_value(val)
        local t = type(val)
        if t == "string" then
            return '"' .. escape_string(val) .. '"'
        elseif t == "number" then
            -- Handle special float values not valid in JSON
            if val ~= val then          -- NaN
                return '"NaN"'
            elseif val == math.huge then
                return '"Infinity"'
            elseif val == -math.huge then
                return '"-Infinity"'
            else
                return tostring(val)
            end
        elseif t == "boolean" then
            return val and "true" or "false"
        elseif t == "nil" then
            return "null"
        elseif t == "table" then
            local is_array = true
            local max_index = 0
            
            -- Check if it's an array
            for k, v in pairs(val) do
                if type(k) ~= "number" or k <= 0 or k ~= math.floor(k) then
                    is_array = false
                    break
                end
                max_index = math.max(max_index, k)
            end
            
            if is_array and max_index > 0 then
                local result = {}
                for i = 1, max_index do
                    table.insert(result, encode_value(val[i]))
                end
                return "[" .. table.concat(result, ",") .. "]"
            else
                local result = {}
                for k, v in pairs(val) do
                    local key = type(k) == "string" and k or tostring(k)
                    table.insert(result, '"' .. escape_string(key) .. '":' .. encode_value(v))
                end
                return "{" .. table.concat(result, ",") .. "}"
            end
        else
            return '"' .. tostring(val) .. '"'
        end
    end
    
    return encode_value(obj)
end

-- ============================================================
-- Robust JSON decoder with tokenizer and recursive parser
-- ============================================================

local function json_tokenize(str)
    local pos = 1
    local len = #str
    local tokens = {}
    
    local function skip_whitespace()
        while pos <= len do
            local c = str:sub(pos, pos)
            if c == " " or c == "\t" or c == "\n" or c == "\r" then
                pos = pos + 1
            else
                break
            end
        end
    end
    
    while pos <= len do
        skip_whitespace()
        if pos > len then break end
        
        local c = str:sub(pos, pos)
        
        -- Single-character tokens
        if c == "{" or c == "}" or c == "[" or c == "]" or c == ":" or c == "," then
            table.insert(tokens, {type = c, value = c})
            pos = pos + 1
        -- String
        elseif c == '"' then
            pos = pos + 1
            local value = {}
            while pos <= len do
                local ch = str:sub(pos, pos)
                if ch == '"' then
                    pos = pos + 1
                    break
                elseif ch == '\\' then
                    pos = pos + 1
                    if pos > len then error("Unexpected end of string in JSON") end
                    local esc = str:sub(pos, pos)
                    if esc == 'n' then table.insert(value, '\n')
                    elseif esc == 't' then table.insert(value, '\t')
                    elseif esc == 'r' then table.insert(value, '\r')
                    elseif esc == 'b' then table.insert(value, '\b')
                    elseif esc == 'f' then table.insert(value, '\f')
                    elseif esc == '\\' then table.insert(value, '\\')
                    elseif esc == '"' then table.insert(value, '"')
                    elseif esc == '/' then table.insert(value, '/')
                    elseif esc == 'u' then
                        -- Unicode escape \uXXXX
                        if pos + 4 > len then error("Invalid unicode escape in JSON") end
                        local hex = str:sub(pos + 1, pos + 4)
                        local code = tonumber(hex, 16)
                        if not code then error("Invalid unicode escape in JSON") end
                        pos = pos + 4
                        if code >= 0xD800 and code <= 0xDBFF then
                            -- Surrogate pair
                            if pos + 6 <= len and str:sub(pos + 1, pos + 2) == "\\u" then
                                local low_hex = str:sub(pos + 3, pos + 6)
                                local low_code = tonumber(low_hex, 16)
                                if low_code and low_code >= 0xDC00 and low_code <= 0xDFFF then
                                    code = 0x10000 + ((code - 0xD800) * 0x400) + (low_code - 0xDC00)
                                    pos = pos + 6
                                end
                            end
                        end
                        -- Basic UTF-8 encoding for Lua 5.3+
                        if code <= 0x7F then
                            table.insert(value, string.char(code))
                        elseif code <= 0x7FF then
                            table.insert(value, string.char(0xC0 + math.floor(code / 64), 0x80 + (code % 64)))
                        elseif code <= 0xFFFF then
                            table.insert(value, string.char(0xE0 + math.floor(code / 4096), 0x80 + (math.floor(code / 64) % 64), 0x80 + (code % 64)))
                        else
                            table.insert(value, string.char(0xF0 + math.floor(code / 262144), 0x80 + (math.floor(code / 4096) % 64), 0x80 + (math.floor(code / 64) % 64), 0x80 + (code % 64)))
                        end
                    else
                        table.insert(value, esc)
                    end
                    pos = pos + 1
                else
                    table.insert(value, ch)
                    pos = pos + 1
                end
            end
            table.insert(tokens, {type = "string", value = table.concat(value)})
        -- Number
        elseif c:match("[%d%-]") then
            local start_pos = pos
            if c == "-" then pos = pos + 1 end
            while pos <= len and str:sub(pos, pos):match("%d") do pos = pos + 1 end
            if pos <= len and str:sub(pos, pos) == "." then
                pos = pos + 1
                while pos <= len and str:sub(pos, pos):match("%d") do pos = pos + 1 end
            end
            if pos <= len and (str:sub(pos, pos) == "e" or str:sub(pos, pos) == "E") then
                pos = pos + 1
                if pos <= len and (str:sub(pos, pos) == "+" or str:sub(pos, pos) == "-") then pos = pos + 1 end
                while pos <= len and str:sub(pos, pos):match("%d") do pos = pos + 1 end
            end
            local num_str = str:sub(start_pos, pos - 1)
            local num = tonumber(num_str)
            if not num then error("Invalid number in JSON: " .. num_str) end
            table.insert(tokens, {type = "number", value = num})
        -- Literals
        elseif str:sub(pos, pos + 3) == "true" then
            table.insert(tokens, {type = "boolean", value = true})
            pos = pos + 4
        elseif str:sub(pos, pos + 4) == "false" then
            table.insert(tokens, {type = "boolean", value = false})
            pos = pos + 5
        elseif str:sub(pos, pos + 3) == "null" then
            table.insert(tokens, {type = "null", value = nil})
            pos = pos + 4
        else
            error("Invalid JSON at position " .. pos .. ": " .. str:sub(pos, pos + 10))
        end
    end
    
    return tokens
end

local function json_parse(tokens, index)
    index = index or 1
    local token = tokens[index]
    if not token then error("Unexpected end of JSON") end
    
    if token.type == "null" then
        return nil, index + 1
    elseif token.type == "boolean" or token.type == "number" or token.type == "string" then
        return token.value, index + 1
    elseif token.type == "[" then
        local arr = {}
        index = index + 1
        if tokens[index] and tokens[index].type == "]" then
            return arr, index + 1
        end
        while true do
            local value, new_index = json_parse(tokens, index)
            table.insert(arr, value)
            index = new_index
            if tokens[index] and tokens[index].type == "]" then
                return arr, index + 1
            elseif tokens[index] and tokens[index].type == "," then
                index = index + 1
            else
                error("Expected ',' or ']' in JSON array")
            end
        end
    elseif token.type == "{" then
        local obj = {}
        index = index + 1
        if tokens[index] and tokens[index].type == "}" then
            return obj, index + 1
        end
        while true do
            if not tokens[index] or tokens[index].type ~= "string" then
                error("Expected string key in JSON object")
            end
            local key = tokens[index].value
            index = index + 1
            if not tokens[index] or tokens[index].type ~= ":" then
                error("Expected ':' after key in JSON object")
            end
            index = index + 1
            local value, new_index = json_parse(tokens, index)
            obj[key] = value
            index = new_index
            if tokens[index] and tokens[index].type == "}" then
                return obj, index + 1
            elseif tokens[index] and tokens[index].type == "," then
                index = index + 1
            else
                error("Expected ',' or '}' in JSON object")
            end
        end
    else
        error("Unexpected token in JSON: " .. token.type)
    end
end

function json.encode_pretty(obj, indent)
    indent = indent or 2
    
    local function encode_value(val, depth)
        local t = type(val)
        if t == "string" then
            return '"' .. escape_string(val) .. '"'
        elseif t == "number" then
            if val ~= val then
                return '"NaN"'
            elseif val == math.huge then
                return '"Infinity"'
            elseif val == -math.huge then
                return '"-Infinity"'
            else
                return tostring(val)
            end
        elseif t == "boolean" then
            return val and "true" or "false"
        elseif t == "nil" then
            return "null"
        elseif t == "table" then
            local is_array = true
            local max_index = 0
            for k, v in pairs(val) do
                if type(k) ~= "number" or k <= 0 or k ~= math.floor(k) then
                    is_array = false
                    break
                end
                max_index = math.max(max_index, k)
            end
            
            local spaces = string.rep(" ", depth * indent)
            local inner_spaces = string.rep(" ", (depth + 1) * indent)
            
            if is_array and max_index > 0 then
                local result = {}
                for i = 1, max_index do
                    table.insert(result, inner_spaces .. encode_value(val[i], depth + 1))
                end
                return "[\n" .. table.concat(result, ",\n") .. "\n" .. spaces .. "]"
            else
                local result = {}
                for k, v in pairs(val) do
                    local key = type(k) == "string" and k or tostring(k)
                    table.insert(result, inner_spaces .. '"' .. escape_string(key) .. '": ' .. encode_value(v, depth + 1))
                end
                if #result == 0 then
                    return "{}"
                end
                return "{\n" .. table.concat(result, ",\n") .. "\n" .. spaces .. "}"
            end
        else
            return '"' .. tostring(val) .. '"'
        end
    end
    
    return encode_value(obj, 0)
end

function json.decode(str)
    if type(str) ~= "string" then
        error("json.decode expects a string, got " .. type(str))
    end
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    if str == "" then
        error("json.decode cannot parse empty string")
    end
    local tokens = json_tokenize(str)
    local result, next_index = json_parse(tokens, 1)
    if next_index <= #tokens then
        error("Unexpected trailing data in JSON")
    end
    return result
end

return json
