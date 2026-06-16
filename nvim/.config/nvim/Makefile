# Simple Makefile for compiling Fennel to Lua
# Only handles init.lua and minipack.lua

# Fennel compiler command
FENNEL = fennel

# Default target
all: init.lua
# all: init.lua lua/plugins/minipack.lua

# Compile init.fnl to init.lua
init.lua: init.fnl
	@echo "Compiling $< to $@"
	$(FENNEL) --compile $< > $@

# # Compile minipack.fnl to minipack.lua
# lua/plugins/minipack.lua: lua/plugins/minipack.fnl
# 	@echo "Compiling $< to $@"
# 	$(FENNEL) --compile $< > $@

# Clean compiled Lua files
clean:
	rm -f init.lua
#	rm -f lua/plugins/minipack.lua

# Run the structural-editing integration tests (loads the real config so the
# parinfer/paredit/parpar plugins and keymaps are present).
test:
	nvim --headless -c "luafile tests/structural_editing.lua"

.PHONY: all clean test
