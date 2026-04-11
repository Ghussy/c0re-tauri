ifeq ($(shell uname -m), arm64)
	ARCH := _arm64
else
	ARCH :=
endif
OS := $(shell uname -s)
MACOS_APP_BUNDLE := src-tauri/target/release/bundle/macos/c0re.app
MACOS_INSTALL_PATH := /Applications/c0re.app

.PHONY: build dev install prebuild precommit format check package webui-build

build: prebuild
	npm run tauri build

dev: prebuild
	npm run tauri dev

install: build
ifeq ($(OS),Darwin)
	@if [ ! -d "$(MACOS_APP_BUNDLE)" ]; then \
		echo "Missing app bundle at $(MACOS_APP_BUNDLE)"; \
		exit 1; \
	fi
	codesign --verify --deep --strict --verbose=2 "$(MACOS_APP_BUNDLE)"
	rm -rf "$(MACOS_INSTALL_PATH)"
	ditto "$(MACOS_APP_BUNDLE)" "$(MACOS_INSTALL_PATH)"
	@echo "Installed signed app to $(MACOS_INSTALL_PATH)"
else
	@echo "make install is only supported on macOS"
	@exit 1
endif

%/.git:
	git submodule update --init --recursive

src-tauri/icons/icon.png: c0re-webui/.git
	mkdir -p src-tauri/icons
	if [ -f "./c0re-webui/public/logo.svg" ]; then \
		npm run tauri icon "./c0re-webui/public/logo.svg"; \
	elif [ -f "./c0re-webui/public/logo.png" ]; then \
		npm run tauri icon "./c0re-webui/public/logo.png"; \
	else \
		echo "No icon source found in c0re-webui/public (expected logo.svg or logo.png)" && exit 1; \
	fi

webui-build: c0re-webui/.git c0re-webui/package.json c0re-webui/pnpm-lock.yaml
	cd c0re-webui && corepack pnpm install --frozen-lockfile && corepack pnpm run build

prebuild: webui-build node_modules src-tauri/icons/icon.png

precommit: format check

format:
	cd src-tauri && cargo fmt

check:
	cd src-tauri && cargo check && cargo clippy

package:
ifeq ($(OS),Linux)
	rm -rf target/package/aw-tauri
	mkdir -p target/package/aw-tauri
	cp src-tauri/target/release/bundle/deb/*.deb target/package/aw-tauri/aw-tauri$(ARCH).deb
	cp src-tauri/target/release/bundle/rpm/*.rpm target/package/aw-tauri/aw-tauri$(ARCH).rpm
	cp src-tauri/target/release/bundle/appimage/*.AppImage target/package/aw-tauri/aw-tauri$(ARCH).AppImage

	mkdir -p dist/aw-tauri
	rm -rf dist/aw-tauri/*
	cp target/package/aw-tauri/* dist/aw-tauri/
else
	rm -rf target/package
	mkdir -p target/package
	cp src-tauri/target/release/aw-tauri target/package/aw-tauri

	mkdir -p dist
	find dist/ -maxdepth 1 -type f -delete 2>/dev/null || true
	cp target/package/* dist/
endif

node_modules: package-lock.json
	npm ci
