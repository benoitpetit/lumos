# Changelog

All notable changes to the Lumos CLI framework are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Lumos uses [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added
- `lumos/security.lua` — new security module with `shell_escape`, `sanitize_path`,
  `safe_open`, `safe_mkdir`, `validate_email`, `validate_url`, `validate_integer`,
  `sanitize_command_name`, `sanitize_output`, `is_elevated`, and `rate_limit`
- `lumos/logger.lua` — new structured logging module with five levels (ERROR/WARN/INFO/DEBUG/TRACE),
  context key-value pairs, configurable timestamps and colours, environment-variable
  configuration, output redirection, and child loggers
- `spec/logger_spec.lua` — 30 unit tests for the logger module
- `spec/config_spec.lua` — 17 unit tests for configuration file loading
- `spec/bundle_spec.lua` — 11 unit tests for application bundling
- Extended `spec/core_advanced_spec.lua` with 16 tests covering argument parsing,
  command execution, help display, and config loading
- Extended `spec/json_spec.lua` with 13 decode tests including nested objects and
  error handling
- Extended `spec/app_spec.lua` with 5 `app:run()` scenario tests
- `make test-coverage` target (requires `luacov`)

### Changed
- `.busted` — local module path now takes priority over `~/.luarocks` so the source
  under test is always loaded instead of any previously installed version
- `Makefile` — `busted` binary is resolved at build time via `which busted` rather
  than a hard-coded `~/.luarocks/bin/busted` path
- `lumos/logger.lua` — `set_output` now accepts table-type handles (enables
  in-memory capture mocks in tests)
- `lumos/core.lua` — `execute_command` uses `rawget(cmd, 'action')` instead of
  `cmd.action` so that the `Command:action` setter method inherited from the
  metatable is not mistaken for a user-provided action callback
- `lumos/bundle.lua` — all `os.execute` calls now pass arguments through
  `security.shell_escape` to prevent shell injection
- `lumos/bundle.lua` — file operations use `security.safe_open` instead of raw
  `io.open`
- `lumos/config.lua` — file operations use `security.safe_open`; extracted
  `parse_key_value()` as a public function to avoid duplicate parsing logic in
  `core.lua`
- `lumos/core.lua` — delegates key-value config parsing to `config.parse_key_value()`
- `lumos/app.lua` — renamed local variable `config` to `config_module` to eliminate
  shadowing of the `config` parameter in `new_app`
- `spec/bundle_spec.lua` — temporary output directory now uses
  `os.tmpname() .. "_d"` to avoid a conflict with the empty file that
  `os.tmpname()` creates on Linux
- `spec/app_spec.lua`, `spec/core_advanced_spec.lua` — `print` mocks now target
  `_G.print` directly so that modules loaded via `require` (which use `_G`) see
  the mock

### Fixed
- `lumos/color.lua` — incorrect Lua regex pattern for ANSI escape stripping
- `lumos/format.lua` — incorrect Lua regex pattern for word-wrap logic
- `lumos/security.lua` — invalid character class in `sanitize_output` ANSI regex
- `lumos/init.lua` — inconsistent indentation
- `lumos-0.1.0-1.rockspec` — missing `lumos.security` and `lumos.logger` module
  entries

---

## [0.1.0] — Initial Release

### Added
- Core CLI framework inspired by Cobra (Go)
- `lumos/app.lua` — application and command builder with fluent API
- `lumos/core.lua` — argument parsing, command execution, and help display
- `lumos/flags.lua` — POSIX flag parsing with type validation
- `lumos/config.lua` — JSON and key-value configuration file support
- `lumos/json.lua` — pure-Lua JSON encoder/decoder
- `lumos/color.lua` — ANSI colour and style helpers
- `lumos/format.lua` — text formatting utilities
- `lumos/progress.lua` — progress bar display
- `lumos/loader.lua` — spinner/loading animation
- `lumos/prompt.lua` — interactive user prompts
- `lumos/table.lua` — boxed table rendering
- `lumos/bundle.lua` — standalone application bundler
- `lumos/completion.lua` — shell completion generation (bash, zsh, fish)
- `lumos/manpage.lua` — man page generation
- `lumos/markdown.lua` — Markdown documentation generation
- `lumos/init.lua` — top-level `require('lumos')` entry point
- Rockspec files for development (`lumos-dev-1.rockspec`) and production
  (`lumos-0.1.0-1.rockspec`)
- Initial test suite with 8 spec files
