# Lumos CLI Framework

<p align="center">
    <img src="assets/lumosb&wclear.png" alt="Lumos Logo" width="250">
</p>

<p align="center">
    <strong>Un framework CLI moderne pour Lua</strong><br>
    Construisez des applications en ligne de commande puissantes avec facilité
</p>

<p align="center">
    <a href="docs/qs.md">🚀 Démarrage rapide</a> •
    <a href="docs/api.md">📚 API</a> •
    <a href="docs/use.md">💡 Exemples</a> •
    <a href="#installation">⚡ Installation</a>
</p>

---

**Lumos** (latin pour "lumière") apporte de la clarté au développement CLI en Lua. Inspiré par Cobra pour Go, il fournit tout le nécessaire pour construire des applications en ligne de commande professionnelles avec un minimum de code et un maximum de fonctionnalités.

## ✨ Ce qui rend Lumos spécial

- **🚀 Générateur de projets** - `lumos new` crée des projets CLI complets en quelques secondes
- **🎯 API intuitive** - Méthodes chaînables et fluides pour définir commandes et flags
- **🎨 Composants UI riches** - Couleurs, barres de progression, prompts et tableaux natifs
- **🔗 Middleware** - Chaîne de middleware Express-like avec auth, dry-run, rate-limiting, etc.
- **⚔️ Flags avancés** - int, float, array, enum, path, url, email avec validation intégrée
- **🔧 Intégration shell** - Auto-complétion, pages de manuel et génération de documentation
- **⚙️ Gestion de configuration** - Fichiers JSON et key=value, variables d'environnement, cache intégré
- **🧪 Prêt pour les tests** - Les projets générés incluent Busted et un fichier de test de démarrage
- **📦 Dépendances minimales** - Seulement `luafilesystem`, architecture modulaire
- **🌍 Multiplateforme** - Linux, macOS et Windows natif avec détection automatique
- **🚀 Bundles portables** - Scripts Lua autonomes avec `lumos bundle`
- **📦 Packages autonomes** - Exécutables sans dépendance avec `lumos package`
- **🔨 Builds natives** - Compilation en binaire natif avec `lumos build`
- **🔒 Sécurité intégrée** - Sanitization, opérations fichier sécurisées, rate limiting
- **📝 Logging structuré** - Logger 5 niveaux avec loggers enfants et configuration environnementale
- **⚡ Lazy loading** - Chargement à la demande des modules pour un démarrage rapide (< 30ms)

## 🚀 Démarrage rapide en 5 minutes

### 📎 TL;DR

```bash
# Installer Lumos depuis LuaRocks
luarocks install --local lumos

# Créer votre première app CLI
lumos new hello-world && cd hello-world

# Lancer !
lua src/main.lua greet "Maître CLI"
# Sortie : Hello, Maître CLI !
```

### 🔍 Guide étape par étape

**Étape 1 : Installer Lumos**
```bash
luarocks install --local lumos

# Ajouter au PATH si nécessaire
echo 'export PATH="$HOME/.luarocks/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Étape 2 : Créer votre projet CLI**
```bash
lumos new my-awesome-cli
# Suivre les prompts interactifs
cd my-awesome-cli
```

**Étape 3 : Tester votre CLI**
```bash
lua src/main.lua --help        # Voir l'aide générée
lua src/main.lua greet World   # Essayer la commande d'exemple
```

**Étape 4 : Développer & Tester**
```bash
make install  # Installer les dépendances de test
make test     # Lancer la suite de tests
```

**Étape 5 : Distribuer (Optionnel)**

```bash
# Rapide : script Lua bundle (nécessite Lua sur la cible)
lumos bundle src/main.lua -o dist/myapp

# Zéro dépendance : exécutable autonome via stub précompilé
lumos package src/main.lua -o dist/myapp

# Contrôle maximal : binaire natif avec VM Lua embarquée
lumos build src/main.lua -o dist/myapp

./dist/myapp --help
```

## Exemple de code CLI

```lua
local lumos = require('lumos')
local color = require('lumos.color')

local app = lumos.new_app({
    name = "my-awesome-cli",
    version = "0.3.2",
    description = "My awesome CLI application"
})

local greet = app:command("greet", "Greet someone")
greet:arg("name", "Name of person to greet")
greet:flag("-u --uppercase", "Use uppercase")
greet:flag("-c --colorful", "Use colors")

greet:action(function(ctx)
    local name = ctx.args[1] or "World"
    local message = "Hello, " .. name .. "!"

    if ctx.flags.uppercase then
        message = message:upper()
    end

    if ctx.flags.colorful then
        message = color.green(message)
    end

    print(message)
    return lumos.success({ greeted = name })
end)

app:run(arg)
```

## ⚡ Installation

### Prérequis
- Lua 5.1+ ou LuaJIT
- LuaRocks >= 3.9

### Option 1 : Depuis LuaRocks (Recommandé)
```bash
luarocks install --local lumos
echo 'export PATH="$HOME/.luarocks/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Option 2 : Installation système
```bash
sudo luarocks install lumos
```

### Option 3 : Installation développement
```bash
git clone https://github.com/benoitpetit/lumos.git
cd lumos
luarocks make --local lumos-dev-1.rockspec
```

### Vérifier l'installation
```bash
lumos version
# Devrait afficher : Lumos CLI Framework v0.3.2
```

## Fonctionnalités clés

### Commandes & Flags
```lua
local deploy = app:command("deploy", "Deploy application")
deploy:arg("environment", "Target environment")
deploy:flag("-f --force", "Force deployment")
deploy:option("--timeout", "Deployment timeout")
```

### Flags typés avancés
```lua
cmd:flag_int("-p --port", "Port number", { min = 1, max = 65535 })
cmd:flag_float("-r --rate", "Rate", { min = 0.0, max = 1.0, precision = 2 })
cmd:flag_array("-t --tags", "Tags", { separator = ",", unique = true })
cmd:flag_enum("-l --level", "Log level", {"debug", "info", "warn", "error"})
cmd:flag_path("-c --config", "Config file", { must_exist = true, extensions = {".json"} })
cmd:flag_url("--endpoint", "API endpoint", { schemes = {"https"} })
cmd:flag_email("--notify", "Notification email")
```

### Groupes mutuellement exclusifs
```lua
cmd:mutex_group("input", {
    cmd:flag_string("-f --file", "Input file"),
    cmd:flag_string("-u --url", "Input URL")
}, { required = true })
```

### Erreurs typées
```lua
cmd:action(function(ctx)
    if not file_exists(ctx.flags.config) then
        return lumos.error("CONFIG_ERROR", "Config file not found", {
            path = ctx.flags.config,
            suggestion = "Create it with 'lumos init'"
        })
    end
    return lumos.success({ deployed = true })
end)
```

### Middleware
```lua
app:use(lumos.middleware.logger())
app:use(lumos.middleware.dry_run())

app:command("deploy", "Deploy")
    :use(lumos.middleware.auth({ env_var = "API_KEY" }))
    :use(lumos.middleware.confirm({ message = "Deploy to production?" }))
    :use(lumos.middleware.rate_limit({ max_requests = 10, window_seconds = 60 }))
    :action(function(ctx) ... end)
```

### Composants UI riches
```lua
local color = require('lumos.color')
local progress = require('lumos.progress')
local prompt = require('lumos.prompt')

print(color.green("Success!"))
progress.simple(75, 100)
local name = prompt.input("Your name:", "Anonymous")
local confirmed = prompt.confirm("Continue?", true)
local choice = prompt.select("Choose", {"apple", "banana"})
```

### Détection multiplateforme
```lua
local platform = require('lumos.platform')
print(platform.name())        -- "linux", "macos", "windows"
print(platform.arch())        -- "amd64", "arm64"
platform.supports_colors()    -- booléen
platform.is_interactive()     -- booléen
platform.is_piped()           -- booléen (désactive auto couleurs)
```

### Gestion de configuration
```lua
local config = require('lumos.config')
local core = require('lumos.core')

local settings = config.merge_configs(
    {timeout = 30},                   -- defaults
    core.load_config("config.json"),  -- fichier JSON/key=value
    config.load_env("MYAPP"),         -- variables d'environnement
    ctx.flags                         -- ligne de commande
)

-- Avec cache en mémoire
local cached = config.load_file_cached("config.json")
```

### Profiling intégré
```lua
local profiler = require('lumos.profiler')
profiler.enable()
profiler.start(" heavy_task")
-- ... code ...
profiler.stop("heavy_task")
profiler.report()
```

### Bundles minimaux (tree-shaking)
```lua
local bundle = require('lumos.bundle')
bundle.minimal("src/main.lua", "dist/myapp.lua", { minify = true })
```

### Intégration shell
```lua
-- Générer auto-complétions
local completion = app:generate_completion("bash")

-- Générer pages man
local manpage = app:generate_manpage()

-- Générer documentation Markdown
local docs = app:generate_docs("markdown", "./docs")
```

### Sécurité & Logging
```lua
local security = require('lumos.security')
local logger = require('lumos.logger')

local safe = security.sanitize_output(user_input)
local path, err = security.sanitize_path(user_path)
local ok, err = security.safe_mkdir("./data")

logger.info("Action performed", {user = "john", id = 42})
```

### Prompts avancés
```lua
local prompt = require('lumos.prompt')

-- Saisie numérique contrainte
local age = prompt.number("Age", 0, 120)

-- Éditeur multi-lignes ($EDITOR ou notepad.exe sur Windows)
local notes = prompt.editor("Notes", "Default text...")

-- Constructeur de formulaire
local profile = prompt.form("Profile", {
    {name = "name", type = "input", required = true},
    {name = "email", type = "input", validate = prompt.validators.email},
    {name = "newsletter", type = "confirm", default = false}
})

-- Wizard
local result = prompt.wizard("Setup", {
    {title = "Profile", fields = {
        {name = "username", type = "input", required = true}
    }},
    {title = "Confirm", fields = {
        {name = "agree", type = "confirm", required = true}
    }}
})
```

### Plugins & Hooks
```lua
-- Plugin global
lumos.use("command", function(cmd, opts)
    cmd:flag("--dry-run", "Simulate without side effects")
end)

-- Ou attacher à une seule commande
app:command("deploy", "Deploy app")
    :use(function(cmd, opts)
        cmd:flag("--region", "Target region")
    end)

-- Hooks setup / teardown
app:command("migrate", "Run migrations")
    :pre_run(function(ctx)
        print("Connecting to database...")
    end)
    :post_run(function(ctx)
        print("Migration complete!")
    end)

-- Hooks globaux
app:persistent_pre_run(function(ctx)
    logger.info("Starting command", {cmd = ctx.command.name})
end)
```

## Documentation

La documentation complète est disponible dans le dossier `docs/` :

- **[Guide de démarrage rapide](docs/qs.md)** - Être opérationnel en 5 minutes
- **[Utilisation du CLI](docs/cli.md)** - Comment utiliser `lumos new`
- **[Référence API](docs/api.md)** - Documentation complète du framework
- **[Exemples d'utilisation](docs/use.md)** - Exemples CLI du monde réel
- **[Guide sécurité](docs/security.md)** - Fonctionnalités de sécurité et bonnes pratiques
- **[Guide bundling](docs/bundle.md)** - Création d'exécutables portables

## Exemples

Explorez de vraies applications CLI construites avec Lumos dans nos [Exemples d'utilisation](docs/use.md).

## Contribuer

Les contributions sont les bienvenues !

### Configuration développement
```bash
git clone https://github.com/benoitpetit/lumos.git
cd lumos

# Installer pour le développement
luarocks make --local lumos-dev-1.rockspec

# Lancer les tests
busted

# Tester la génération CLI
./bin/lumos new test-project
cd test-project
make install && make test
```

## Statut du projet

- **Version :** 0.3.2
- **Licence :** MIT
- **Versions Lua :** 5.1, 5.2, 5.3, 5.4, LuaJIT
- **Plateformes :** Linux, macOS, Windows natif
- **Tests :** 411 tests passants
- **Dépendances :** luafilesystem

## Remerciements

- Inspiré par le framework CLI [Cobra](https://cobra.dev/) pour Go
- Suit les [POSIX Utility Syntax Guidelines](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html)
- Construit avec soin pour la communauté Lua

## Licence

Ce projet est sous licence MIT — voir le fichier [LICENSE](LICENSE) pour les détails.

---

<p align="center">
    <strong>Lumos</strong> - <em>Apportant la lumière au développement CLI en Lua</em>
</p>
