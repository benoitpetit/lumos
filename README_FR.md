# Lumos CLI Framework

<p align="center">
    <img src="assets/lumosb&wclear.png" alt="Lumos Logo" width="250">
</p>

<p align="center">
    <strong>Un framework CLI moderne pour Lua</strong><br>
    Construisez des applications en ligne de commande puissantes avec simplicité
</p>

<p align="center">
    <a href="docs/qs.md">Démarrage Rapide</a> &bull;
    <a href="docs/api.md">Docs API</a> &bull;
    <a href="docs/use.md">Exemples</a> &bull;
    <a href="#installation">Installer</a>
</p>

---
> 💡 **Lumos est activement développé.** Si vous rencontrez un bug ou avez une suggestion, n'hésitez pas à [ouvrir une issue](https://github.com/benoitpetit/lumos/issues/new) — nous lisons tout.


**Lumos** (du latin "lumière") apporte de la clarté au développement CLI en Lua. Inspiré par Cobra pour Go, il fournit tout ce dont vous avez besoin pour construire des applications en ligne de commande professionnelles avec un minimum de code et un maximum de fonctionnalités.

## Ce qui rend Lumos spécial

- **Générateur de projet** - `lumos new` crée des projets CLI complets en quelques secondes
- **API intuitive** - Méthodes fluides et chaînables pour définir commandes et flags
- **Conformité POSIX** - Supporte `--` (fin des options) et `-abc` (flags courts combinés)
- **Composants UI riches** - Couleurs, barres de progression, prompts, tableaux
- **Chaîne de middleware** - Middleware style Express avec auth, dry-run, retry, rate-limiting, etc.
- **Flags avancés** - int, float, array, enum, path, url, email avec validation intégrée
- **Flags cachés et dépréciés** - Faites évoluer votre CLI sans casser vos utilisateurs
- **Intégration shell** - Auto-complétion, pages man, génération de documentation
- **Gestion de configuration** - Fichiers JSON, TOML, et key=value, variables d'environnement, cache intégré
- **Prêt pour les tests** - Les projets générés incluent Busted et un fichier de test de démarrage
- **Dépendances minimales** - Nécessite seulement `luafilesystem`, architecture modulaire
- **Multi-plateforme** - Linux, macOS, et Windows natif avec détection automatique
- **Bundles portables** - Créez des scripts Lua autonomes avec `lumos bundle`
- **Packages autonomes** - Créez des exécutables sans dépendances avec `lumos package`
- **Builds natifs** - Compilez en binaires natifs avec `lumos build` (embarque la VM Lua)
- **Sécurité intégrée** - Assainissement des entrées, opérations fichiers sécurisées, rate limiting
- **Logging structuré** - 5 niveaux de log avec loggers enfants et configuration via environnement
- **Client HTTP natif** - GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS avec backend curl
- **Chargement paresseux** - Chargement des modules à la demande pour un démarrage rapide (< 30ms)

## Démarrage rapide en 5 minutes

### TL;DR

```bash
# Installez Lumos depuis LuaRocks
luarocks install --local lumos

# Créez votre première application CLI
lumos new hello-world && cd hello-world

# Lancez-la !
lua src/main.lua greet "CLI Master"
# Sortie : Hello, CLI Master!
```

### Guide étape par étape

**Étape 1 : Installer Lumos**
```bash
luarocks install --local lumos

# Ajoutez au PATH si nécessaire
echo 'export PATH="$HOME/.luarocks/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Étape 2 : Créer votre projet CLI**
```bash
lumos new my-awesome-cli
# Suivez les prompts interactifs
cd my-awesome-cli
```

**Étape 3 : Tester votre CLI**
```bash
lua src/main.lua --help        # Voir l'aide générée
lua src/main.lua greet World   # Essayer la commande exemple
```

**Étape 4 : Développer & tester**
```bash
make install  # Installer les dépendances de test
make test     # Lancer la suite de tests
```

**Étape 5 : Distribuer votre CLI (optionnel)**

```bash
# Rapide : script Lua bundlé (nécessite Lua sur la cible)
lumos bundle src/main.lua -o dist/myapp

# Zéro dépendance : package autonome utilisant un launcher précompilé
lumos package src/main.lua -o dist/myapp

# Cibler un OS différent (ex: Windows depuis Linux)
lumos package src/main.lua -o dist/myapp -t windows-x86_64

# Voir les cibles package disponibles dans votre installation
lumos package --list-targets

# (Optionnel) Télécharger les launchers manquants
lumos package --sync-runtime --list-targets

# Contrôle maximal : binaire natif avec VM Lua embarquée
lumos build src/main.lua -o dist/myapp

# Cross-compilation Windows depuis Linux
lumos build src/main.lua -o dist/myapp -t windows-x86_64

# Pour macOS depuis Linux, utilisez les launchers package
lumos package src/main.lua -o dist/myapp -t darwin-aarch64

./dist/myapp --help
```

## Exemple de code CLI

```lua
local lumos = require('lumos')
local color = require('lumos.color')

local app = lumos.new_app({
    name = "my-awesome-cli",
    version = "0.3.7",
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

## Installation

### Prérequis
- Lua 5.1+ ou LuaJIT
- LuaRocks >= 3.8

### Option 1 : Depuis LuaRocks (Recommandé)
```bash
luarocks install --local lumos

# Ajoutez au PATH si nécessaire
echo 'export PATH="$HOME/.luarocks/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Option 2 : Installation système
```bash
sudo luarocks install lumos
```

### Option 3 : Installation de développement
```bash
git clone https://github.com/benoitpetit/lumos.git
cd lumos
luarocks make --local lumos-dev-1.rockspec
```

### Vérifier l'installation
```bash
lumos version
# Devrait afficher : Lumos CLI Framework v0.3.7
```

## Le runtime & modèle de distribution

Lumos inclut un répertoire **`runtime/`** contenant tout le nécessaire pour bundler, packager ou builder votre CLI sans dépendances externes :

- **Launchers précompilés** (`runtime/lumos-launcher-<os>-<arch>`) : Binaires autonomes embarquant un interpréteur Lua. Utilisés par `lumos package` pour créer des exécutables sans dépendances et sans compilateur C.
- **Librairies statiques & headers** (`runtime/lib/<plateforme>/liblua.a` + `include/*.h`) : Toolchains de cross-compilation fournies avec Lumos. `lumos build` les préfère aux librairies système pour garantir la compatibilité de version, notamment en cross-compilation (ex: Windows depuis Linux). Elles servent aussi de fallback si les paquets de développement Lua système ne sont pas installés.
- **`launcher.c`** : Code source du launcher, utile pour des builds personnalisés ou l'audit.

Tous ces éléments sont installés automatiquement avec `luarocks install lumos` ou `luarocks make`.

### Trois façons de distribuer votre CLI

| Méthode | Commande | Sortie | Lua requis sur cible ? | Compilateur C requis ? | Modules C natifs |
|---------|----------|--------|------------------------|------------------------|------------------|
| **Bundle** | `lumos bundle` | Script `.lua` unique | ✅ Oui | ❌ Non | ❌ Non |
| **Package** | `lumos package` | Exécutable natif | ❌ Non | ❌ Non | ❌ Non (échoue si détectés) |
| **Build** | `lumos build` | Binaire natif | ❌ Non | ✅ Oui | ✅ Oui (`liblua.a` toujours fourni ; modules C utilisateur comme `lfs`/`lpeg` si `.a` trouvées) |

- **`bundle`** est le plus rapide et le plus portable parmi les utilisateurs Lua.
- **`package`** produit un binaire natif **sans compilateur C requis** sur la machine de build, grâce aux launchers précompilés.
- **`build`** offre le contrôle maximal : il compile un binaire natif embarquant la VM Lua, et peut linker statiquement des modules C comme `lfs` ou `lpeg` si leurs archives `.a` sont disponibles.

### Cross-compilation

`lumos package` fonctionne depuis n'importe quel hôte vers n'importe quelle cible car il utilise des launchers précompilés :

```bash
# Depuis Linux, packager pour Windows ou macOS
lumos package src/main.lua -t windows-x86_64
lumos package src/main.lua -t darwin-aarch64
```

`lumos build` compile un binaire natif et nécessite un cross-compilateur adapté :

| Depuis → Vers | Supporté | Outil requis |
|---------------|----------|--------------|
| Linux → Windows | ✅ Oui | `x86_64-w64-mingw32-gcc` (mingw-w64) |
| Linux → Linux ARM64 | ✅ Oui | `aarch64-linux-gnu-gcc` |
| Linux → macOS | ❌ Non* | Installer [osxcross](https://github.com/tpoechtrager/osxcross) pour débloquer |
| macOS → Tout | ✅ Oui | Xcode Command Line Tools |

\* Depuis Linux, utilisez `lumos package -t darwin-*` à la place pour les cibles macOS.

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
cmd:flag_int("-p --port", "Port number", 1, 65535)
cmd:flag_float("-r --rate", "Rate", { min = 0.0, max = 1.0, precision = 2 })
cmd:flag_array("-t --tags", "Tags", { separator = ",", unique = true })
cmd:flag_enum("-l --level", "Log level", {"debug", "info", "warn", "error"})
cmd:flag_path("-c --config", "Config file", { must_exist = true, extensions = {".json", ".toml"} })
cmd:flag_url("--endpoint", "API endpoint", { schemes = {"https"} })
cmd:flag_email("--notify", "Notification email")
```

### Flags courts combinés (POSIX)
```bash
myapp deploy -fvt production
# Équivalent à : myapp deploy -f -v -t production
```

### Délimiteur de fin d'options
```bash
myapp rm -- -file-starting-with-dash
# Traite -file-starting-with-dash comme un argument positionnel, pas un flag
```

### Flags mutuellement exclusifs
```lua
cmd:flag_string("-f --file", "Input file")
cmd:flag_string("-u --url", "Input URL")
cmd:mutex_group("input", {"file", "url"}, { required = true })
```

### Commandes et flags cachés / dépréciés
```lua
-- Cacher une commande de l'aide (visible uniquement avec LUMOS_DEBUG=1)
cmd:hidden(true)

-- Marquer un flag comme déprécié
cmd:flag("--legacy-mode", "Old mode")
    :deprecated("Use --modern-mode instead")
```

### Erreurs typées
```lua
cmd:action(function(ctx)
    if not file_exists(ctx.flags.config) then
        return lumos.new_error("CONFIG_ERROR", "Config file not found", {
            path = ctx.flags.config,
            suggestion = "Create it with 'lumos init'"
        })
    end
    return lumos.success({ deployed = true })
end)
```

### Middleware
```lua
app:use(lumos.middleware.builtin.logger())
app:use(lumos.middleware.builtin.dry_run())
app:use(lumos.middleware.builtin.verbosity())  -- Standard -v / -vv / -vvv

app:command("deploy", "Deploy")
    :use(lumos.middleware.builtin.auth({ env_var = "API_KEY" }))
    :use(lumos.middleware.builtin.confirm({ message = "Deploy to production?" }))
    :use(lumos.middleware.builtin.rate_limit({ max_requests = 10, window_seconds = 60 }))
    :use(lumos.middleware.builtin.retry({ max_attempts = 3, backoff = "exponential" }))
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

### Détection multi-plateforme
```lua
local platform = require('lumos.platform')
print(platform.name())        -- "linux", "macos", "windows"
print(platform.arch())        -- "amd64", "arm64"
platform.supports_colors()    -- boolean
platform.is_interactive()     -- boolean
platform.is_piped()           -- boolean (désactive automatiquement les couleurs)
```

### Gestion de configuration
```lua
local config = require('lumos.config')
local core = require('lumos.core')

-- Supporte JSON, TOML, et key=value
local settings = config.merge_configs(
    {timeout = 30},                   -- valeurs par défaut
    core.load_config("config.toml"),  -- fichier (JSON, TOML, ou key=value)
    config.load_env("MYAPP"),         -- variables d'environnement
    ctx.flags                         -- ligne de commande
)

-- Avec cache mémoire
local cached = config.load_file_cached("config.json")
```

### Profiling intégré
```lua
local profiler = require('lumos.profiler')
profiler.enable()
profiler.start("heavy_task")
-- ... code ...
profiler.stop("heavy_task")
profiler.report()
```

### Bundles minimaux (Tree-Shaking)
```lua
local bundle = require('lumos.bundle')
bundle.minimal("src/main.lua", "dist/myapp.lua", { minify = true })
```

### Intégration shell
```lua
-- Générer les completions
local completion = app:generate_completion("bash")

-- Générer les pages man
local manpage = app:generate_manpage()

-- Générer la documentation markdown
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

### Client HTTP natif
```lua
local http = require('lumos.http')

-- GET avec paramètres de requête
local resp, err = http.get("https://api.example.com/users", {
    query = {page = "1", limit = "10"}
})

-- POST avec body JSON (encodage automatique)
local resp, err = http.post("https://api.example.com/users", {
    body = {name = "Alice", email = "alice@example.com"},
    headers = {["X-Request-ID"] = "abc123"}
})

-- Requête authentifiée
local resp, err = http.put("https://api.example.com/users/1", {
    body = {name = "Bob"},
    auth = {bearer = "my_api_token"},
    timeout = 10
})

-- Helpers de réponse
if resp and resp.ok then
    local data = resp.json()
    print(data.id)
end
```

### Prompts avancés
```lua
local prompt = require('lumos.prompt')

-- Entrée numérique avec contraintes
local age = prompt.number("Age", 0, 120)

-- Éditeur multi-lignes ($EDITOR ou notepad.exe sur Windows)
local notes = prompt.editor("Notes", "Default text...")

-- Constructeur de formulaires
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

### Contrôle du format de sortie
```bash
# Obtenir une sortie JSON structurée
myapp info --format=json
# ou
myapp info --json
```

### Plugins & Hooks
```lua
-- Enregistrer un plugin globalement sur l'app
lumos.use(app, function(app, opts)
    app:flag("--dry-run", "Simulate without side effects")
end)

-- Ou attacher à une seule commande
app:command("deploy", "Deploy app")
    :plugin(function(cmd, opts)
        cmd:flag("--region", "Target region")
    end)

-- Hooks pour setup / teardown
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

### No-Args-Is-Help
```lua
local app = lumos.new_app({
    name = "myapp",
    no_args_is_help = true  -- Affiche l'aide au lieu d'une erreur quand aucune sous-commande n'est donnée
})
```

## Documentation

La documentation complète est disponible dans le répertoire `docs/` :

- **[Guide de démarrage rapide](docs/qs.md)** - Soyez opérationnel en 5 minutes
- **[Utilisation de l'outil CLI](docs/cli.md)** - Comment utiliser `lumos new` pour créer des projets
- **[Référence API](docs/api.md)** - Documentation complète de l'API du framework
- **[Exemples d'utilisation](docs/use.md)** - Exemples CLI réels et patterns
- **[Guide de sécurité](docs/security.md)** - Fonctionnalités de sécurité et bonnes pratiques
- **[Guide de bundling](docs/bundle.md)** - Créer des exécutables autonomes en un seul fichier

## Exemples

Explorez de vraies applications CLI construites avec Lumos dans nos [Exemples d'utilisation](docs/use.md).

## Contribuer

Les contributions sont les bienvenues !

### Configuration de développement
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

- **Version :** 0.3.7
- **Licence :** MIT
- **Versions Lua :** 5.1, 5.2, 5.3, 5.4, LuaJIT
- **Plateformes :** Linux, macOS, Windows (natif)
- **Tests :** 455 tests passants
- **Dépendances :** luafilesystem

## Remerciements

- Inspiré par le framework CLI [Cobra](https://cobra.dev/) pour Go
- Suit les [POSIX Utility Syntax Guidelines](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html)
- Construit avec soin pour la communauté Lua

## Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.

---

<p align="center">
    <strong>Lumos</strong> - <em>Apportant la lumière au développement CLI en Lua</em>
</p>
