install:
	@echo "Installing dependencies"
	@luarocks install busted --local --lua-version=5.4 --force || echo "Please install busted manually"
	@echo "Lumos is already installed globally or local to your user."

test:
	@~/.luarocks/bin/busted tests/

run:
	@lua src/main.lua greet World

help:
	@lua src/main.lua --help

clean:
	@rm -rf docs/*.txt

.PHONY: install test run help clean
