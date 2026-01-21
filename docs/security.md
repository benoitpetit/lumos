# 🔒 Lumos Security Guide

Guide de sécurité et best practices pour l'utilisation de Lumos en production.

## 📋 Table des Matières

- [Vue d'ensemble](#vue-densemble)
- [Nouvelles Fonctionnalités de Sécurité](#nouvelles-fonctionnalités-de-sécurité)
- [Best Practices](#best-practices)
- [Protection contre les Vulnérabilités](#protection-contre-les-vulnérabilités)
- [Configuration Sécurisée](#configuration-sécurisée)
- [Audit et Monitoring](#audit-et-monitoring)
- [Checklist de Déploiement](#checklist-de-déploiement)

## 🎯 Vue d'ensemble

Lumos inclut désormais des fonctionnalités de sécurité robustes pour protéger vos applications CLI contre les vulnérabilités courantes.

### Modules de Sécurité

- **`lumos.security`** - Sanitisation et validation des entrées
- **`lumos.logger`** - Logging structuré pour l'audit

## 🆕 Nouvelles Fonctionnalités de Sécurité

### Module security.lua

Le module `security` fournit des fonctions pour sécuriser vos applications :

```lua
local security = require('lumos.security')

-- Échapper des arguments shell
local safe_arg = security.shell_escape(user_input)
os.execute("ls " .. safe_arg)

-- Valider des chemins
local path, err = security.sanitize_path(user_path)
if not path then
    print("Invalid path: " .. err)
    return
end

-- Ouvrir des fichiers de manière sécurisée
local file, err = security.safe_open(path, "r")
if not file then
    print("Cannot open file: " .. err)
    return
end

-- Valider des emails
local valid, err = security.validate_email(email)
if not valid then
    print("Invalid email: " .. err)
end

-- Valider des URLs
local valid, err = security.validate_url(url)
if not valid then
    print("Invalid URL: " .. err)
end

-- Rate limiting
local allowed, err = security.rate_limit("api_call", 10, 60)
if not allowed then
    print("Rate limit exceeded")
end
```

### Module logger.lua

Le module `logger` offre un logging structuré avec niveaux :

```lua
local logger = require('lumos.logger')

-- Différents niveaux de log
logger.error("Critical error occurred", {user = "admin", code = 500})
logger.warn("Deprecated feature used", {feature = "old_api"})
logger.info("User logged in", {user = "john", ip = "192.168.1.1"})
logger.debug("Cache miss", {key = "user:123"})
logger.trace("Function entry", {function = "process_data"})

-- Configuration
logger.set_level("INFO")  -- ou logger.LEVELS.INFO
logger.set_output("/var/log/myapp.log")
logger.set_timestamp(true)
logger.set_colors(true)

-- Configuration depuis l'environnement
logger.configure_from_env("MYAPP")  -- Lit MYAPP_LOG_LEVEL, etc.

-- Logger avec contexte fixe
local user_logger = logger.child({user = "john", session = "abc123"})
user_logger.info("Action performed")  -- Inclut automatiquement le contexte
```

## 🛡️ Best Practices

### 1. Validation des Entrées Utilisateur

**❌ MAUVAIS :**
```lua
local cmd = app:command("delete", "Delete file")
cmd:arg("file", "File to delete")
cmd:action(function(ctx)
    os.execute("rm " .. ctx.args[1])  -- DANGEREUX!
end)
```

**✅ BON :**
```lua
local security = require('lumos.security')
local logger = require('lumos.logger')

local cmd = app:command("delete", "Delete file")
cmd:arg("file", "File to delete")
cmd:action(function(ctx)
    local file_path, err = security.sanitize_path(ctx.args[1])
    if not file_path then
        logger.error("Invalid file path", {error = err, input = ctx.args[1]})
        print("Error: " .. err)
        return false
    end
    
    local escaped_path = security.shell_escape(file_path)
    local success = os.execute("rm " .. escaped_path)
    
    if success then
        logger.info("File deleted", {path = file_path})
        return true
    else
        logger.error("Failed to delete file", {path = file_path})
        return false
    end
end)
```

### 2. Gestion Sécurisée des Fichiers

**❌ MAUVAIS :**
```lua
local file = io.open(user_provided_path, "w")
file:write(data)
file:close()
```

**✅ BON :**
```lua
local security = require('lumos.security')
local logger = require('lumos.logger')

local file, err = security.safe_open(user_provided_path, "w")
if not file then
    logger.error("Cannot open file", {path = user_provided_path, error = err})
    print("Error: " .. err)
    return false
end

file:write(data)
file:close()
logger.info("File written successfully", {path = user_provided_path})
```

### 3. Logging Approprié

```lua
local logger = require('lumos.logger')

-- Log des actions importantes
cmd:action(function(ctx)
    logger.info("Command executed", {
        command = ctx.command.name,
        user = os.getenv("USER"),
        args = ctx.args,
        flags = ctx.flags
    })
    
    -- Votre logique métier...
    
    if error_occurred then
        logger.error("Operation failed", {
            command = ctx.command.name,
            error = error_message,
            details = error_details
        })
    end
end)
```

### 4. Protection contre l'Escalade de Privilèges

```lua
local security = require('lumos.security')
local logger = require('lumos.logger')

-- Vérifier si on tourne avec des privilèges élevés
if security.is_elevated() then
    logger.warn("Running with elevated privileges", {
        user = os.getenv("USER"),
        uid = os.getenv("UID")
    })
    
    print("⚠️  Warning: Running as root/administrator")
    print("This is not recommended for this command.")
    
    -- Demander confirmation
    local prompt = require('lumos.prompt')
    if not prompt.confirm("Continue anyway?", false) then
        return false
    end
end
```

## 🔐 Protection contre les Vulnérabilités

### Injection de Commandes Shell

**Problème :** Exécution de commandes arbitraires via des entrées malveillantes.

**Solution :**
```lua
local security = require('lumos.security')

-- Toujours échapper les arguments
local safe_filename = security.shell_escape(filename)
os.execute("cat " .. safe_filename)

-- Ou utiliser des chemins validés
local path, err = security.sanitize_path(filename)
if path then
    os.execute("cat " .. security.shell_escape(path))
end
```

### Path Traversal

**Problème :** Accès à des fichiers en dehors du répertoire autorisé.

**Solution :**
```lua
local security = require('lumos.security')

-- Valider le chemin
local path, err = security.sanitize_path(user_path)
if not path then
    print("Invalid path: " .. err)
    return false
end

-- Vérifier que le chemin est dans le répertoire autorisé
local allowed_dir = "/var/app/data/"
if not path:match("^" .. allowed_dir) then
    logger.warn("Path traversal attempt", {path = path})
    print("Access denied: path outside allowed directory")
    return false
end
```

### Injection de Code dans les Prompts

**Problème :** Séquences d'échappement malveillantes dans les entrées.

**Solution :**
```lua
local security = require('lumos.security')
local prompt = require('lumos.prompt')

local input = prompt.input("Enter name")
local safe_input = security.sanitize_output(input)

-- Utiliser safe_input au lieu de input
print("Hello, " .. safe_input)
```

### Rate Limiting

**Problème :** Abus de ressources par des appels répétés.

**Solution :**
```lua
local security = require('lumos.security')

local cmd = app:command("api-call", "Call external API")
cmd:action(function(ctx)
    local allowed, err = security.rate_limit("api_call", 10, 60)
    if not allowed then
        logger.warn("Rate limit exceeded", {command = "api-call"})
        print("Error: Too many requests. Please wait.")
        return false
    end
    
    -- Appel API...
end)
```

## ⚙️ Configuration Sécurisée

### Variables d'Environnement

```bash
# Logging
export LUMOS_LOG_LEVEL=INFO
export LUMOS_LOG_FILE=/var/log/myapp.log
export LUMOS_LOG_TIMESTAMP=true

# Désactiver les couleurs en production
export LUMOS_NO_COLOR=1

# Mode debug (inclut stacktraces)
export LUMOS_DEBUG=1
```

### Permissions des Fichiers

```bash
# Fichiers de configuration
chmod 600 config.json

# Répertoires de données
chmod 700 /var/app/data

# Logs
chmod 640 /var/log/myapp.log
chown app:log /var/log/myapp.log
```

### Chargement Sécurisé de la Configuration

```lua
local config = require('lumos.config')
local security = require('lumos.security')
local logger = require('lumos.logger')

-- Valider le chemin du fichier config
local config_path = os.getenv("APP_CONFIG") or "./config.json"
local validated_path, err = security.sanitize_path(config_path)

if not validated_path then
    logger.error("Invalid config path", {path = config_path, error = err})
    os.exit(1)
end

-- Charger la config
local cfg, load_err = config.load_file(validated_path)
if not cfg then
    logger.error("Failed to load config", {error = load_err})
    os.exit(1)
end

logger.info("Configuration loaded", {path = validated_path})
```

## 📊 Audit et Monitoring

### Logging des Événements de Sécurité

```lua
local logger = require('lumos.logger')

-- Connexions/Authentifications
logger.info("User authenticated", {
    user = username,
    method = "password",
    ip = remote_ip
})

-- Tentatives d'accès refusées
logger.warn("Access denied", {
    user = username,
    resource = resource_path,
    reason = "insufficient_permissions"
})

-- Modifications sensibles
logger.info("Configuration changed", {
    user = username,
    file = config_file,
    changes = changed_keys
})

-- Erreurs de sécurité
logger.error("Security violation detected", {
    type = "path_traversal",
    user = username,
    input = malicious_input
})
```

### Format de Log Structuré

Les logs sont au format :
```
2026-01-21 14:30:45 [ERROR] Security violation detected [type=path_traversal user=john input=../../etc/passwd]
```

Facilement parsables avec des outils comme `jq`, `grep`, ou des systèmes de log centralisés (ELK, Splunk, etc.).

## ✅ Checklist de Déploiement

### Avant de Déployer en Production

- [ ] Toutes les entrées utilisateur sont validées avec `security.sanitize_*`
- [ ] Les commandes shell utilisent `security.shell_escape()`
- [ ] Les fichiers sont ouverts avec `security.safe_open()`
- [ ] Le logging est configuré avec des niveaux appropriés
- [ ] Les événements de sécurité sont loggés
- [ ] Les permissions des fichiers sont correctes (600/700)
- [ ] Le mode debug est désactivé (`LUMOS_DEBUG` non défini)
- [ ] Les stacktraces ne sont pas exposées aux utilisateurs
- [ ] Rate limiting est implémenté pour les opérations coûteuses
- [ ] Les dépendances sont à jour (`luarocks list`)
- [ ] Les tests de sécurité passent (`busted spec/security_spec.lua`)

### Monitoring Continu

- [ ] Les logs sont collectés et analysés régulièrement
- [ ] Les alertes sont configurées pour les événements critiques
- [ ] Les métriques de performance sont suivies
- [ ] Les tentatives d'intrusion sont détectées
- [ ] Les mises à jour de sécurité sont appliquées rapidement

## 🚨 En Cas d'Incident de Sécurité

1. **Isoler** : Arrêter l'application si nécessaire
2. **Analyser** : Examiner les logs avec `logger`
3. **Contenir** : Identifier et bloquer la source
4. **Corriger** : Patcher la vulnérabilité
5. **Vérifier** : Tester la correction
6. **Documenter** : Créer un post-mortem

### Analyse des Logs

```bash
# Chercher des tentatives de path traversal
grep "path_traversal" /var/log/myapp.log

# Chercher des erreurs de sécurité
grep "\[ERROR\]" /var/log/myapp.log | grep -i security

# Analyse des rate limits dépassés
grep "Rate limit exceeded" /var/log/myapp.log

# Tentatives d'accès refusées
grep "Access denied" /var/log/myapp.log
```

## 📚 Ressources Complémentaires

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE - Common Weakness Enumeration](https://cwe.mitre.org/)
- [Lua Security Considerations](https://www.lua.org/pil/8.1.html)

## 🔄 Mises à Jour

Ce guide de sécurité est mis à jour régulièrement. Consultez-le avant chaque déploiement majeur.

---

**Version du Guide :** 1.0  
**Dernière mise à jour :** 21 janvier 2026  
**Framework Lumos :** v0.1.0+
