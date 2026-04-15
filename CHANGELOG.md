# Changelog

All notable changes to the Lumos CLI framework are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Lumos uses [Semantic Versioning](https://semver.org/).

---

## [0.2.1] — 2026-04-15

### Fixed

- `lumos/core.lua` — Replaced `goto continue` with `repeat … until true` loops to restore Lua 5.1 compatibility.
- `lumos/core.lua` — Wrapped `xpcall` arguments in closures to work around Lua 5.1's inability to pass extra arguments to `xpcall`.
- CI workflow — Added `luarocks make lumos-dev-1.rockspec` so GitHub Actions runners correctly resolve `require('lumos')`.
- `spec/package_spec.lua` — Skipped Linux stub binary execution on macOS to prevent `cannot execute binary file` failures on `macos-latest` runners.

## [0.2.0] — 2026-04-15

### Added

- `lumos/app.lua` — `Command:pre_run()`, `Command:post_run()`,
  `Command:persistent_pre_run()`, `app:persistent_pre_run()`, and
  `app:persistent_post_run()` hooks for per-command and global setup / teardown.
- `lumos/core.lua` — Standard exit codes `EXIT_OK`, `EXIT_ERROR`, and
  `EXIT_USAGE`; all error paths now write to `io.stderr` and `app:run()`
  returns an exit code.
- `lumos/core.lua` — Levenshtein-based command suggestions with
  "Did you mean?" output when an unknown command is entered.
- `lumos/app.lua` — `Command:category(name)` for grouping commands in help
  output.
- `lumos/app.lua` — Fluent flag modifiers: `:default()`, `:required()`,
  `:env()`, and `:validate()` can be chained directly after any flag definition.
- `lumos/app.lua` — `Command:arg(name, description, options)` now supports
  positional argument validation with `required`, `type`, `min`, `max`,
  `default`, and custom `validate` functions.
- `lumos/plugin.lua` — New plugin system with `lumos.use(target, plugin, opts)`
  and chainable `Command:use(plugin, opts)`.
- `lumos/config.lua` — Schema validation via `config.validate_schema()` and
  `config.load_validated()`.
- `lumos/table.lua` — Table pagination with `tbl.paginate()` and `tbl.page()`.
- `bin/lumos` — New `lumos doctor` command for diagnosing the local environment.
- `.github/workflows/test.yml` — GitHub Actions CI with a matrix of Lua
  5.1–5.4 and LuaJIT on Ubuntu and macOS.

### Fixed

**Critical**

- `lumos/bundle.lua` (L.353) — Bundle cache hit always reported 0 bundled modules
  because the pattern `_BUNDLED_MODULES%[%` failed to match the generated code.
  Corrected to `_BUNDLED_MODULES%[%"`.
- `lumos/package.lua` (L.114) — `lfs.dir()` called before LuaFileSystem was
  initialised; replaced with `get_lfs().dir()`.
- `lumos-0.1.0-1.rockspec` / `lumos-dev-1.rockspec` — `lumos.native_build` and
  `lumos.package` were missing from `build.modules`.
- `lumos/app.lua` (L.380) — `-v` short flag for the built-in version banner now
  detects collisions with user-defined flags: if the user has already claimed `-v`
  in `persistent_flags` or `global_flags`, the banner no longer registers its own
  `-v` shorthand.

**Medium**

- `lumos/flags.lua` — `int` validator returned `nil` instead of `false` when
  `tonumber()` failed; fixed with `num ~= nil and ...` explicit boolean return.
- `lumos/flags.lua` — Range-check block now guarded by `type == "int" or
  type == "number"` to prevent string/number comparison crash on other types.
- `lumos/flags.lua` — Negative numbers (e.g. `-5`) were incorrectly treated as
  flags; pattern changed from `^%-%-?` to `^%-%-?[%a_]` so numeric tokens are
  left as values.
- `lumos/logger.lua` — `set_output()` now closes the previous file handle before
  opening a new one, fixing a file-descriptor leak.
- `lumos/logger.lua` — `child()` filter pattern `^[a-z]+$` widened to
  `^[a-z][a-z_]*$` so methods containing underscores (e.g. `set_level`,
  `configure_from_env`) are correctly copied to child loggers.
- `lumos/core.lua` — `execute_command` upgraded from `pcall` to `xpcall` with a
  proper error handler that captures the full traceback; traceback is shown only
  in debug mode, giving users a clean error message otherwise.
- `lumos/config.lua` — Added a Windows guard (checks `package.config`) before
  calling `io.popen("env")`; key-value parse pattern hardened to `[^=\n]+`.
- `lumos/completion.lua` — Bash completion function name was hardcoded to
  `_lumos_completions`; it is now derived from the app name
  (`_%s_completions` with non-word chars replaced by `_`).
- `lumos/bundle.lua` — `LUMOS_MODULES` list was missing `lumos.native_build`
  and `lumos.package`.

**Minor**

- `lumos/native_build.lua` — Build steps were misnumbered (step 5 duplicated);
  steps reordered to: 3=toolchain, 4=output path, 5=native modules,
  6=C wrapper, 7=compile.
- `lumos/manpage.lua` — Dash escaping now applied globally to all text via a
  single `text:gsub("%-", "\\-")`, replacing the previous two partial substitutions
  that left some hyphens un-escaped.
- `lumos/markdown.lua` — `generate_command()` now inserts `## Reference` before
  delegating to `generate_command_docs()`, fixing the H1→H3 heading hierarchy.
- `lumos/security.lua` — Windows-style backslashes are now normalised to `/`
  before the path-traversal `..` check, so `foo\..\bar` is correctly rejected.
- `Makefile` — `BUSTED` resolved via `:=` at parse time instead of inline
  `$(shell ...)` in recipes; `install-prod` and `check-rockspec` updated to
  reference `lumos-0.2.0-1.rockspec`.

### Changed

- `lumos/bundle.lua` — `LUMOS_MODULES` list extended with `lumos.native_build`
  and `lumos.package` so they are bundled when `include_lumos = true`.
- `examples/*` — All demonstration scripts are now consistent CLI Lumos
  applications using `lumos.new_app()`, a `demo` command, and
  `os.exit(app:run(arg))`. Removed the `whitepaper.md` development artifact.

### Tests

- `spec/bundle_spec.lua` — `after_each` in `amalgamate()` and `create()` now
  removes the `.lumos/cache/` directory to prevent stale cache files from
  leaking between test runs.
- `spec/completion_spec.lua` — Bash completion assertion updated from
  `_lumos_completions` to `_testapp_completions` to validate the app-name
  derivation fix.
- `spec/flags_spec.lua` — Added four new tests: `validate_flag` passes a boolean
  value through cleanly; `validate_flag` returns `false` (not `nil`) for a
  boolean value on an `int` flag; `parse_single_flag` treats `-5` as the value
  of a long flag; same for a short flag.
- `spec/manpage_spec.lua` — Example assertion updated to match the now-escaped
  `\-\-` form produced by the global dash-escaping fix.
- `spec/plugin_spec.lua` — 4 unit tests for the plugin system.
- Extended `spec/config_spec.lua` with 6 tests for schema validation and
  `load_validated()`.
- Extended `spec/table_spec.lua` with 6 tests for `paginate()` and `page()`.
- Test count: 333 (up from 291).

### Removed

- `dist/` directory — build artefacts from development (compiled binaries
  `basic_app_binary`, `advanced_usage_binary`, bundle files, `build_demo.lua`)
  removed from the repository.
- `.lumos` file — leftover cache file at the project root removed.
- `lumos-0.1.0-1.src.rock` — old release archive removed; source rocks are
  not tracked in the repository.
- `lumos/core.lua` (L.4–5) — unused `require('lumos.json')` and
  `require('lumos.security')` imports removed; neither symbol was referenced
  anywhere in `core.lua`.
- `lumos/progress.lua` (L.7) — unused `require('lumos.table')` import
  removed; `lumos_table` was never called in the module.

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
