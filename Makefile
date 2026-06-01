APP_NAME := OpenFortiVPN
BUNDLE_ID := de.devk.openfortivpn-gui
BUILD_DIR := .build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
BINARY := $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
SOURCES := $(wildcard Sources/*.swift)
# Source files needed by tests (exclude UI and @main entry point)
TESTABLE_SOURCES := Sources/Constants.swift Sources/Localization.swift Sources/VPNState.swift Sources/VPNSettings.swift Sources/PrivilegedExecution.swift Sources/VPNManager.swift
TEST_SOURCES := $(wildcard Tests/*.swift)
TEST_BINARY := $(BUILD_DIR)/tests
SWIFT_FLAGS := -O -swift-version 6

SUDOERS_FILE := /etc/sudoers.d/openfortivpn-gui
OPENFORTIVPN := $(shell command -v openfortivpn 2>/dev/null || echo /opt/homebrew/bin/openfortivpn)

.PHONY: all clean run test install-sudoers uninstall-sudoers install uninstall

all: $(APP_BUNDLE)

$(APP_BUNDLE): $(SOURCES) Info.plist
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp Info.plist $(APP_BUNDLE)/Contents/
	swiftc $(SWIFT_FLAGS) -o $(BINARY) $(SOURCES)
	@echo "Built $(APP_BUNDLE)"

run: $(APP_BUNDLE)
	open $(APP_BUNDLE)

test: $(TEST_BINARY)
	$(TEST_BINARY)

$(TEST_BINARY): $(TESTABLE_SOURCES) $(TEST_SOURCES)
	@mkdir -p $(BUILD_DIR)
	swiftc -swift-version 6 -o $(TEST_BINARY) $(TESTABLE_SOURCES) $(TEST_SOURCES)

# Install sudoers rule to allow running openfortivpn without a password.
# This prompts for your admin password once via osascript.
install-sudoers:
	@echo "Installing sudoers rule for password-free openfortivpn..."
	@echo "openfortivpn path: $(OPENFORTIVPN)"
	@RULE="$$(whoami) ALL=(root) NOPASSWD: $(OPENFORTIVPN), /usr/bin/kill"; \
	osascript -e "do shell script \"echo '$$RULE' | EDITOR='tee' visudo -f $(SUDOERS_FILE)\" with administrator privileges"
	@echo "Done. You can now run 'make run' without being prompted for a password."

# Remove the sudoers rule.
uninstall-sudoers:
	@echo "Removing sudoers rule..."
	osascript -e "do shell script \"rm -f $(SUDOERS_FILE)\" with administrator privileges"
	@echo "Done."

# Full install: build, set up sudoers, copy to /Applications.
install: $(APP_BUNDLE) install-sudoers
	@TMP_APP="/Applications/$(APP_NAME).app.tmp"; \
	rm -rf "$$TMP_APP"; \
	cp -R $(APP_BUNDLE) "$$TMP_APP"; \
	rm -rf /Applications/$(APP_NAME).app; \
	mv "$$TMP_APP" /Applications/$(APP_NAME).app
	@echo "Installed to /Applications/$(APP_NAME).app"

# Full uninstall: remove app and sudoers rule.
uninstall: uninstall-sudoers
	@rm -rf /Applications/$(APP_NAME).app
	@echo "Uninstalled."

clean:
	rm -rf $(BUILD_DIR)
