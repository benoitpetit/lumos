-- test/loader.lua
-- Démonstration du loader CLI avec différents styles et gestion de statut

local loader = require("lumos.loader")

-- Style standard
loader.start("Chargement standard", "standard")
for i = 1, 8 do
    loader.next()
    os.execute("sleep 0.2")
end
loader.success()

-- Style dots
loader.start("Chargement points", "dots")
for i = 1, 8 do
    loader.next()
    os.execute("sleep 0.2")
end
loader.fail()

-- Style bounce
loader.start("Chargement bounce", "bounce")
for i = 1, 8 do
    loader.next()
    os.execute("sleep 0.2")
end
loader.stop()
