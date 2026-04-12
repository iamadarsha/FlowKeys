# FlowKeys Makefile
# Universal macOS Binary (arm64 + x86_64)

APP_NAME = FlowKeys
PRODUCT_NAME = FlowKeys
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
ICON_ICNS = Resources/AppIcon.icns

# Architecture: 'universal', 'arm64', or 'x86_64'
ARCH ?= universal

ifeq ($(ARCH),universal)
    XCODE_FLAGS = -arch arm64 -arch x86_64
else
    XCODE_FLAGS = -arch $(ARCH)
endif

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

build:
	@mkdir -p $(BUILD_DIR)
	@echo "Building FlowKeys ($(ARCH))..."
	@xcodebuild -project FlowKeys.xcodeproj \
		-scheme FlowKeys \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR)/DerivedData \
		$(XCODE_FLAGS) \
		build
	@cp -R $(BUILD_DIR)/DerivedData/Build/Products/Release/$(APP_NAME).app $(BUILD_DIR)/
	@echo "Built $(APP_BUNDLE)"

dmg: build
	@echo "Creating DMG..."
	@rm -rf $(BUILD_DIR)/dmg-staging
	@mkdir -p $(BUILD_DIR)/dmg-staging
	@cp -R "$(APP_BUNDLE)" $(BUILD_DIR)/dmg-staging/
	@ln -s /Applications $(BUILD_DIR)/dmg-staging/Applications
	@# Attempt to set the folder icon if fileicon is available
	@if [ -x "$$(which fileicon 2>/dev/null)" ]; then \
		fileicon set "$(BUILD_DIR)/dmg-staging/Applications" /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ApplicationsFolderIcon.icns || true; \
	fi
	@rm -f "$(BUILD_DIR)/$(APP_NAME).dmg"
	@if [ -x "$$(which create-dmg 2>/dev/null)" ]; then \
		echo "Using create-dmg..."; \
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

# External target that ensures build is run
dmg-hdiutil: build
	@$(MAKE) dmg-hdiutil-internal

# Internal target that assumes staging is ready
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
	@echo "1. Push changes: git commit -am 'Release v1.0.x' && git push"
	@echo "2. Tag version:  git tag v1.0.x && git push origin v1.0.x"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
