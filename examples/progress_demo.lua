#!/usr/bin/env lua

-- Démonstration du module progress de Lumos
-- Montre différents types de barres de progression

-- Ajouter le répertoire parent au chemin de recherche
package.path = package.path .. ';./?.lua;./?/init.lua'

local progress = require('lumos.progress')
local color = require('lumos.color')

print("=== Démonstration du module Progress de Lumos ===\n")

-- Fonction utilitaire pour simuler du travail
local function simulate_work(duration)
    -- Utiliser une méthode plus précise pour des délais courts
    local start_time = os.clock()
    local target_duration = duration or 0.1
    while os.clock() - start_time < target_duration do
        -- Simulation de travail
    end
end

-- 1. Barre de progression simple
print("1. Barre de progression simple:")
for i = 1, 10 do
    progress.simple(i, 10)
    simulate_work(0.05)  -- Réduit de 200ms à 50ms
end
print()

-- 2. Barre de progression avancée avec configuration personnalisée
print("2. Barre de progression avancée:")
local bar1 = progress.new({
    total = 20,
    width = 40,
    format = "[{bar}] {percentage}% ({current}/{total}) {eta}",
    fill = "█",
    empty = "░",
    prefix = "Traitement: ",
    suffix = " Terminé"
})

for i = 1, 20 do
    bar1:update(i)
    simulate_work(0.03)  -- Réduit de 100ms à 30ms
end
print()

-- 3. Différents styles de barres
print("3. Différents styles:")

-- Style classique
print("Style classique:")
local bar_classic = progress.new({
    total = 15,
    width = 30,
    style = "classic",
    format = "Classique: [{bar}] {percentage}%"
})
for i = 1, 15 do
    bar_classic:update(i)
    simulate_work(0.02)  -- Réduit à 20ms
end
print()

-- Style Unicode
print("Style Unicode:")
local bar_unicode = progress.new({
    total = 15,
    width = 30,
    style = "unicode",
    format = "Unicode: [{bar}] {percentage}%"
})
for i = 1, 15 do
    bar_unicode:update(i)
    simulate_work(0.02)  -- Réduit à 20ms
end
print()

-- Style blocs
print("Style blocs:")
local bar_blocks = progress.new({
    total = 15,
    width = 30,
    style = "blocks",
    format = "Blocs: [{bar}] {percentage}%"
})
for i = 1, 15 do
    bar_blocks:update(i)
    simulate_work(0.02)  -- Réduit à 20ms
end
print()

-- 4. Barre avec couleurs dynamiques
print("4. Barre avec couleurs dynamiques:")
local bar_colored = progress.new({
    total = 30,
    width = 50,
    format = "Coloré: [{bar}] {percentage}%",
    color_fn = function(bar, current, total)
        local ratio = current / total
        if ratio < 0.33 then
            return color.red(bar)
        elseif ratio < 0.66 then
            return color.yellow(bar)
        else
            return color.green(bar)
        end
    end
})

for i = 1, 30 do
    bar_colored:update(i)
    simulate_work(0.015)  -- Réduit à 15ms
end
print()

-- 5. Utilisation avec increment au lieu d'update
print("5. Utilisation avec increment:")
local bar_increment = progress.new({
    total = 50,  -- Réduit de 100 à 50 pour être plus rapide
    width = 40,
    format = "Incrémental: [{bar}] {current}/{total}"
})

-- Simulation de traitement par lots
local batch_sizes = {5, 10, 15, 20}  -- Réduit le nombre de lots
for _, batch_size in ipairs(batch_sizes) do
    for j = 1, batch_size do
        bar_increment:increment()
        simulate_work(0.01)  -- Réduit à 10ms
    end
    simulate_work(0.05)  -- Réduit la pause entre les lots
end

-- S'assurer que la barre est complète
bar_increment:finish()
print()

-- 6. Plusieurs barres en parallèle (simulation)
print("6. Simulation de barres multiples:")
print("Tâche A:")
local task_a = progress.new({
    total = 8,
    format = "  A: [{bar}] {percentage}%"
})

print("Tâche B:")
local task_b = progress.new({
    total = 12,
    format = "  B: [{bar}] {percentage}%"
})

-- Simulation de tâches en parallèle
for i = 1, 12 do
    if i <= 8 then
        task_a:update(i)
    end
    task_b:update(i)
    simulate_work(0.05)  -- Réduit de 100ms à 50ms
end

print()
print("Démonstration terminée!")
print(color.green("✓ Toutes les barres de progression ont été testées avec succès"))
