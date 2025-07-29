[200~# Lumos : Spécifications techniques et plan d’actionLumos a pour ambition d’offrir à la communauté Lua un framework CLI aussi ergonomique que Cobra pour Go, tout en restant fidèle à la philosophie « petit, clair, rapide ». Le présent document décrit l’architecture technique, l’API publique attendue, les conventions de développement, ainsi qu’une feuille de route détaillée accompagnée d’un tableau TODO exhaustif.

## 1. Principes d’architecture### 1.1 Philosophies directrices  
1. **Modularité granulaire** : chaque composant est un module Lua autonome retournant une table locale, conformément aux meilleures pratiques de la communauté[1].  
2. **Conforme POSIX** : la syntaxe des options suit strictement les Utility Syntax Guidelines (court `-f`, long `--force`, séparateur `--`)[2].  
3. **Extensibilité par plugins** : les sous‐commandes peuvent être chargées dynamiquement à partir d’un dossier `commands/`, à la manière des sub-commands Git[3][4].  
4. **Expérience développeur d’abord** : génération automatique d’aide, d’autocomplétion pour bash/zsh/fish/pwsh[5][6], validation d’entrée intégrée et messages d’erreur humains[7][8].

### 1.2 Couche cœur (Core)  
Le noyau « lumos.core » fournit :  
* un planificateur léger basé sur coroutines pour gérer les prompts asynchrones sans threads natifs[9][10];  
* un parseur d’arguments POSIX‐compliant dérivé du pattern `flags`[11];  
* un routeur de sous-commandes inspiré de CLI11/SubCmd qui résout `lumos-` dans le `PATH`[12][13].

## 2. Spécification de l’API publique### 2.1 Espace de noms principal
```lua
local lum``` = require```umos"

-- création``` l’application
local app```lumos.new_app{
 ```me        =```ytool",
  version```  = "0.1.0",
 ```scription =```xemple CLI```

-- déclaration```une sous-commande
local```eet = app:command("greet```"Affiche un```ssage")
greet:arg("name```"Nom à sal```"):default("World")
greet```ag("-q --quiet", "```e silencieux")

greet:```ion(function(ctx)
 ``` not ctx.flags.quiet then```  print("Hello "..```.args.name.."!")
 ```d
end)

app:run(arg)
```

### 2.2 Type `App`
| Méthode | Rôle | Retour |
|---------|------|--------|
| `new_app(tbl)` | Constructeur | `App` |
| `command(name, desc)` | Déclare un sous‐commande | `Command` |
| `flag(spec, desc)` | Ajoute un flag global | `Flag` |
| `option(spec, desc)` | Ajoute une option avec valeur | `Option` |
| `run(argv)` | Parse / exécute | nil |

### 2.3 Type `Command`  
* `arg(name, help)` : paramètre positionnel obligatoire.  
* `flag(spec, help)` / `option(spec, help)` : héritent du parseur POSIX[2].  
* `action(fn(ctx))` : enregistre la fonction à exécuter.  
* `examples{ "mytool greet Alice", …}` : documentation intégrée.

### 2.4 Flags et arguments  
L’analyseur supporte :  
* flags booléens `-v`, `--verbose`;  
* options avec valeur obligatoire `-o file` ou `--output=file`;  
* options combinées `-xzvf` grâce à l’algorithme d’expansion single-dash[14];  
* cascade des flags parents vers enfants comme Cobra[15].

### 2.5 Autocomplétion shell  
`app:enable_completion()` génère un sous-commande caché `completion ` qui imprime le script approprié, suivant la technique utilisée par urfave/cli et clikt[5][16][17].

### 2.6 Prompts interactifs  
Module `lumos.prompt` expose :  
* `prompt.input`, `prompt.password`, `prompt.select`, `prompt.multiselect`, avec validation synchrone ou asynchrone[18][19][20];  
* support de l’autocomplétion incrémentale dans les prompts textes ;  
* gestion des tentatives et messages d’erreur personnalisables[21].

### 2.7 Couleurs et styling  
Module `lumos.color` est un wrapper au-dessus de `ansicolors` et `eansi`[22][23][24] :  
```lua
color("{green}Succ```!{reset}")
```
Détection automatique TTY / Windows, et désactivation via `LUMOS_NO_COLOR`.

### 2.8 Indicateurs de progression  
`lumos.progress` fournit barres simples ou multi-barres inspirées de `cli-progress`[25][26] et de la spec R `cli_progress_bar`[27]. Exemple :
```lua
local bar```progress.new{ total```100 }
for i```100 do
  bar```c()
end
```

## 3. Organisation du code et des modules```
lumos/
 ├```ore.lua         ``` parseur, router```cheduler
 ├```ommand.lua      ``` objets Command```─ flags.lua        ``` gestion POS```flags
 ├─ prompt```a        -- API```teractive
 ├```olor.lua        ``` style ANSI```─ progress```a      -- bar``` de progression```─ completion```     -- templates```sh, zsh, fish```wsh
 └─ commands```       -- sous```mmandes plugins````
Chaque fichier retourne une table locale (pattern module 1)[1].

## 4. Packaging, distribution et versionnage### 4.1 Rockspec  
Un fichier `lumos-0.1.0-1.rockspec` décrira : dépendance `lua >= 5.3`, modules à installer, scripts binaires, tests, licence MIT[28][29][30][31].  
Champ `build.type = "builtin"` puis `modules = { ["lumos.core"]="lumos/core.lua", … }`.

### 4.2 Binaire de démarrage  
Le script `lumos` placé dans le `PATH` appelle :
```bash
#!/usr/bin/env```a
require("lumos.cli").main```g)
```
Il agit aussi comme « dispatcher » pour les plugins `lumos-` sur le modèle Git[3].

## 5. Assurance qualité : tests & CI* **Unités** : `busted` pour chaque module.  
* **Tests CLI** : harness expect‐like simulant l’entrée utilisateur.  
* **Lint** : `luacheck`.  
* **CI** : GitHub Actions matrice Lua 5.1 → 5.4 + LuaJIT, exécution des suites et publication sur LuaRocks.

## 6. Sécurité et validation d’entrée* Validation systématique des valeurs utilisateur via callbacks `validate()` et filtrage OWASP (longueur, regexp, white-list)[8].  
* Les prompts mots de passe utilisent l’entrée masquée et ne gardent rien en mémoire après usage.  
* Le parseur refuse toute option inconnue, conformément au principe « fail-fast ».

## 7. Feuille de route prévisionnelle  
Les jalons suivants structurent le projet :## 8. TODO détaillé| ID | Composant | Tâche | Priorité | Responsable |
|----|-----------|-------|----------|-------------|
| C-1 | core      | Implémenter `new_app`, parseur flags POSIX | 🟥 Élevée | @core-team |
| C-2 | core      | Algorithme de résolution sous-commandes Plugins | 🟥 | @core-team |
| F-1 | flags     | Gestion `--help`, `--version`, héritage | 🟥 | @flags |
| F-2 | flags     | Expansion single-dash (`-xzvf`) | 🟧 Moyenne | @flags |
| P-1 | prompt    | `prompt.input`, validation sync | 🟥 | @ux |
| P-2 | prompt    | `prompt.select` avec navigation clavier | 🟧 | @ux |
| P-3 | prompt    | Validation asynchrone (coroutines) | 🟨 Faible | @ux |
| AC-1 | completion | Génération bash/zsh | 🟥 | @shell |
| AC-2 | completion | fish & PowerShell | 🟧 | @shell |
| CLR-1 | color   | Wrapper `ansicolors`, auto-disable | 🟧 | @styling |
| PR-1 | progress | Barre simple (ETA, % ) | 🟧 | @styling |
| PR-2 | progress | Multi-barres concurrentes | 🟨 | @styling |
| DOC-1| docs     | Générateur d’aide auto par reflection | 🟥 | @docs |
| DOC-2| docs     | Documentation MD + exemples | 🟧 | @docs |
| PKG-1| package  | Rockspec 1.0, publication LuaRocks | 🟥 | @release |
| CI-1 | ci       | GitHub Actions build matrix | 🟥 | @ci |
| EX-1 | examples | `lumos hello` & `lumos todo` démos | 🟧 | @examples |

## Conclusion

En combinant un parseur POSIX robuste, une architecture modulaire Lua-native et un ensemble d’extensions modernes (couleurs, autocomplétion, prompts interactifs), Lumos vise à devenir la référence CLI de l’écosystème Lua. Le calendrier présenté permet une livraison incrémentale : d’abord un noyau minimal utilisable, puis des fonctionnalités différenciantes, enfin l’ouverture vers l’IA et les plugins externes. Il ne reste qu’à suivre le tableau TODO pour matérialiser la vision et faire rayonner la **lumière** de Lumos dans la ligne de commande.

[1] https://help.interfaceware.com/v6/recommended-module-structure
[2] https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap12.html
[3] https://blog.sebastian-daschner.com/entries/custom-git-subcommands
[4] https://opensource.com/article/22/4/customize-git-subcommands
[5] https://ajalt.github.io/clikt/autocomplete/
[6] https://developer.atlassian.com/cloud/acli/guides/enable-shell-autocomplete/
[7] https://www.thoughtworks.com/insights/blog/engineering-effectiveness/elevate-developer-experiences-cli-design-guidelines
[8] https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html
[9] http://lua-users.org/lists/lua-l/2015-01/msg00025.html
[10] https://www.lua.org/pil/9.1.html
[11] https://github.com/xitonix/flags
[12] https://github.com/davidmoreno/commands
[13] https://cliutils.gitlab.io/CLI11Tutorial/chapters/subcommands.html
[14] https://gist.github.com/AlexAegis/c2c21d2558e7a49f46f49a07009f5842
[15] https://github.com/spf13/cobra
[16] https://cli.urfave.org/v3/examples/completions/shell-completions/
[17] https://www.ncbi.nlm.nih.gov/datasets/docs/v1/reference-docs/command-line/dataformat/completion/
[18] https://github.com/mikaelmello/inquire
[19] https://docs.rs/inquire/latest/inquire/
[20] https://app.studyraid.com/en/read/12628/409795/input-validation-strategies
[21] https://kevinsmith.io/a-better-way-to-handle-validation-errors/
[22] https://codepal.ai/library-finder/query/dAJtJzke/lua-library-colors-terminal-output
[23] https://github.com/kikito/ansicolors.lua
[24] https://luarocks.org/modules/smi11/eansi
[25] https://www.npmjs.com/package/@sidneys/cli-progress
[26] https://www.npmjs.com/package/cli-progress
[27] https://search.r-project.org/CRAN/refmans/cli/html/cli_progress_bar.html
[28] https://github.com/stevedonovan/rockspec/blob/master/docs/readme.md
[29] https://luarocks.org/about
[30] https://googlegroups.com/group/bamboo-cn/attach/c532c649a40d01e4/Creating%20a%20rock.pdf?part=0.1
[31] https://www.lua.org/wshop14/Muhammad.pdf
[32] https://www.reddit.com/r/golang/comments/8d3qkr/go_cli_patterns/
[33] https://www.reddit.com/r/commandline/comments/m62cjq/recommended_architecture_for_cli_applications/
[34] https://www.bytesizego.com/blog/structure-go-cli-app
[35] https://dev.to/wesen/14-great-tips-to-make-amazing-cli-applications-3gp3
[36] https://www.packtpub.com/en-us/product/lua-game-development-cookbook-9781849515504/chapter/1-basics-of-the-game-engine-1/section/creating-lua-modules-ch01lvl1sec08
[37] https://www.codingexplorations.com/blog/mastering-cli-development-with-cobra-in-go-a-comprehensive-guide
[38] https://docs.sciencelogic.com/dev-docs/cli_toolkit/reference/best_practices.html
[39] https://github.com/floydawong/lua-patterns
[40] https://kddnewton.com/2016/10/11/exploring-cli-best-practices.html
[41] https://devforum.roblox.com/t/writing-clean-code-part-3-what-are-creational-design-patterns-how-do-i-use-them-and-why-do-i-care/2312758
[42] https://github.com/skport/golang-cli-architecture
[43] https://www.lua.org/doc/cacm2018.pdf
[44] https://cobra.dev
[45] https://www.thoughtworks.com/en-us/insights/blog/engineering-effectiveness/elevate-developer-experiences-cli-design-guidelines
[46] http://lua-users.org/wiki/LuaDesignPatterns
[47] https://dev.to/deadlock/golang-writing-cli-app-in-golang-with-cobra-54lp
[48] https://github.com/lirantal/nodejs-cli-apps-best-practices
[49] https://github.com/luarocks/luarocks/discussions/1714
[50] https://github.com/randrews/color
[51] https://stackoverflow.com/questions/40901215/what-is-a-good-way-to-manage-luarocks-rockspec-files-and-why
[52] https://docs.cloudera.com/cdp-public-cloud/cloud/cli/topics/mc-configure-cli-autocomplete.html
[53] https://docs.stackgen.com/cli-guide/configuration/autocomplete/autocomplete-for-stackgen
[54] https://github.com/hoelzro/ansicolors
[55] https://github.com/stevedonovan/rockspec
[56] https://packages.debian.org/sid/lua-ansicolors
[57] https://github.com/DieTime/CLI-AutoComplete
[58] https://github.com/gillesdemey/cli-progress-bar
[59] https://www.reddit.com/r/rust/comments/onft69/requestty_an_easytouse_collection_of_interactive/
[60] https://www.cs.princeton.edu/~appel/smlnj/basis/posix-flags.html
[61] https://www.npmjs.com/package/inquirer
[62] https://dev.to/lawaniej/alive-progress-bars-i0
[63] https://www.npmjs.com/package/@inquirer/prompts
[64] https://gist.github.com/coolaj86/1759b70e72f038869b7bf87816d9dc2e
[65] https://github.com/pyramation/inquirerer
[66] https://perldoc.perl.org/POSIX
[67] https://www.baeldung.com/linux/command-line-progress-bar
[68] https://www.digitalocean.com/community/tutorials/nodejs-interactive-command-line-prompts
[69] https://www.datacamp.com/tutorial/progress-bars-in-python
[70] https://github.com/Mister-Meeseeks/subcmd
[71] https://gist.github.com/Meorawr/6a69ad8857a3fb7202fda9e8c2731fed?permalink_comment_id=4091458
[72] https://labex.io/tutorials/go-how-to-validate-command-line-input-419830
[73] https://www.codecademy.com/resources/docs/lua/coroutines
[74] https://developer.mozilla.org/en-US/docs/Learn_web_development/Extensions/Forms/Form_validation
[75] https://github.com/ms-jpq/lua-async-await/blob/neo/README.md
[76] https://comp423-25s.github.io/resources/git/ch2-git-fundamental-subcommands/
[77] https://dkolf.de/lua-async-await
[78] https://app.studyraid.com/en/read/11921/379940/input-validation-strategies
[79] https://betterstack.com/community/guides/scaling-php/laravel-error-handling-patterns/
[80] https://news.ycombinator.com/item?id=15471950
