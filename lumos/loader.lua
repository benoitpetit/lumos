-- lumos/loader.lua
-- Loader CLI which displays a loading animation in the terminal.
-- It supports different styles and can indicate success or failure.
local loader = {}

local styles = {
    standard = {"|", "/", "-", "\\"},
    dots = {".  ", ".. ", "...", "   "},
    bounce = {"◜", "◠", "◝", "◞", "◡", "◟"}
}

local current = {
    active = false,
    style = styles.standard,
    idx = 1,
    message = "",
    status = ""
}


function loader.start(msg, style_name)
    current.active = true
    current.style = styles[style_name] or styles.standard
    current.idx = 1
    current.message = msg or "Loading"
    current.status = "loading"
    io.write("\r" .. current.message .. " " .. current.style[current.idx] .. string.rep(" ", 20) .. "\r")
    io.flush()
end


function loader.stop()
    if current.active then
        io.write("\r" .. current.message .. " [STOP]" .. string.rep(" ", 20) .. "\n")
        io.flush()
        current.active = false
        current.status = "stopped"
    end
end


function loader.success()
    if current.active then
        io.write("\r" .. current.message .. " [OK]" .. string.rep(" ", 20) .. "\n")
        io.flush()
        current.active = false
        current.status = "success"
    end
end


function loader.fail()
    if current.active then
        io.write("\r" .. current.message .. " [FAIL]" .. string.rep(" ", 20) .. "\n")
        io.flush()
        current.active = false
        current.status = "fail"
    end
end


function loader.next()
    if current.active then
        current.idx = current.idx % #current.style + 1
        io.write("\r" .. current.message .. " " .. current.style[current.idx] .. string.rep(" ", 20) .. "\r")
        io.flush()
    end
end

return loader
