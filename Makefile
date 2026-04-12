APP_NAME ?= FlowKeys
BUNDLE_ID ?= com.flowkeys.app
CODESIGN_IDENTITY ?= -
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS)/MacOS
empty :=
space := $(empty) $(empty)
APP_EXECUTABLE = $(MACOS_DIR)/$(APP_NAME)
APP_EXECUTABLE_TARGET := $(subst $(space),\ ,$(APP_EXECUTABLE))

SOURCES = $(wildcard Sources/*.swift)
RESOURCES = $(CONTENTS)/Resources
ARCH ?= $(shell uname -m)
ICON_SOURCE = Resources/AppIcon-Source.png
ICON_ICNS = Resources/AppIcon.icns

.PHONY: all clean run icon dmg codesign-dmg notarize

all: $(APP_EXECUTABLE_TARGET)

$(APP_EXECUTABLE_TARGET): $(SOURCES) Info.plist $(ICON_ICNS)
	@mkdir -p "$(MACOS_DIR)" "$(RESOURCES)"
ifeq ($(ARCH),universal)
	swiftc \
		-parse-as-library \
		-o "$(MACOS_DIR)/$(APP_NAME)-arm64" \
		-sdk $(shell xcrun --show-sdk-path) \
		-target arm64-apple-macosx13.0 \
		$(SOURCES)
	swiftc \
		-parse-as-library \
		-o "$(MACOS_DIR)/$(APP_NAME)-x86_64" \
		-sdk $(shell xcrun --show-sdk-path) \
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
		-sdk $(shell xcrun --show-sdk-path) \
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

icon: $(ICON_ICNS)

$(ICON_ICNS): $(ICON_SOURCE)
	@mkdir -p $(BUILD_DIR)/AppIcon.iconset
	@sips -z 16 16 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_16x16.png > /dev/null
	@sips -z 32 32 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_16x16@2x.png > /dev/null
	@sips -z 32 32 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_32x32.png > /dev/null
	@sips -z 64 64 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_32x32@2x.png > /dev/null
	@sips -z 128 128 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_128x128.png > /dev/null
	@sips -z 256 256 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_128x128@2x.png > /dev/null
	@sips -z 256 256 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_256x256.png > /dev/null
	@sips -z 512 512 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_256x256@2x.png > /dev/null
	@sips -z 512 512 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_512x512.png > /dev/null
	@sips -z 1024 1024 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_512x512@2x.png > /dev/null
	@iconutil -c icns -o $@ $(BUILD_DIR)/AppIcon.iconset
	@rm -rf $(BUILD_DIR)/AppIcon.iconset
	@echo "Generated $@"

dmg: all
	@rm -f "$(BUILD_DIR)/$(APP_NAME).dmg"
	@rm -rf $(BUILD_DIR)/dmg-staging
	@mkdir -p $(BUILD_DIR)/dmg-staging
	@cp -R "$(APP_BUNDLE)" $(BUILD_DIR)/dmg-staging/
	@ln -s /Applications $(BUILD_DIR)/dmg-staging/Applications
	@if [ -x "$$(which fileicon 2>/dev/null)" ]; then \
		fileicon set "$(BUILD_DIR)/dmg-staging/Applications" /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ApplicationsFolderIcon.icns; \
	fi
	@echo "Creating DMG..."
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
			"$(BUILD_DIR)/dmg-staging"; \
	else \
		echo "create-dmg not found, falling back to hdiutil (basic DMG)..."; \
		hdiutil create -size 50m -volname "$(APP_NAME)" -fs HFS+ \
			-type SPARSE "$(BUILD_DIR)/$(APP_NAME)-rw" ; \
		hdiutil attach "$(BUILD_DIR)/$(APP_NAME)-rw.sparseimage" -mountpoint "$(BUILD_DIR)/dmg-mount" ; \
		cp -R "$(BUILD_DIR)/dmg-staging/$(APP_NAME).app" "$(BUILD_DIR)/dmg-mount/" ; \
		ln -s /Applications "$(BUILD_DIR)/dmg-mount/Applications" ; \
		hdiutil detach "$(BUILD_DIR)/dmg-mount" ; \
		hdiutil convert "$(BUILD_DIR)/$(APP_NAME)-rw.sparseimage" -format UDZO \
			-o "$(BUILD_DIR)/$(APP_NAME).dmg" ; \
		rm -f "$(BUILD_DIR)/$(APP_NAME)-rw.sparseimage" ; \
	fi
	@rm -rf $(BUILD_DIR)/dmg-staging
	@echo "Created $(BUILD_DIR)/$(APP_NAME).dmg"

codesign-dmg: dmg
	codesign --force --sign "$(CODESIGN_IDENTITY)" "$(BUILD_DIR)/$(APP_NAME).dmg"

notarize:
	xcrun notarytool submit "$(BUILD_DIR)/$(APP_NAME).dmg" \
		--keychain-profile "$(NOTARIZE_PROFILE)" --wait
	xcrun stapler staple "$(BUILD_DIR)/$(APP_NAME).dmg"

clean:
	rm -rf $(BUILD_DIR)

run: all
	open "$(APP_BUNDLE)"

release: dmg
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  FlowKeys DMG ready for GitHub Release"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "NEXT STEPS TO PUBLISH:"
	@echo ""
	@echo "1. Commit and push everything:"
	@echo "   git add -A"
	@echo "   git commit -m 'Release v1.0.0'"
	@echo "   git push origin main"
	@echo ""
	@echo "2. Create and push a version tag:"
	@echo "   git tag v1.0.0"
	@echo "   git push origin v1.0.0"
	@echo ""
	@echo "3. GitHub Actions will automatically:"
	@echo "   - Build the universal DMG"
	@echo "   - Create a GitHub Release"
	@echo "   - Upload FlowKeys.dmg to the release"
	@echo ""
	@echo "4. Share this install command with anyone:"
	@echo "   curl -fsSL https://raw.githubusercontent.com/iamadarsha/FlowKeys/main/install.sh | bash"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
