
-- lumos/table.lua
-- Module pour créer des tableaux encadrés dans le CLI

local tbl = {}

-- Crée un tableau encadré à partir d'une liste de chaînes
function tbl.boxed(items)
    -- Trouve la largeur maximale
    local max_len = 0
    for _, item in ipairs(items) do
        if #item > max_len then max_len = #item end
    end
    local top = "┌" .. string.rep("─", max_len + 2) .. "┐"
    local bottom = "└" .. string.rep("─", max_len + 2) .. "┘"
    local lines = {top}
    for _, item in ipairs(items) do
        table.insert(lines, "│ " .. item .. string.rep(" ", max_len - #item) .. " │")
    end
    table.insert(lines, bottom)
    return table.concat(lines, "\n")
end

return tbl
