local progress = require('lumos.progress')
local color = require('lumos.color')
local lumos_table = require('lumos.table')

local function run_bar(bar)
    for i = 1, bar.total do
        bar:update(i)
        os.execute("sleep 0.02")
    end
    -- bar:finish()
end

print("Barre classique :")
local bar1 = progress.new{total=50, style="classic"}
run_bar(bar1)

print("Barre Unicode :")
local bar2 = progress.new{total=50, style="unicode"}
run_bar(bar2)

print("Barre blocs :")
local bar3 = progress.new{total=50, style="blocks"}
run_bar(bar3)

print("Barre Unicode :")
local bar4 = progress.new{
    total=50,
    style="unicode",
    color_fn=function(bar, current, total)
        return progress.color_bar(bar, current, total, "magenta")
    end
}run_bar(bar4)

print("Barre colorée :")
local bar5 = progress.new{total=50, style="unicode", color_fn=progress.color_bar}
run_bar(bar5)