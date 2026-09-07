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

SDK := $(shell xcrun --sdk macosx --show-sdk-path)

# Architecture: 'universal', 'arm64', or 'x86_64'
ARCH ?= universal

# ---------------------------------------------------------------------------
# Local AI native runtime (whisper.cpp) — vendored, built as universal static libs.
# Set LOCAL_AI=0 to build the app without the on-device engine (cloud-only).
# ---------------------------------------------------------------------------
LOCAL_AI ?= 1
WHISPER_SRC   = vendor/whisper.cpp
WHISPER_BUILD = $(BUILD_DIR)/whisper
WHISPER_LIBS  = $(WHISPER_BUILD)/src/libwhisper.a \
                $(WHISPER_BUILD)/ggml/src/libggml.a \
                $(WHISPER_BUILD)/ggml/src/libggml-base.a \
                $(WHISPER_BUILD)/ggml/src/libggml-cpu.a
BRIDGE_DIR    = Sources/LocalAI/CWhisper
BRIDGE_OBJDIR = $(BUILD_DIR)/bridge
CXX          ?= clang++
CXXFLAGS_BASE = -std=c++17 -O2 -mmacosx-version-min=13.0 \
                -isysroot $(SDK) -I $(BRIDGE_DIR) \
                -I $(WHISPER_SRC)/include -I $(WHISPER_SRC)/ggml/include

ifeq ($(LOCAL_AI),1)
  SWIFT_LOCALAI_FLAGS = -D FLK_LOCAL_AI \
    -import-objc-header $(BRIDGE_DIR)/whisper_bridge.h \
    -L $(WHISPER_BUILD)/src -L $(WHISPER_BUILD)/ggml/src \
    -lwhisper -lggml -lggml-base -lggml-cpu \
    -lc++ -framework Accelerate
  BRIDGE_OBJ_arm64  = $(BRIDGE_OBJDIR)/whisper_bridge_arm64.o
  BRIDGE_OBJ_x86_64 = $(BRIDGE_OBJDIR)/whisper_bridge_x86_64.o
else
  SWIFT_LOCALAI_FLAGS =
  BRIDGE_OBJ_arm64  =
  BRIDGE_OBJ_x86_64 =
endif

.PHONY: all build dmg clean clean-all run release help dmg-hdiutil-internal whisper-libs

all: build

help:
	@echo "FlowKeys Build System"
	@echo "Targets:"
	@echo "  make build       Build the app bundle (LOCAL_AI=1 by default)"
	@echo "  make build LOCAL_AI=0   Cloud-only build (no whisper.cpp)"
	@echo "  make whisper-libs       Build only the vendored whisper.cpp static libs"
	@echo "  make dmg         Create a distributable DMG"
	@echo "  make clean       Remove app build artifacts (keeps whisper libs)"
	@echo "  make clean-all   Remove everything including whisper libs"
	@echo "  make run         Build and launch the app"
	@echo "  make release     Prepare for GitHub release"

# --- whisper.cpp static libs (universal, CPU + Accelerate) -------------------

$(WHISPER_BUILD)/CMakeCache.txt: $(WHISPER_SRC)/CMakeLists.txt
	@echo "Configuring whisper.cpp ($(WHISPER_SRC))..."
	@if [ ! -f "$(WHISPER_SRC)/CMakeLists.txt" ]; then \
		echo "ERROR: vendor/whisper.cpp is missing. Run: git submodule update --init --recursive"; exit 1; \
	fi
	cmake -S $(WHISPER_SRC) -B $(WHISPER_BUILD) \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUILD_SHARED_LIBS=OFF \
		-DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=OFF -DWHISPER_BUILD_SERVER=OFF \
		-DGGML_METAL=OFF -DGGML_ACCELERATE=ON -DGGML_BLAS=OFF -DGGML_OPENMP=OFF \
		-DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
		-DCMAKE_OSX_DEPLOYMENT_TARGET=13.0

$(WHISPER_LIBS): $(WHISPER_BUILD)/CMakeCache.txt
	@echo "Building whisper.cpp static libs (universal)..."
	cmake --build $(WHISPER_BUILD) --config Release -j

whisper-libs: $(WHISPER_LIBS)

# --- C++ bridge objects -----------------------------------------------------

$(BRIDGE_OBJDIR)/whisper_bridge_%.o: $(BRIDGE_DIR)/whisper_bridge.cpp $(BRIDGE_DIR)/whisper_bridge.h $(WHISPER_LIBS)
	@mkdir -p $(BRIDGE_OBJDIR)
	$(CXX) $(CXXFLAGS_BASE) -arch $* -c $(BRIDGE_DIR)/whisper_bridge.cpp -o $@

# --- app ------------------------------------------------------------------

ifeq ($(LOCAL_AI),1)
build: $(SOURCES) Info.plist $(ICON_ICNS) $(BRIDGE_OBJ_arm64) $(BRIDGE_OBJ_x86_64)
else
build: $(SOURCES) Info.plist $(ICON_ICNS)
endif
	@mkdir -p "$(MACOS_DIR)" "$(RESOURCES)"
	@echo "Building FlowKeys ($(ARCH), LOCAL_AI=$(LOCAL_AI))..."
ifeq ($(ARCH),universal)
	swiftc \
		-parse-as-library \
		-o "$(MACOS_DIR)/$(APP_NAME)-arm64" \
		-sdk $(SDK) \
		-target arm64-apple-macosx13.0 \
		$(SWIFT_LOCALAI_FLAGS) $(BRIDGE_OBJ_arm64) \
		$(SOURCES)
	swiftc \
		-parse-as-library \
		-o "$(MACOS_DIR)/$(APP_NAME)-x86_64" \
		-sdk $(SDK) \
		-target x86_64-apple-macosx13.0 \
		$(SWIFT_LOCALAI_FLAGS) $(BRIDGE_OBJ_x86_64) \
		$(SOURCES)
	lipo -create -output "$(MACOS_DIR)/$(APP_NAME)" \
		"$(MACOS_DIR)/$(APP_NAME)-arm64" \
		"$(MACOS_DIR)/$(APP_NAME)-x86_64"
	@rm "$(MACOS_DIR)/$(APP_NAME)-arm64" "$(MACOS_DIR)/$(APP_NAME)-x86_64"
else
	swiftc \
		-parse-as-library \
		-o "$(MACOS_DIR)/$(APP_NAME)" \
		-sdk $(SDK) \
		-target $(ARCH)-apple-macosx13.0 \
		$(SWIFT_LOCALAI_FLAGS) $(BRIDGE_OBJDIR)/whisper_bridge_$(ARCH).o \
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
	rm -rf $(APP_BUNDLE) $(BUILD_DIR)/dmg-staging $(BRIDGE_OBJDIR) "$(BUILD_DIR)/$(APP_NAME).dmg"

clean-all:
	rm -rf $(BUILD_DIR)

run: build
	open "$(APP_BUNDLE)"

release: dmg
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  FlowKeys DMG ready for GitHub Release"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
