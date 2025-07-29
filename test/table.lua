-- test/table.lua
-- Démonstration de la création de tableaux encadrés avec lumos.table

local tbl = require("lumos.table")


local fruits = {"Pomme", "Banane", "Cerise", "Abricot"}
print(tbl.boxed(fruits))

local infos = {"Nom: Ben", "Projet: Lumos", "Version: 0.1.0"}
print(tbl.boxed(infos))

local mixed = {"Lumos", 42, true, {nested = "value"}}
print(tbl.boxed(mixed, {header = "Tableau Mixte", footer = "Fin du Tableau"}))

-- Exemple big table sans accents
local bigdata = {"Lumos", "Terminal", "Largeur", "Big Table", "Test"}
print(tbl.boxed(bigdata, {header = "Big Table", footer = "Fin", big = true}))