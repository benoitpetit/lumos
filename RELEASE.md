# Lumos Release Guide

This document outlines the release process for Lumos CLI Framework.

## Version Management

Lumos uses semantic versioning (MAJOR.MINOR.PATCH):
- **MAJOR**: Breaking changes to the API
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

Current version: **0.1.0** (stored in `VERSION` file)

## Rockspec Files

The project maintains two rockspec files:

### 1. `lumos-dev-1.rockspec` (Development)
- Used for local development and testing
- Points to local directory (`.`)
- Uses current working directory files
- Install with: `luarocks make --local lumos-dev-1.rockspec`

### 2. `lumos-0.1.0-1.rockspec` (Production)
- Used for installation from GitHub
- Points to `main` branch on GitHub
- Used when project is published online
- Install with: `luarocks make --local lumos-0.1.0-1.rockspec`

## Release Process

### 1. Pre-release Checklist
- [ ] All tests passing: `make test`
- [ ] Code coverage acceptable: `busted --coverage`
- [ ] Examples working: `make examples`
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped in:
  - [ ] `VERSION` file
  - [ ] `bin/lumos` (version string)
  - [ ] Production rockspec filename and content

### 2. Create Release
```bash
# 1. Update version files
echo "1.1.0" > VERSION

# 2. Update bin/lumos version
sed -i 's/version = "0.1.0"/version = "1.1.0"/' bin/lumos
sed -i 's/v0.1.0/v1.1.0/' bin/lumos

# 3. Create new production rockspec
cp lumos-0.1.0-1.rockspec lumos-1.1.0-1.rockspec
sed -i 's/0.1.0/1.1.0/g' lumos-1.1.0-1.rockspec
sed -i 's/v0.1.0/v1.1.0/g' lumos-1.1.0-1.rockspec

# 4. Test the release
make install-prod
make test

# 5. Commit and tag
git add .
git commit -m "Release v1.1.0"
git tag -a v1.1.0 -m "Version 1.1.0"
git push origin main
git push origin v1.1.0
```

### 3. Post-release
- [ ] Upload to LuaRocks: `luarocks upload lumos-1.1.0-1.rockspec`
- [ ] Update documentation site
- [ ] Announce release on relevant channels

## Development Workflow

### Daily Development
```bash
# Use development rockspec
make install          # installs lumos-dev-1.rockspec
make test
```

### Testing Production Build
```bash
# Test production rockspec
make install-prod     # installs lumos-0.1.0-1.rockspec
make test
```

### Installation Options

| Command | Rockspec | Purpose |
|---------|----------|---------|
| `make install` | `lumos-dev-1.rockspec` | Development |
| `make install-prod` | `lumos-0.1.0-1.rockspec` | Production testing |
| `make setup` | `lumos-dev-1.rockspec` | Full system setup |

## File Structure

```
lumos/
├── VERSION                    # Current version number
├── .lumos                     # Project configuration
├── lumos-dev-1.rockspec      # Development rockspec
├── lumos-0.1.0-1.rockspec    # Production rockspec (versioned)
├── bin/lumos                  # CLI executable
├── lumos/                     # Framework source code
├── scripts/install.sh         # Installation script
├── Makefile                   # Build automation
└── RELEASE.md                 # This file
```

## Troubleshooting

### Common Issues

1. **Rockspec validation fails**
   ```bash
   make check-rockspec
   ```

2. **Version mismatch**
   - Check `VERSION` file
   - Check `bin/lumos` version strings
   - Check rockspec version and tag

3. **Installation fails**
   - Verify dependencies: `lua >= 5.1`, `luafilesystem >= 1.6.3`
   - Check LuaRocks configuration
   - Test with `make install` first

### Recovery

If a release has issues:
1. Fix the issues in a new commit
2. Create a patch release (e.g., 1.0.1)
3. Follow the normal release process
