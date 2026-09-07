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
# Local AI native runtime.
#   LOCAL_AI=1  (default) — whisper.cpp ASR + VAD, universal static libs.
#   LOCAL_LLM=1 (default when LOCAL_AI=1) — llama.cpp for on-device text cleanup,
#               bundled as a dylib in Contents/Frameworks/ (its ggml 0.23 must
#               not statically collide with whisper.cpp's ggml 0.20).
#   LOCAL_AI=0 → cloud-only build.
# ---------------------------------------------------------------------------
LOCAL_AI  ?= 1
LOCAL_LLM ?= $(LOCAL_AI)
WHISPER_SRC   = vendor/whisper.cpp
WHISPER_BUILD = $(BUILD_DIR)/whisper
WHISPER_LIBS  = $(WHISPER_BUILD)/src/libwhisper.a \
                $(WHISPER_BUILD)/ggml/src/libggml.a \
                $(WHISPER_BUILD)/ggml/src/libggml-base.a \
                $(WHISPER_BUILD)/ggml/src/libggml-cpu.a
LLAMA_SRC     = vendor/llama.cpp
LLAMA_BUILD   = $(BUILD_DIR)/llama
LLAMA_DYLIB   = $(LLAMA_BUILD)/bin/libllama.dylib
FW_DIR        = $(BUILD_DIR)/Frameworks
FW_DYLIBS     = $(FW_DIR)/libllama.dylib $(FW_DIR)/libggml.dylib \
                $(FW_DIR)/libggml-base.dylib $(FW_DIR)/libggml-cpu.dylib
BRIDGE_DIR    = Sources/LocalAI/CWhisper
LLAMA_BRIDGE_DIR = Sources/LocalAI/CLlama
BRIDGE_OBJDIR = $(BUILD_DIR)/bridge
BRIDGING_HEADER = Sources/LocalAI/flowkeys_bridging.h
CXX          ?= clang++
CXXFLAGS_BASE = -std=c++17 -O2 -mmacosx-version-min=13.0 \
                -isysroot $(SDK) -I $(BRIDGE_DIR) \
                -I $(WHISPER_SRC)/include -I $(WHISPER_SRC)/ggml/include
LLAMA_CXXFLAGS = -std=c++17 -O2 -mmacosx-version-min=13.0 -isysroot $(SDK) \
                -I $(LLAMA_BRIDGE_DIR) -I $(LLAMA_SRC)/include -I $(LLAMA_SRC)/ggml/include

ifeq ($(LOCAL_AI),1)
  LOCALAI_DEFINES = -D FLK_LOCAL_AI
  BRIDGE_OBJ_arm64  = $(BRIDGE_OBJDIR)/whisper_bridge_arm64.o
  BRIDGE_OBJ_x86_64 = $(BRIDGE_OBJDIR)/whisper_bridge_x86_64.o
  SWIFT_WHISPER_LINK = -L $(WHISPER_BUILD)/src -L $(WHISPER_BUILD)/ggml/src \
    -lwhisper -lggml -lggml-base -lggml-cpu -lc++ -framework Accelerate
ifeq ($(LOCAL_LLM),1)
  LOCALAI_DEFINES += -D FLK_LOCAL_LLM -Xcc -DFLK_LOCAL_LLM
  LLAMA_BRIDGE_OBJ_arm64  = $(BRIDGE_OBJDIR)/llama_bridge_arm64.o
  LLAMA_BRIDGE_OBJ_x86_64 = $(BRIDGE_OBJDIR)/llama_bridge_x86_64.o
  SWIFT_LLAMA_LINK = -L $(FW_DIR) -lllama -Xlinker -rpath -Xlinker @executable_path/../Frameworks
else
  LLAMA_BRIDGE_OBJ_arm64 =
  LLAMA_BRIDGE_OBJ_x86_64 =
  SWIFT_LLAMA_LINK =
endif
  SWIFT_LOCALAI_FLAGS = $(LOCALAI_DEFINES) -import-objc-header $(BRIDGING_HEADER) \
    $(SWIFT_WHISPER_LINK) $(SWIFT_LLAMA_LINK)
else
  SWIFT_LOCALAI_FLAGS =
  BRIDGE_OBJ_arm64  =
  BRIDGE_OBJ_x86_64 =
  LLAMA_BRIDGE_OBJ_arm64 =
  LLAMA_BRIDGE_OBJ_x86_64 =
endif

.PHONY: all build dmg clean clean-all run release help dmg-hdiutil-internal whisper-libs test-local

all: build

# Dependency-free Local AI test harness (see Tests/local_ai_tests.swift)
TEST_LOCAL_SRCS = Tests/local_ai_tests.swift \
	Sources/LocalAI/LocalAISettings.swift \
	Sources/LocalAI/LocalModelManifest.swift \
	Sources/LocalAI/LanguageRouting.swift \
	Sources/LocalAI/CryptoKitSHA256.swift \
	Sources/LocalAI/SpeechAnalysis.swift \
	Sources/IndianContextPrompts.swift \
	Sources/BengaliContextPrompts.swift \
	Sources/Notification+VoiceToText.swift

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

# --- llama.cpp dylib (universal) + Frameworks/ staging ----------------------

$(LLAMA_BUILD)/CMakeCache.txt: $(LLAMA_SRC)/CMakeLists.txt
	@echo "Configuring llama.cpp ($(LLAMA_SRC))..."
	@if [ ! -f "$(LLAMA_SRC)/CMakeLists.txt" ]; then \
		echo "ERROR: vendor/llama.cpp is missing. Run: git submodule update --init --recursive"; exit 1; \
	fi
	cmake -S $(LLAMA_SRC) -B $(LLAMA_BUILD) \
		-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON \
		-DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_TOOLS=OFF \
		-DLLAMA_BUILD_SERVER=OFF -DLLAMA_CURL=OFF -DLLAMA_BUILD_IS_DEV=OFF \
		-DGGML_METAL=OFF -DGGML_ACCELERATE=ON -DGGML_BLAS=OFF -DGGML_OPENMP=OFF \
		-DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0

$(LLAMA_DYLIB): $(LLAMA_BUILD)/CMakeCache.txt
	@echo "Building llama.cpp dylib (universal)..."
	cmake --build $(LLAMA_BUILD) --config Release --target llama -j

$(FW_DYLIBS): $(LLAMA_DYLIB)
	@echo "Staging llama dylibs into $(FW_DIR)/..."
	@mkdir -p $(FW_DIR)
	@for n in llama ggml ggml-base ggml-cpu; do \
		src=$$(readlink -f $(LLAMA_BUILD)/bin/lib$$n.dylib 2>/dev/null || echo $(LLAMA_BUILD)/bin/lib$$n.dylib); \
		cp "$$src" $(FW_DIR)/lib$$n.dylib; \
		install_name_tool -id @rpath/lib$$n.dylib $(FW_DIR)/lib$$n.dylib; \
	done
	@for f in $(FW_DIR)/*.dylib; do \
		otool -L "$$f" | awk '/@rpath\/lib(ggml|llama)[.0-9]*\.dylib/{print $$1}' | while read ref; do \
			base=$$(basename "$$ref"); newbase=$$(echo "$$base" | sed -E 's/\.[0-9.]+dylib$$/.dylib/'); \
			[ "$$base" != "$$newbase" ] && install_name_tool -change "$$ref" "@rpath/$$newbase" "$$f" || true; \
		done; \
	done
	@codesign -f -s "$(CODESIGN_IDENTITY)" $(FW_DIR)/*.dylib

llama-libs: $(FW_DYLIBS)

# --- C++ bridge objects -----------------------------------------------------

$(BRIDGE_OBJDIR)/whisper_bridge_%.o: $(BRIDGE_DIR)/whisper_bridge.cpp $(BRIDGE_DIR)/whisper_bridge.h $(WHISPER_LIBS)
	@mkdir -p $(BRIDGE_OBJDIR)
	$(CXX) $(CXXFLAGS_BASE) -arch $* -c $(BRIDGE_DIR)/whisper_bridge.cpp -o $@

$(BRIDGE_OBJDIR)/llama_bridge_%.o: $(LLAMA_BRIDGE_DIR)/llama_bridge.cpp $(LLAMA_BRIDGE_DIR)/llama_bridge.h $(LLAMA_DYLIB)
	@mkdir -p $(BRIDGE_OBJDIR)
	$(CXX) $(LLAMA_CXXFLAGS) -arch $* -c $(LLAMA_BRIDGE_DIR)/llama_bridge.cpp -o $@

# --- app ------------------------------------------------------------------

BUILD_PREREQS = $(SOURCES) Info.plist $(ICON_ICNS)
ifeq ($(LOCAL_AI),1)
BUILD_PREREQS += $(BRIDGE_OBJ_arm64) $(BRIDGE_OBJ_x86_64)
ifeq ($(LOCAL_LLM),1)
BUILD_PREREQS += $(LLAMA_BRIDGE_OBJ_arm64) $(LLAMA_BRIDGE_OBJ_x86_64) $(FW_DYLIBS)
endif
endif

build: $(BUILD_PREREQS)
	@mkdir -p "$(MACOS_DIR)" "$(RESOURCES)"
	@echo "Building FlowKeys ($(ARCH), LOCAL_AI=$(LOCAL_AI) LOCAL_LLM=$(LOCAL_LLM))..."
ifeq ($(ARCH),universal)
	swiftc \
		-parse-as-library \
		-o "$(MACOS_DIR)/$(APP_NAME)-arm64" \
		-sdk $(SDK) \
		-target arm64-apple-macosx13.0 \
		$(SWIFT_LOCALAI_FLAGS) $(BRIDGE_OBJ_arm64) $(LLAMA_BRIDGE_OBJ_arm64) \
		$(SOURCES)
	swiftc \
		-parse-as-library \
		-o "$(MACOS_DIR)/$(APP_NAME)-x86_64" \
		-sdk $(SDK) \
		-target x86_64-apple-macosx13.0 \
		$(SWIFT_LOCALAI_FLAGS) $(BRIDGE_OBJ_x86_64) $(LLAMA_BRIDGE_OBJ_x86_64) \
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
		$(if $(filter 1,$(LOCAL_LLM)),$(BRIDGE_OBJDIR)/llama_bridge_$(ARCH).o) \
		$(SOURCES)
endif
	@cp Info.plist "$(CONTENTS)/"
	@plutil -replace CFBundleName -string "$(APP_NAME)" "$(CONTENTS)/Info.plist"
	@plutil -replace CFBundleDisplayName -string "$(APP_NAME)" "$(CONTENTS)/Info.plist"
	@plutil -replace CFBundleExecutable -string "$(APP_NAME)" "$(CONTENTS)/Info.plist"
	@plutil -replace CFBundleIdentifier -string "$(BUNDLE_ID)" "$(CONTENTS)/Info.plist"
	@cp $(ICON_ICNS) "$(RESOURCES)/"
ifeq ($(LOCAL_LLM),1)
	@if [ "$(LOCAL_AI)" = "1" ]; then \
		mkdir -p "$(CONTENTS)/Frameworks"; \
		cp $(FW_DIR)/*.dylib "$(CONTENTS)/Frameworks/"; \
	fi
endif
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

test-local:
	@mkdir -p $(BUILD_DIR)
	swiftc -O -parse-as-library -sdk $(SDK) -target arm64-apple-macosx13.0 \
		-o $(BUILD_DIR)/local_ai_tests $(TEST_LOCAL_SRCS)
	@$(BUILD_DIR)/local_ai_tests

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
