APP      = build/Quickly.app
BIN      = .build/release/Quickly
CONTENTS = $(APP)/Contents
ICON     = build/AppIcon.icns

.PHONY: all build run install uninstall test clean icon dist

VERSION  = $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Support/Info.plist)
ZIP      = build/Quickly-$(VERSION).zip

all: build

$(BIN): $(wildcard Sources/*/*.swift) Package.swift
	swift build -c release

$(ICON): Support/make-icon.swift
	@mkdir -p build
	swift Support/make-icon.swift build/AppIcon.iconset
	iconutil -c icns build/AppIcon.iconset -o $(ICON)
	@rm -rf build/AppIcon.iconset

icon: $(ICON)

build: $(BIN) $(ICON)
	@rm -rf $(APP)
	@mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	@cp $(BIN) $(CONTENTS)/MacOS/Quickly
	@cp Support/Info.plist $(CONTENTS)/Info.plist
	@cp $(ICON) $(CONTENTS)/Resources/AppIcon.icns
	@codesign --force --sign - $(APP) >/dev/null 2>&1
	@echo "Built $(APP)"

run: build
	@pkill -x Quickly 2>/dev/null || true
	open $(APP)

install: build
	@pkill -x Quickly 2>/dev/null || true
	rm -rf /Applications/Quickly.app
	cp -R $(APP) /Applications/Quickly.app
	open /Applications/Quickly.app
	@echo "Installed to /Applications/Quickly.app — press ⌥Space"

# Zip the app for a GitHub release. ditto keeps the bundle's metadata intact.
dist: build
	@rm -f $(ZIP)
	ditto -c -k --keepParent $(APP) $(ZIP)
	@echo "Wrote $(ZIP)"

uninstall:
	@pkill -x Quickly 2>/dev/null || true
	rm -rf /Applications/Quickly.app

test:
	swift test

clean:
	rm -rf .build build
