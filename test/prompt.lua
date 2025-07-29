-- Test complet pour lumos.prompt
local prompt = require('lumos.prompt')
local color = require('lumos.color')

print("\n--- Test interactif prompt.input ---")
local input1 = prompt.input("Entrer une valeur (defaut)", "defaut")
print("Vous avez entré :", input1)

print("\n--- Test interactif prompt.password ---")
local pwd = prompt.password("Mot de passe")
print("Mot de passe saisi :", pwd)

print("\n--- Test interactif prompt.confirm ---")
local conf = prompt.confirm("Confirmer ?", true)
print("Confirmation :", tostring(conf))

print("\n--- Test interactif prompt.select ---")
local idx, val = prompt.select("Choisissez une option :", {"A", "B", "C"}, 2)
print("Choix :", idx, val)

print("\n--- Test interactif prompt.multiselect ---")
local res = prompt.multiselect("Sélection multiple :", {"A", "B", "C"})
print("Sélections :")
for _, v in ipairs(res) do print(v.index, v.value) end

print("\n--- Test interactif prompt.validate ---")
io.write("Entrez un nombre : ")
local val = io.read("*l")
local function is_num(x) return tonumber(x) ~= nil end
local ok, result = prompt.validate(val, is_num, "Ce n'est pas un nombre !")
if ok then
    print("Validé :", result)
else
    print("Erreur :", result)
end
