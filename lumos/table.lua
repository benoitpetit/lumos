
-- lumos/table.lua
-- Module pour créer des tableaux encadrés dans le CLI

local tbl = {}

-- Crée un tableau encadré à partir d'une liste de chaînes
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


function tbl.boxed(items, options)
    options = options or {}
    local lines = {}
    local str_items = {}
    for _, item in ipairs(items) do
        table.insert(str_items, to_string(item))
    end

    local header = options.header and to_string(options.header) or nil
    local footer = options.footer and to_string(options.footer) or nil

    -- Calcule la largeur maximale
    local all_items = {}
    if header then table.insert(all_items, header) end
    for _, v in ipairs(str_items) do table.insert(all_items, v) end
    if footer then table.insert(all_items, footer) end
    local max_len = 0
    for _, item in ipairs(all_items) do
        if #item > max_len then max_len = #item end
    end

    -- Si option big, adapte la largeur au terminal
    if options.big then
        local term_width = 0
        local fh = io.popen('tput cols 2>/dev/null')
        if fh then
            local w = fh:read('*l')
            fh:close()
            term_width = tonumber(w) or 0
        end
        if term_width > 10 then
            max_len = term_width - 4 -- 2 pour chaque bordure
            if max_len < 1 then max_len = 1 end
        end
    end

    local function align_text(text)
        local text_len = #text
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

return tbl
