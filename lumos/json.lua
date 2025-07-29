-- Lumos JSON Module
-- Simple JSON encoding without external dependencies

local json = {}

-- Escape string for JSON
local function escape_string(str)
    return str:gsub('\\', '\\\\')
              :gsub('"', '\\"')
              :gsub('\n', '\\n')
              :gsub('\r', '\\r')
              :gsub('\t', '\\t')
end

-- Encode table to JSON
function json.encode(obj)
    local function encode_value(val)
        local t = type(val)
        if t == "string" then
            return '"' .. escape_string(val) .. '"'
        elseif t == "number" then
            return tostring(val)
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

return json
