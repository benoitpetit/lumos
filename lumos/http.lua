-- Lumos HTTP Module
-- Lightweight HTTP client using curl (with optional LuaSocket fallback).
-- No extra dependencies required: curl is used as the default backend.

local http = {}

local json = require("lumos.json")

-- Internal executor; exposed for testability
http._exec = function(cmd)
    local handle, err = io.popen(cmd, "r")
    if not handle then
        return nil, "failed to execute curl: " .. tostring(err)
    end
    local output = handle:read("*a")
    handle:close()
    return output
end

-- Escape a string for safe use inside single-quoted shell arguments
local function shell_escape(str)
    -- Use single quotes and escape any embedded single quotes
    -- by ending the quote, adding an escaped quote, then restarting
    return "'" .. tostring(str):gsub("'", "'\"'\"'") .. "'"
end

-- Build URL with query parameters
local function build_url(base, query)
    if not query then
        return base
    end
    local parts = {}
    for k, v in pairs(query) do
        -- Simple percent-encoding for common characters
        local enc_k = tostring(k):gsub("([^%w%-%.%_~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        local enc_v = tostring(v):gsub("([^%w%-%.%_~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        table.insert(parts, enc_k .. "=" .. enc_v)
    end
    if #parts == 0 then
        return base
    end
    local sep = base:match("%?") and "&" or "?"
    return base .. sep .. table.concat(parts, "&")
end

-- Parse curl -D headers file content
local function parse_headers(raw)
    local headers = {}
    if not raw then
        return headers
    end
    for line in (raw .. "\n"):gmatch("(.-)\n") do
        local key, value = line:match("^([^:]+):%s*(.+)$")
        if key and value then
            headers[key:lower()] = value
        end
    end
    return headers
end

-- Parse status line from headers file
local function parse_status(raw)
    if not raw then
        return nil
    end
    for line in (raw .. "\n"):gmatch("(.-)\n") do
        local status = line:match("^HTTP/%d%.%d%s+(%d+)")
        if status then
            return tonumber(status)
        end
        -- HTTP/2 status line
        status = line:match("^HTTP/2%s+(%d+)")
        if status then
            return tonumber(status)
        end
    end
    return nil
end

-- ============================================================
-- Core request function
-- ============================================================

--- Perform an HTTP request.
-- @param opts (table)
--   - url     (string)  : request URL (required)
--   - method  (string)  : HTTP method (default: "GET")
--   - headers (table)   : key-value headers
--   - query   (table)   : query parameters
--   - body    (string|table): request body; tables are JSON-encoded when opts.json ~= false
--   - json    (boolean) : auto encode/decode JSON (default: true when body is a table)
--   - timeout (number)  : request timeout in seconds
--   - auth    (table)   : {bearer=token} or {user=..., pass=...}
--   - follow_redirects (boolean): follow 3xx redirects (default: true)
--   - insecure(boolean): skip SSL verification (default: false)
-- @return response table {status, body, headers, ok, json()} or nil, error
function http.request(opts)
    opts = opts or {}
    local url = opts.url
    if not url or url == "" then
        return nil, "URL is required"
    end

    url = build_url(url, opts.query)

    local headers_file = os.tmpname()
    local body_file = os.tmpname()

    local parts = {
        "curl",
        "-s",                       -- silent
        "-D", shell_escape(headers_file), -- dump headers
        "-o", shell_escape(body_file),    -- output body
        "-w", shell_escape("%{http_code}"), -- write status code to stdout
    }

    -- Method
    local method = (opts.method or "GET"):upper()
    table.insert(parts, "-X")
    table.insert(parts, method)

    -- Redirects
    if opts.follow_redirects == false then
        table.insert(parts, "--max-redirs")
        table.insert(parts, "0")
    else
        table.insert(parts, "-L")
    end

    -- Insecure
    if opts.insecure then
        table.insert(parts, "-k")
    end

    -- Timeout
    if opts.timeout and opts.timeout > 0 then
        table.insert(parts, "--connect-timeout")
        table.insert(parts, tostring(opts.timeout))
        table.insert(parts, "--max-time")
        table.insert(parts, tostring(opts.timeout))
    end

    -- Auth
    if opts.auth then
        if opts.auth.bearer then
            table.insert(parts, "-H")
            table.insert(parts, shell_escape("Authorization: Bearer " .. opts.auth.bearer))
        elseif opts.auth.user then
            local pass = opts.auth.pass or ""
            table.insert(parts, "-u")
            table.insert(parts, shell_escape(opts.auth.user .. ":" .. pass))
        end
    end

    -- Headers
    local req_headers = opts.headers or {}
    for k, v in pairs(req_headers) do
        table.insert(parts, "-H")
        table.insert(parts, shell_escape(tostring(k) .. ": " .. tostring(v)))
    end

    -- Body
    local body_str = nil
    if opts.body ~= nil then
        if type(opts.body) == "table" then
            local encode_json = opts.json
            if encode_json == nil then
                encode_json = true
            end
            if encode_json then
                body_str = json.encode(opts.body)
                -- Ensure Content-Type if not already set
                local has_ct = false
                for k, _ in pairs(req_headers) do
                    if k:lower() == "content-type" then
                        has_ct = true
                        break
                    end
                end
                if not has_ct then
                    table.insert(parts, "-H")
                    table.insert(parts, shell_escape("Content-Type: application/json"))
                end
            else
                body_str = tostring(opts.body)
            end
        else
            body_str = tostring(opts.body)
        end
    end

    if body_str then
        table.insert(parts, "-d")
        table.insert(parts, shell_escape(body_str))
    end

    -- URL last
    table.insert(parts, shell_escape(url))

    local cmd = table.concat(parts, " ")
    local output, err = http._exec(cmd)

    -- Read headers
    local hf, hf_err = io.open(headers_file, "r")
    local raw_headers = ""
    if hf then
        raw_headers = hf:read("*a") or ""
        hf:close()
    end
    os.remove(headers_file)

    -- Read body
    local bf, bf_err = io.open(body_file, "r")
    local body = ""
    if bf then
        body = bf:read("*a") or ""
        bf:close()
    end
    os.remove(body_file)

    if not output then
        return nil, err or "curl execution failed"
    end

    local status = tonumber(output:match("%d+")) or parse_status(raw_headers)
    if not status then
        return nil, "unable to parse HTTP status from curl response"
    end

    local headers = parse_headers(raw_headers)

    local response = {
        status = status,
        body = body,
        headers = headers,
        ok = status >= 200 and status < 300,
    }

    -- Lazy JSON decode helper
    response.json = function()
        if not body or body == "" then
            return nil, "empty body"
        end
        local ok, result = pcall(json.decode, body)
        if ok then
            return result
        else
            return nil, result
        end
    end

    return response
end

-- ============================================================
-- Convenience methods
-- ============================================================

function http.get(url, opts)
    opts = opts or {}
    opts.url = url
    opts.method = "GET"
    return http.request(opts)
end

function http.post(url, opts)
    opts = opts or {}
    opts.url = url
    opts.method = "POST"
    return http.request(opts)
end

function http.put(url, opts)
    opts = opts or {}
    opts.url = url
    opts.method = "PUT"
    return http.request(opts)
end

function http.patch(url, opts)
    opts = opts or {}
    opts.url = url
    opts.method = "PATCH"
    return http.request(opts)
end

function http.delete(url, opts)
    opts = opts or {}
    opts.url = url
    opts.method = "DELETE"
    return http.request(opts)
end

function http.head(url, opts)
    opts = opts or {}
    opts.url = url
    opts.method = "HEAD"
    return http.request(opts)
end

function http.options(url, opts)
    opts = opts or {}
    opts.url = url
    opts.method = "OPTIONS"
    return http.request(opts)
end

return http
