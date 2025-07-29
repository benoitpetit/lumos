#!/usr/bin/env lua

-- Exemple basique d'utilisation du framework Lumos
-- Démontre les fonctionnalités principales : commandes, arguments, flags

-- Ajouter le répertoire parent au chemin de recherche
package.path = package.path .. ';./?.lua;./?/init.lua'

local lumos = require('lumos')
local color = require('lumos.color')

-- Créer l'application
local app = lumos.new_app({
    name = "myapp",
    version = "1.0.0", 
    description = "Exemple basique d'utilisation de Lumos"
})

-- Ajouter des flags globaux
app:flag("-v --verbose", "Active la sortie détaillée")
app:flag("--debug", "Active le mode debug")

-- Commande "greet" pour saluer
local greet = app:command("greet", "Salue une personne")
greet:arg("name", "Nom de la personne à saluer")
greet:flag("-u --uppercase", "Affiche en majuscules") 
greet:flag("-c --colorful", "Affiche en couleur")
greet:examples({
    "myapp greet Alice",
    "myapp greet Bob --uppercase",
    "myapp greet Charlie --colorful"
})

greet:action(function(ctx)
    local name = ctx.args[1] or "Monde"
    local message = "Bonjour, " .. name .. " !"
    
    if ctx.flags.uppercase then
        message = message:upper()
    end
    
    if ctx.flags.colorful then
        message = color.green(message)
    end
    
    if ctx.flags.verbose then
        print(color.dim("Mode verbose activé"))
        print(color.dim("Arguments reçus: " .. table.concat(ctx.args or {}, ", ")))
    end
    
    print(message)
    return true
end)

-- Commande "info" pour des informations
local info = app:command("info", "Affiche des informations sur l'application")
info:flag("-a --all", "Affiche toutes les informations")

info:action(function(ctx)
    print(color.bold("Informations sur l'application:"))
    print("Nom: " .. color.cyan("myapp"))
    print("Version: " .. color.yellow("1.0.0"))
    
    if ctx.flags.all then
        print("Framework: " .. color.magenta("Lumos"))
        print("Langage: " .. color.blue("Lua"))
        print("Commandes disponibles: greet, info")
    end
    
    return true
end)

-- Lancer l'application avec les arguments de la ligne de commande
app:run(arg)
