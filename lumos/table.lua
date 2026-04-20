
-- lumos/table.lua
-- Module to create boxed tables and advanced table formatting in the CLI

local tbl = {}

-- Detect Windows
local function is_windows()
    return package.config:sub(1, 1) == "\\"
end

-- Cross-platform terminal width detection
local function get_terminal_width()
    -- First, try environment variable
    local cols = tonumber(os.getenv("COLUMNS"))
    if cols and cols > 0 then
        return cols
    end
    
    if is_windows() then
        -- Try mode con on Windows
        local handle = io.popen("mode con /status 2>nul")
        if handle then
            for line in handle:lines() do
                local num = line:match("Columns:%s*(%d+)")
                if num then
                    handle:close()
                    return tonumber(num)
                end
            end
            handle:close()
        end
    else
        -- Try tput on Unix
        local fh = io.popen("tput cols 2>/dev/null")
        if fh then
            local w = fh:read("*l")
            fh:close()
            local num = tonumber(w)
            if num and num > 0 then
                return num
            end
        end
    end
    
    return 80 -- default fallback
end

-- Creates a boxed table from a list of strings
-- options: {header=..., footer=..., align="left"|"center"|"right"}
local function to_string(val)
    if type(val) == "table" then
        local t = {}
        for k, v in pairs(val) do
            table.insert(t, tostring(k) .. ": " .. to_string(v))
        end
        return "{" .. table.concat(t, ", ") .. "}"
    elseif type(val) == "boolean" then
        return val and "true" or "false"
    else
        return tostring(val)
    end
end

-- Return the visible width of a string (ANSI escape sequences are ignored)
local function display_width(s)
    s = tostring(s or "")
    return #(s:gsub("\27%[[0-9;]*m", ""))
end


function tbl.boxed(items, options)
    options = options or {}
    local lines = {}
    local str_items = {}
    for _, item in ipairs(items) do
        table.insert(str_items, to_string(item))
    end

    local header = options.header and to_string(options.header) or nil
    local footer = options.footer and to_string(options.footer) or nil

    -- Compute maximum width
    local all_items = {}
    if header then table.insert(all_items, header) end
    for _, v in ipairs(str_items) do table.insert(all_items, v) end
    if footer then table.insert(all_items, footer) end
    local max_len = 0
    for _, item in ipairs(all_items) do
        if display_width(item) > max_len then max_len = display_width(item) end
    end

    -- If 'large' option, adapt width to terminal
    if options.large then
        local term_width = get_terminal_width()
        if term_width > 10 then
            max_len = term_width - 4 -- 2 for each border
            if max_len < 1 then max_len = 1 end
        end
    end

    local function align_text(text)
        local text_len = display_width(text)
        local pad_left, pad_right = 0, 0
        if options.align == "center" then
            pad_left = math.floor((max_len - text_len) / 2)
            pad_right = max_len - text_len - pad_left
        elseif options.align == "right" then
            pad_left = max_len - text_len
            pad_right = 0
        else -- left
            pad_left = 0
            pad_right = max_len - text_len
        end
        return string.rep(" ", pad_left) .. text .. string.rep(" ", pad_right)
    end

    local top = "┌" .. string.rep("─", max_len + 2) .. "┐"
    local sep = "├" .. string.rep("─", max_len + 2) .. "┤"
    local bottom = "└" .. string.rep("─", max_len + 2) .. "┘"
    table.insert(lines, top)
    if header then
        table.insert(lines, "│ " .. align_text(header) .. " │")
        table.insert(lines, sep)
    end
    for _, item in ipairs(str_items) do
        table.insert(lines, "│ " .. align_text(item) .. " │")
    end
    if footer then
        table.insert(lines, sep)
        table.insert(lines, "│ " .. align_text(footer) .. " │")
    end
    table.insert(lines, bottom)
    return table.concat(lines, "\n")
end

-- Advanced table with headers and rows
function tbl.create(data, options)
    options = options or {}
    local lines = {}
    
    if not data or #data == 0 then
        return "Empty table"
    end
    
    -- Get headers from first row if not provided
    local headers = options.headers or {}
    if #headers == 0 and type(data[1]) == "table" then
        for key, _ in pairs(data[1]) do
            table.insert(headers, key)
        end
        table.sort(headers)  -- deterministic column order
    end
    
    -- Convert data to string matrix
    local matrix = {}
    
    -- Add headers if available
    if #headers > 0 then
        local header_row = {}
        for _, header in ipairs(headers) do
            table.insert(header_row, to_string(header))
        end
        table.insert(matrix, header_row)
    end
    
    -- Add data rows
    for _, row in ipairs(data) do
        local row_data = {}
        if type(row) == "table" then
            if #headers > 0 then
                -- Use headers to extract values
                for _, header in ipairs(headers) do
                    table.insert(row_data, to_string(row[header] or ""))
                end
            else
                -- Array-like table
                for _, value in ipairs(row) do
                    table.insert(row_data, to_string(value))
                end
            end
        else
            table.insert(row_data, to_string(row))
        end
        table.insert(matrix, row_data)
    end
    
    -- Calculate column widths
    local col_widths = {}
    for _, row in ipairs(matrix) do
        for i, cell in ipairs(row) do
            col_widths[i] = math.max(col_widths[i] or 0, display_width(cell))
        end
    end
    
    -- Apply minimum/maximum width constraints
    if options.min_width then
        for i = 1, #col_widths do
            col_widths[i] = math.max(col_widths[i], options.min_width)
        end
    end
    
    if options.max_width then
        for i = 1, #col_widths do
            col_widths[i] = math.min(col_widths[i], options.max_width)
        end
    end
    
    -- Auto-fit to terminal width
    if options.fit_terminal ~= false then
        local term_width = get_terminal_width()
        local total_width = 1  -- left border
        for i, w in ipairs(col_widths) do
            total_width = total_width + w + 2 + (i < #col_widths and 1 or 0)
        end
        total_width = total_width + 1  -- right border
        
        if total_width > term_width and term_width > 20 then
            local excess = total_width - term_width
            local num_cols = #col_widths
            -- Reduce widest columns first
            while excess > 0 do
                local max_i, max_w = 1, col_widths[1]
                for i = 2, num_cols do
                    if col_widths[i] > max_w then
                        max_i, max_w = i, col_widths[i]
                    end
                end
                if max_w <= 3 then break end
                local reduction = math.min(excess, math.max(1, math.floor(max_w * 0.2)))
                col_widths[max_i] = max_w - reduction
                excess = excess - reduction
            end
        end
    end
    
    -- Format table
    local border_chars = options.border or {
        top_left = "┌", top_right = "┐", bottom_left = "└", bottom_right = "┘",
        horizontal = "─", vertical = "│", cross = "┼", 
        top_tee = "┬", bottom_tee = "┴", left_tee = "├", right_tee = "┤"
    }
    
    -- Top border
    local top_line = border_chars.top_left
    for i, width in ipairs(col_widths) do
        top_line = top_line .. string.rep(border_chars.horizontal, width + 2)
        if i < #col_widths then
            top_line = top_line .. border_chars.top_tee
        end
    end
    top_line = top_line .. border_chars.top_right
    table.insert(lines, top_line)
    
    -- Rows
    local has_headers = #headers > 0
    for row_idx, row in ipairs(matrix) do
        local line = border_chars.vertical
        for i, cell in ipairs(row) do
            local width = col_widths[i]
            -- Truncate cell if it exceeds the column width (e.g. due to max_width)
            if display_width(cell) > width then
                cell = cell:sub(1, width)
            end
            local padded_cell
            
            -- Alignment
            local align = options.align and options.align[i] or "left"
            if align == "center" then
                local pad_left = math.floor((width - display_width(cell)) / 2)
                local pad_right = width - display_width(cell) - pad_left
                padded_cell = string.rep(" ", pad_left) .. cell .. string.rep(" ", pad_right)
            elseif align == "right" then
                padded_cell = string.rep(" ", width - display_width(cell)) .. cell
            else -- left
                padded_cell = cell .. string.rep(" ", width - display_width(cell))
            end
            
            line = line .. " " .. padded_cell .. " " .. border_chars.vertical
        end
        table.insert(lines, line)
        
        -- Header separator
        if has_headers and row_idx == 1 then
            local separator = border_chars.left_tee
            for i, width in ipairs(col_widths) do
                separator = separator .. string.rep(border_chars.horizontal, width + 2)
                if i < #col_widths then
                    separator = separator .. border_chars.cross
                end
            end
            separator = separator .. border_chars.right_tee
            table.insert(lines, separator)
        end
    end
    
    -- Bottom border
    local bottom_line = border_chars.bottom_left
    for i, width in ipairs(col_widths) do
        bottom_line = bottom_line .. string.rep(border_chars.horizontal, width + 2)
        if i < #col_widths then
            bottom_line = bottom_line .. border_chars.bottom_tee
        end
    end
    bottom_line = bottom_line .. border_chars.bottom_right
    table.insert(lines, bottom_line)
    
    return table.concat(lines, "\n")
end

-- Simple table without borders
function tbl.simple(data, options)
    options = options or {}
    local lines = {}
    
    if not data or #data == 0 then
        return "Empty table"
    end
    
    -- Get headers
    local headers = options.headers or {}
    if #headers == 0 and type(data[1]) == "table" then
        for key, _ in pairs(data[1]) do
            table.insert(headers, key)
        end
        table.sort(headers)  -- deterministic column order
    end
    
    -- Convert to matrix
    local matrix = {}
    if #headers > 0 then
        local header_row = {}
        for _, header in ipairs(headers) do
            table.insert(header_row, to_string(header))
        end
        table.insert(matrix, header_row)
    end
    
    for _, row in ipairs(data) do
        local row_data = {}
        if type(row) == "table" then
            if #headers > 0 then
                for _, header in ipairs(headers) do
                    table.insert(row_data, to_string(row[header] or ""))
                end
            else
                for _, value in ipairs(row) do
                    table.insert(row_data, to_string(value))
                end
            end
        else
            table.insert(row_data, to_string(row))
        end
        table.insert(matrix, row_data)
    end
    
    -- Calculate column widths
    local col_widths = {}
    for _, row in ipairs(matrix) do
        for i, cell in ipairs(row) do
            col_widths[i] = math.max(col_widths[i] or 0, display_width(cell))
        end
    end
    
    local separator = options.separator or "  "
    
    -- Format rows
    for row_idx, row in ipairs(matrix) do
        local line_parts = {}
        for i, cell in ipairs(row) do
            local width = col_widths[i]
            -- Truncate cell if it exceeds the column width
            if display_width(cell) > width then
                cell = cell:sub(1, width)
            end
            local align = options.align and options.align[i] or "left"
            local padded_cell
            
            if align == "center" then
                local pad_left = math.floor((width - display_width(cell)) / 2)
                local pad_right = width - display_width(cell) - pad_left
                padded_cell = string.rep(" ", pad_left) .. cell .. string.rep(" ", pad_right)
            elseif align == "right" then
                padded_cell = string.rep(" ", width - display_width(cell)) .. cell
            else -- left
                padded_cell = cell .. string.rep(" ", width - display_width(cell))
            end
            
            table.insert(line_parts, padded_cell)
        end
        table.insert(lines, table.concat(line_parts, separator))
        
        -- Header separator for simple tables
        if #headers > 0 and row_idx == 1 then
            local sep_parts = {}
            for i, width in ipairs(col_widths) do
                table.insert(sep_parts, string.rep("-", width))
            end
            table.insert(lines, table.concat(sep_parts, separator))
        end
    end
    
    return table.concat(lines, "\n")
end

-- Key-value pairs table
function tbl.key_value(data, options)
    options = options or {}
    local items = {}
    
    for key, value in pairs(data) do
        table.insert(items, {Key = to_string(key), Value = to_string(value)})
    end
    table.sort(items, function(a, b) return a.Key < b.Key end)
    
    local table_options = {
        headers = {"Key", "Value"},
        align = {"left", "left"}
    }
    
    if options.simple then
        return tbl.simple(items, table_options)
    else
        return tbl.create(items, table_options)
    end
end

-- Split rows into pages of a given size.
function tbl.paginate(rows, page_size)
    page_size = page_size or 10
    local pages = {}
    for i = 1, #rows, page_size do
        local page = {}
        for j = i, math.min(i + page_size - 1, #rows) do
            table.insert(page, rows[j])
        end
        table.insert(pages, page)
    end
    return pages
end

-- Return a single page of rows along with pagination metadata.
function tbl.page(rows, page_num, page_size)
    page_num = page_num or 1
    page_size = page_size or 10
    local total_pages = math.max(1, math.ceil(#rows / page_size))
    if page_num < 1 then page_num = 1 end
    if page_num > total_pages then page_num = total_pages end
    local start_idx = (page_num - 1) * page_size + 1
    local end_idx = math.min(start_idx + page_size - 1, #rows)
    local page = {}
    for i = start_idx, end_idx do
        table.insert(page, rows[i])
    end
    return {
        data = page,
        page = page_num,
        total_pages = total_pages,
        total_rows = #rows,
        page_size = page_size,
        has_next = page_num < total_pages,
        has_prev = page_num > 1
    }
end

return tbl
