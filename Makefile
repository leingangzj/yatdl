# YATDL — Yet Another To-Do List
# Author: Zac Leingang

CLI_SRC     = cli/main.swift
CLI_BIN     = .build/yatdl
INSTALL_DIR = /usr/local/bin

# arm64 native, release-optimised
SWIFT_FLAGS = -O -target arm64-apple-macos14.0

.PHONY: cli install uninstall clean

cli:
	@mkdir -p .build
	swiftc $(CLI_SRC) $(SWIFT_FLAGS) -o $(CLI_BIN)
	@echo "Built: $(CLI_BIN)"

install: cli
	install -m 755 $(CLI_BIN) $(INSTALL_DIR)/yatdl
	@echo "Installed: $(INSTALL_DIR)/yatdl"

uninstall:
	rm -f $(INSTALL_DIR)/yatdl
	@echo "Removed: $(INSTALL_DIR)/yatdl"

clean:
	rm -rf .build
