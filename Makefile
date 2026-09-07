# FlowKeys Makefile
# Universal macOS Binary (arm64 + x86_64)

APP_NAME = FlowKeys
BUNDLE_ID = com.flowkeys.app
CODESIGN_IDENTITY ?= -
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS)/MacOS
RESOURCES = $(CONTENTS)/Resources
ICON_ICNS = Resources/AppIcon.icns
# Recurse into Sources/ subdirectories (e.g. Sources/LocalAI/) so the additive
# Local AI subsystem compiles alongside the flat Sources/*.swift files.
SOURCES = $(shell find Sources -name '*.swift' | sort)

# Architecture: 'universal', 'arm64', or 'x86_64'
ARCH ?= universal

.PHONY: all build dmg clean run release help dmg-hdiutil-internal

all: build

help:
	@echo "FlowKeys Build System"
	@echo "Targets:"
	@echo "  make build      Build the app bundle"
	@echo "  make dmg        Create a distributable DMG"
	@echo "  make clean      Remove build artifacts"
	@echo "  make run        Build and launch the app"
	@echo "  make release    Prepare for GitHub release"

build: $(SOURCES) Info.plist $(ICON_ICNS)
	@mkdir -p "$(MACOS_DIR)" "$(RESOURCES)"
	@echo "Building FlowKeys ($(ARCH))..."
ifeq ($(ARCH),universal)
	swiftc \
		-parse-as-library \
		-o "$(MACOS_DIR)/$(APP_NAME)-arm64" \
		-sdk $(shell xcrun --sdk macosx --show-sdk-path) \
		-target arm64-apple-macosx13.0 \
		$(SOURCES)
	swiftc \
		-parse-as-library \
		-o "$(MACOS_DIR)/$(APP_NAME)-x86_64" \
		-sdk $(shell xcrun --sdk macosx --show-sdk-path) \
		-target x86_64-apple-macosx13.0 \
		$(SOURCES)
	lipo -create -output "$(MACOS_DIR)/$(APP_NAME)" \
		"$(MACOS_DIR)/$(APP_NAME)-arm64" \
		"$(MACOS_DIR)/$(APP_NAME)-x86_64"
	@rm "$(MACOS_DIR)/$(APP_NAME)-arm64" "$(MACOS_DIR)/$(APP_NAME)-x86_64"
else
	swiftc \
		-parse-as-library \
		-o "$(MACOS_DIR)/$(APP_NAME)" \
		-sdk $(shell xcrun --sdk macosx --show-sdk-path) \
		-target $(ARCH)-apple-macosx13.0 \
		$(SOURCES)
endif
	@cp Info.plist "$(CONTENTS)/"
	@plutil -replace CFBundleName -string "$(APP_NAME)" "$(CONTENTS)/Info.plist"
	@plutil -replace CFBundleDisplayName -string "$(APP_NAME)" "$(CONTENTS)/Info.plist"
	@plutil -replace CFBundleExecutable -string "$(APP_NAME)" "$(CONTENTS)/Info.plist"
	@plutil -replace CFBundleIdentifier -string "$(BUNDLE_ID)" "$(CONTENTS)/Info.plist"
	@cp $(ICON_ICNS) "$(RESOURCES)/"
	@codesign --force --deep --options runtime \
		--sign "$(CODESIGN_IDENTITY)" \
		--entitlements FlowKeys.entitlements \
		"$(APP_BUNDLE)"
	@echo "Built $(APP_BUNDLE)"

dmg: build
	@echo "Creating DMG..."
	@rm -rf $(BUILD_DIR)/dmg-staging
	@mkdir -p $(BUILD_DIR)/dmg-staging
	@cp -R "$(APP_BUNDLE)" $(BUILD_DIR)/dmg-staging/
	@ln -s /Applications $(BUILD_DIR)/dmg-staging/Applications
	@if [ -x "$$(which fileicon 2>/dev/null)" ]; then \
		fileicon set "$(BUILD_DIR)/dmg-staging/Applications" /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ApplicationsFolderIcon.icns || true; \
	fi
	@rm -f "$(BUILD_DIR)/$(APP_NAME).dmg"
	@if [ -x "$$(which create-dmg 2>/dev/null)" ]; then \
		create-dmg \
			--volname "$(APP_NAME)" \
			--volicon "$(ICON_ICNS)" \
			--window-pos 200 120 \
			--window-size 660 400 \
			--icon-size 128 \
			--icon "$(APP_NAME).app" 180 170 \
			--hide-extension "$(APP_NAME).app" \
			--icon "Applications" 480 170 \
			--no-internet-enable \
			"$(BUILD_DIR)/$(APP_NAME).dmg" \
			"$(BUILD_DIR)/dmg-staging" || (echo "create-dmg failed, falling back to hdiutil..." && $(MAKE) dmg-hdiutil-internal); \
	else \
		$(MAKE) dmg-hdiutil-internal; \
	fi
	@rm -rf $(BUILD_DIR)/dmg-staging
	@echo "Created $(BUILD_DIR)/$(APP_NAME).dmg"

dmg-hdiutil: build
	@$(MAKE) dmg-hdiutil-internal

dmg-hdiutil-internal:
	@echo "Creating basic DMG using hdiutil (HFS+ for compatibility)..."
	@if [ ! -d "$(BUILD_DIR)/dmg-staging" ]; then \
		mkdir -p $(BUILD_DIR)/dmg-staging; \
		cp -R "$(APP_BUNDLE)" $(BUILD_DIR)/dmg-staging/; \
		ln -s /Applications $(BUILD_DIR)/dmg-staging/Applications; \
	fi
	@rm -f "$(BUILD_DIR)/$(APP_NAME).dmg"
	@hdiutil create -volname "$(APP_NAME)" -srcfolder "$(BUILD_DIR)/dmg-staging" -ov -format UDZO -fs HFS+ "$(BUILD_DIR)/$(APP_NAME).dmg"

clean:
	rm -rf $(BUILD_DIR)

run: build
	open "$(APP_BUNDLE)"

release: dmg
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  FlowKeys DMG ready for GitHub Release"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
