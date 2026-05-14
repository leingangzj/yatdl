# YATDL — Yet Another To-Do List
# Author: Zac Leingang

APP_SRC = \
	YATDL/YATDLApp.swift \
	YATDL/AppDelegate.swift \
	YATDL/TodoItem.swift \
	YATDL/TodoList.swift \
	YATDL/TodoStore.swift \
	YATDL/FileWatcher.swift \
	YATDL/HotkeyManager.swift \
	YATDL/PanelController.swift \
	YATDL/ContentView.swift \
	YATDL/TabBarView.swift \
	YATDL/TodoListView.swift \
	YATDL/BottomToolbarView.swift

APP_FRAMEWORKS = \
	-framework AppKit \
	-framework SwiftUI \
	-framework Carbon \
	-framework Combine

CLI_SRC     = cli/main.swift
BUILD       = .build
INSTALL_DIR = /usr/local/bin
SWIFT_FLAGS = -O -target arm64-apple-macos14.0

.PHONY: all app cli install install-app uninstall clean icon

all: app cli

# ── GUI app (no Xcode required) ────────────────────────────────────────────

app: $(BUILD)/YATDL.app/Contents/MacOS/YATDL

$(BUILD)/YATDL.app/Contents/MacOS/YATDL: $(APP_SRC)
	@mkdir -p $(BUILD)/YATDL.app/Contents/MacOS
	@mkdir -p $(BUILD)/YATDL.app/Contents/Resources
	swiftc $(APP_SRC) $(APP_FRAMEWORKS) $(SWIFT_FLAGS) -o $(BUILD)/YATDL.app/Contents/MacOS/YATDL
	@cp YATDL/Info.plist   $(BUILD)/YATDL.app/Contents/Info.plist
	@cp YATDL/AppIcon.icns $(BUILD)/YATDL.app/Contents/Resources/AppIcon.icns
	@echo "Built: $(BUILD)/YATDL.app"

install-app: app
	cp -r $(BUILD)/YATDL.app /Applications/YATDL.app
	@echo "Installed: /Applications/YATDL.app"

# ── CLI ────────────────────────────────────────────────────────────────────

cli: $(BUILD)/yatdl

$(BUILD)/yatdl: $(CLI_SRC)
	@mkdir -p $(BUILD)
	swiftc $(CLI_SRC) $(SWIFT_FLAGS) -o $(BUILD)/yatdl
	@echo "Built: $(BUILD)/yatdl"

install: cli
	install -m 755 $(BUILD)/yatdl $(INSTALL_DIR)/yatdl
	@echo "Installed: $(INSTALL_DIR)/yatdl"

uninstall:
	rm -f $(INSTALL_DIR)/yatdl /Applications/YATDL.app
	@echo "Uninstalled"

# ── Icon regeneration ──────────────────────────────────────────────────────

icon:
	swift generate_icon.swift
	mkdir -p AppIcon.iconset
	sips -z 16   16   icon_1024.png --out AppIcon.iconset/icon_16x16.png      >/dev/null
	sips -z 32   32   icon_1024.png --out AppIcon.iconset/icon_16x16@2x.png   >/dev/null
	sips -z 32   32   icon_1024.png --out AppIcon.iconset/icon_32x32.png      >/dev/null
	sips -z 64   64   icon_1024.png --out AppIcon.iconset/icon_32x32@2x.png   >/dev/null
	sips -z 128  128  icon_1024.png --out AppIcon.iconset/icon_128x128.png    >/dev/null
	sips -z 256  256  icon_1024.png --out AppIcon.iconset/icon_128x128@2x.png >/dev/null
	sips -z 256  256  icon_1024.png --out AppIcon.iconset/icon_256x256.png    >/dev/null
	sips -z 512  512  icon_1024.png --out AppIcon.iconset/icon_256x256@2x.png >/dev/null
	sips -z 512  512  icon_1024.png --out AppIcon.iconset/icon_512x512.png    >/dev/null
	cp icon_1024.png AppIcon.iconset/icon_512x512@2x.png
	iconutil -c icns AppIcon.iconset -o YATDL/AppIcon.icns
	@echo "Icon updated: YATDL/AppIcon.icns"

# ── Clean ──────────────────────────────────────────────────────────────────

clean:
	rm -rf $(BUILD) AppIcon.iconset icon_1024.png
