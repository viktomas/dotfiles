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

.PHONY: all clean
