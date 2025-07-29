#!/usr/bin/env lua

-- Démonstration du module loader de Lumos
-- Montre différents styles de loaders et statuts

-- Ajouter le répertoire parent au chemin de recherche
package.path = package.path .. ';./?.lua;./?/init.lua'

local loader = require('lumos.loader')
local color = require('lumos.color')

print("=== Démonstration du module Loader de Lumos ===\n")

-- Fonction utilitaire pour simuler du travail
local function simulate_work(duration)
    local start_time = os.clock()
    local target_duration = duration or 0.1
    while os.clock() - start_time < target_duration do
        -- Simulation de travail
    end
end

-- 1. Loader standard avec succès
print("1. Loader standard avec succès:")
loader.start("Connexion à la base de données", "standard")
for i = 1, 15 do
    loader.next()
    simulate_work(0.1)
end
loader.success()
print()

-- 2. Loader dots avec échec
print("2. Loader dots avec échec:")
loader.start("Téléchargement du fichier", "dots")
for i = 1, 8 do
    loader.next()
    simulate_work(0.15)
end
loader.fail()
print()

-- 3. Loader bounce avec arrêt
print("3. Loader bounce avec arrêt:")
loader.start("Traitement des données", "bounce")
for i = 1, 6 do
    loader.next()
    simulate_work(0.12)
end
loader.stop()
print()

-- 4. Simulation de différentes tâches avec différents styles
print("4. Simulation de tâches multiples:")

local tasks = {
    {message = "Initialisation du système", style = "standard", duration = 0.08, iterations = 12, result = "success"},
    {message = "Chargement des modules", style = "dots", duration = 0.1, iterations = 10, result = "success"},
    {message = "Vérification des permissions", style = "bounce", duration = 0.06, iterations = 15, result = "success"},
    {message = "Configuration réseau", style = "standard", duration = 0.12, iterations = 8, result = "fail"},
    {message = "Sauvegarde des paramètres", style = "dots", duration = 0.09, iterations = 11, result = "success"},
}

for _, task in ipairs(tasks) do
    loader.start(task.message, task.style)
    for i = 1, task.iterations do
        loader.next()
        simulate_work(task.duration)
    end
    
    if task.result == "success" then
        loader.success()
    elseif task.result == "fail" then
        loader.fail()
    else
        loader.stop()
    end
end

print()
print("5. Démonstration des différents styles de loaders:")

-- Style standard
print("\n   Style STANDARD:")
loader.start("   Exemple standard", "standard")
for i = 1, 8 do
    loader.next()
    simulate_work(0.1)
end
loader.success()

-- Style dots
print("\n   Style DOTS:")
loader.start("   Exemple avec points", "dots")
for i = 1, 8 do
    loader.next()
    simulate_work(0.1)
end
loader.success()

-- Style bounce
print("\n   Style BOUNCE:")
loader.start("   Exemple avec rebond", "bounce")
for i = 1, 8 do
    loader.next()
    simulate_work(0.1)
end
loader.success()

print()
print("=== Résumé des fonctionnalités ===\n")
print(color.bold("Styles disponibles:"))
print("  • standard : | / - \\")
print("  • dots     : .   ..  ...")
print("  • bounce   : ◜ ◠ ◝ ◞ ◡ ◟")
print()
print(color.bold("Méthodes disponibles:"))
print("  • loader.start(message, style) - Démarre un loader")
print("  • loader.next()                 - Anime le loader")
print("  • loader.success()              - Termine avec succès")
print("  • loader.fail()                 - Termine avec échec")
print("  • loader.stop()                 - Arrête le loader")
print()
print(color.green("✓ Démonstration des loaders terminée avec succès!"))
