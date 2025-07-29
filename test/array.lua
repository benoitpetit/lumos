-- test/array.lua
-- Démonstration de la création de tableaux encadrés avec lumos.array

local array = require("lumos.array")

local fruits = {"Pomme", "Banane", "Cerise", "Abricot"}
print(array.boxed(fruits))

local infos = {"Nom: Ben", "Projet: Lumos", "Version: 0.1.0"}
print(array.boxed(infos))
