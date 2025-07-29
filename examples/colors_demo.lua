#!/usr/bin/env lua

-- Démonstration du module color de Lumos
-- Montre toutes les capacités de colorisation et stylage

-- Ajouter le répertoire parent au chemin de recherche
package.path = package.path .. ';./?.lua;./?/init.lua'

local color = require('lumos.color')

print("=== Démonstration du module Color de Lumos ===\n")

-- Couleurs de base
print("Couleurs de base:")
print("• " .. color.red("Rouge"))
print("• " .. color.green("Vert"))
print("• " .. color.blue("Bleu"))
print("• " .. color.yellow("Jaune"))
print("• " .. color.magenta("Magenta"))
print("• " .. color.cyan("Cyan"))
print("• " .. color.black("Noir"))
print("• " .. color.format("{white}Blanc{reset}"))
print()

-- Couleurs vives
print("Couleurs vives:")
print("• " .. color.colorize("Rouge vif", "bright_red"))
print("• " .. color.colorize("Vert vif", "bright_green"))
print("• " .. color.colorize("Bleu vif", "bright_blue"))
print("• " .. color.colorize("Jaune vif", "bright_yellow"))
print("• " .. color.colorize("Magenta vif", "bright_magenta"))
print("• " .. color.colorize("Cyan vif", "bright_cyan"))
print()

-- Couleurs de fond
print("Couleurs de fond:")
print("• " .. color.colorize("Fond rouge", "bg_red"))
print("• " .. color.colorize("Fond vert", "bg_green"))
print("• " .. color.colorize("Fond bleu", "bg_blue"))
print("• " .. color.colorize("Fond jaune", "bg_yellow"))
print()

-- Styles de texte
print("Styles de texte:")
print("• " .. color.bold("Texte en gras"))
print("• " .. color.dim("Texte estompé"))
print("• " .. color.colorize("Texte italique", "italic"))
print("• " .. color.colorize("Texte souligné", "underline"))
print("• " .. color.colorize("Texte barré", "strikethrough"))
print()

-- Formatage avec templates
print("Formatage avec templates:")
print(color.format("{red}Erreur:{reset} Quelque chose s'est mal passé"))
print(color.format("{green}{bold}Succès!{reset} L'opération est terminée"))
print(color.format("{blue}Info:{reset} {dim}Détails supplémentaires{reset}"))
print(color.format("{yellow}Attention:{reset} Vérifiez votre configuration"))
print()

-- Exemples pratiques
print("Exemples pratiques:")

-- Simulation d'un log
local function log_message(level, message)
    local colors = {
        ERROR = "red",
        WARN = "yellow", 
        INFO = "blue",
        SUCCESS = "green"
    }
    local template = "{" .. colors[level] .. "}{bold}[" .. level .. "]{reset} " .. message
    print(color.format(template))
end

log_message("ERROR", "Connexion à la base de données échouée")
log_message("WARN", "Configuration par défaut utilisée")
log_message("INFO", "Traitement en cours...")
log_message("SUCCESS", "Fichier sauvegardé avec succès")
print()

-- Barre de progression colorée
print("Barre de progression colorée:")
local function colored_progress(percentage)
    local filled = math.floor(percentage / 2)  -- 50 chars max
    local empty = 50 - filled
    
    local bar_color = "red"
    if percentage > 33 then bar_color = "yellow" end
    if percentage > 66 then bar_color = "green" end
    
    local bar = string.rep("█", filled) .. string.rep("░", empty)
    return color.format("[{" .. bar_color .. "}" .. bar .. "{reset}] " .. percentage .. "%")
end

for i = 0, 100, 25 do
    print(colored_progress(i))
end
print()

-- Test de détection du terminal
print("État des couleurs:")
print("• Couleurs activées: " .. (color.is_enabled() and "✓" or "✗"))
print("• Contrôle: utilisez LUMOS_NO_COLOR=1 pour désactiver")
print()

-- Fonction pour désactiver/réactiver les couleurs
print("Test d'activation/désactivation:")
print("Avec couleurs: " .. color.red("Texte rouge"))
color.disable()
print("Sans couleurs: " .. color.red("Texte rouge"))
color.enable()
print("Avec couleurs: " .. color.red("Texte rouge"))
