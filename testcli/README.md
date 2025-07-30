# testcli CLI Project

This project was generated with `lumos new`.

## Structure

- `src/app.lua` : Main CLI module
- `src/main.lua` : Entrypoint script
- `tests/app_spec.lua` : Example test (busted)
- `Makefile` : Build automation
- `.busted` : Busted test configuration
- `.gitignore` : Git ignore patterns

## Getting Started

### Run the application
```bash
lua src/main.lua greet Alice
# or
make run
```

### Install dependencies
```bash
make install
```

### Run tests
```bash
make test
# or
busted tests/
```

### Build documentation
```bash
lua src/main.lua --help
```

## Development

This project uses the Lumos CLI framework. Check out the [Lumos documentation](https://github.com/your-org/lumos) for more advanced features like:

- Command aliases and subcommands
- Advanced flag types and validation
- Configuration file support
- Shell completion
- Man page generation
- Progress bars and prompts

## License

MIT License
