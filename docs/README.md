# OpenFortiVPN GUI for MacOS

A native macOS menu bar application for managing FortiVPN connections via
[openfortivpn](https://github.com/adrienverge/openfortivpn) with SAML
authentication support.

This is a graphical front-end providing a persistent menu bar icon with
connect/disconnect controls, a live log view, and configurable settings.

## Prerequisites

- macOS 14 (Sonoma) or later
- Swift 6+ toolchain (Xcode Command Line Tools or Xcode)
- `openfortivpn` installed (e.g. `brew install openfortivpn`)

## Build

```bash
make
```

The app bundle is created at `.build/OpenFortiVPN.app`.

## Install

```bash
make install
```

This will:
1. Build the app
2. Install a sudoers rule so `openfortivpn` can run without a password prompt
   (you will be asked for your admin password once during this step)
3. Copy the app to `/Applications`

### Manual sudoers setup

If you prefer to set up the sudoers rule separately:

```bash
make install-sudoers   # one-time setup, prompts for admin password
```

This creates `/etc/sudoers.d/openfortivpn-gui` with a NOPASSWD rule allowing
your user to run `openfortivpn` and `kill` as root.

### In-app sudoers install

If the sudoers rule is not installed when you click **Connect**, the app will
display an alert offering to install it. Clicking **Install** triggers a system
administrator password prompt (via `osascript`). On success the connection is
retried automatically.

## Uninstall

```bash
make uninstall
```

Removes the app from `/Applications` and the sudoers rule.

## Automated Deployment (Intune, Jamf, etc.)

For enterprise deployments via Mobile Device Management (MDM) solutions like
Intune, you can pre-configure the VPN settings without requiring manual setup
on first app start.

### Option 1: Post-Install Script with `defaults write`

Create a shell script that runs after installation:

```bash
#!/bin/bash
# configure-vpn.sh - Intune deployment script

VPN_HOST="${1:-your.vpn.host.com}"
SAML_PORT="${2:-8020}"

# Write settings to macOS preferences
defaults write com.github.usaran-devk.openfortivpn-gui vpnSettings \
  "$(printf '{"vpnHost":"%s","samlPort":%d,"setDNS":false,"peerDNS":true}' "$VPN_HOST" "$SAML_PORT")"

echo "OpenFortiVPN configured with host: $VPN_HOST port: $SAML_PORT"
```

**Deploy via Intune:**
1. Add the script to your deployment package
2. Run: `./configure-vpn.sh "vpn.company.com" 8020`

### Option 2: macOS Configuration Profile (mobileconfig)

Create a Configuration Profile that Intune can deploy directly:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadIdentifier</key>
            <string>com.github.usaran-devk.openfortivpn-gui.config</string>
            <key>PayloadType</key>
            <string>com.apple.ManagedClient.preferences</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadUUID</key>
            <string>12345678-1234-1234-1234-123456789012</string>
            <key>Forced</key>
            <array>
                <dict>
                    <key>mcx_preference_settings</key>
                    <dict>
                        <key>vpnSettings</key>
                        <string>{"vpnHost":"your.vpn.host.com","samlPort":8020,"setDNS":false,"peerDNS":true}</string>
                    </dict>
                </dict>
            </array>
        </dict>
    </array>
    <key>PayloadDescription</key>
    <string>OpenFortiVPN Configuration</string>
    <key>PayloadDisplayName</key>
    <string>OpenFortiVPN Settings</string>
    <key>PayloadIdentifier</key>
    <string>com.github.usaran-devk.openfortivpn-gui.profile</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadUUID</key>
    <string>87654321-4321-4321-4321-210987654321</string>
</dict>
</plist>
```

Upload this profile to Intune as a macOS Configuration Profile and deploy to
your user groups.

### Option 3: Managed Preferences (System-wide)

For system-wide configuration that applies to all users:

```bash
#!/bin/bash
# Create managed preferences directory (requires admin)
sudo mkdir -p /Library/Managed\ Preferences

# Write the configuration
sudo defaults write /Library/Managed\ Preferences/com.github.usaran-devk.openfortivpn-gui vpnSettings \
  '{"vpnHost":"your.vpn.host.com","samlPort":8020,"setDNS":false,"peerDNS":true}'

# Set appropriate permissions
sudo chown root /Library/Managed\ Preferences/com.github.usaran-devk.openfortivpn-gui.plist
sudo chmod 644 /Library/Managed\ Preferences/com.github.usaran-devk.openfortivpn-gui.plist
```

### Configuration Fields

When pre-configuring, set these fields in the JSON settings:

| Field        | Type    | Default | Description                    |
|--------------|---------|---------|--------------------------------|
| `vpnHost`    | string  | `""`    | FortiGate VPN gateway hostname |
| `samlPort`   | integer | `8020`  | Local SAML proxy port (1–65535) |
| `setDNS`     | boolean | `false` | Enable `--set-dns` flag         |
| `peerDNS`    | boolean | `true`  | Enable `--pppd-use-peerdns` flag |

### Recommended Approach

For Intune deployment:
- **Best:** Use **Option 1** (post-install script) — simplest to deploy via
  Intune's custom script feature
- **Enterprise:** Use **Option 2** (mobileconfig) — more professional, integrates
  with MDM frameworks, easier to manage at scale

Both approaches will configure the app on first launch without manual user
interaction.

## Run

```bash
make run
```

Or double-click the app in Finder / `/Applications`.

## Test

```bash
make test
```

## Usage

1. Click the **shield icon** in the menu bar to open the popover.
2. Click **Connect** to start the VPN connection.
3. Your default browser opens for SAML authentication -- complete the login.
4. Once authenticated, the tunnel establishes and the icon changes to a filled
   shield.
5. Click **Disconnect** to terminate the VPN.

No password prompt appears during connect/disconnect because the sudoers rule
grants passwordless access to `openfortivpn`.

### Settings

Click the gear icon in the popover footer to open the settings window:

| Setting           | Default                | Description                          |
|-------------------|------------------------|--------------------------------------|
| VPN Host          | *(empty)*              | FortiGate VPN gateway hostname       |
| SAML Port         | `8020`                 | Local port for the SAML login proxy (1–65535) |
| Launch at Login   | Off                    | Start the app automatically on user login |
| Set DNS           | Off                    | `--set-dns` flag for openfortivpn    |
| Use Peer DNS      | On                     | `--pppd-use-peerdns` flag            |

> **Note:** On macOS, keep *Set DNS* disabled and *Use Peer DNS* enabled for
> correct DNS resolution. See
> [openfortivpn#534](https://github.com/adrienverge/openfortivpn/issues/534).

## Project Structure

```
Sources/
  OpenFortiVPNApp.swift      # @main entry point
  AppDelegate.swift          # Menu bar setup, icon state management
  Constants.swift            # Centralized constants (paths, patterns, defaults)
  MenuBarView.swift          # SwiftUI popover (status, log, controls)
  SettingsView.swift         # SwiftUI settings window
  VPNManager.swift           # VPN process lifecycle & state machine
  VPNSettings.swift          # Persisted settings model
  VPNState.swift             # VPN state enum
  PrivilegedExecution.swift  # sudoers-based privilege escalation & process mgmt
  Localization.swift         # i18n strings (English + German)
Tests/
  Tests.swift                # Unit tests (137 tests)
Makefile                     # Build, install, test, sudoers management
Info.plist                   # App bundle metadata
```

## Localization

The app supports **English** and **German**. The language is auto-detected from
the system locale. Translations are defined in `Sources/Localization.swift`.

## How It Works

The app performs the following steps to establish a VPN connection:

1. Runs `sudo openfortivpn <host> --set-dns=<0|1> --pppd-use-peerdns=<0|1> --saml-login=<port>` directly via a `Process` handle (no password needed thanks to sudoers rule)
2. Monitors process output for the `"Listening for SAML login on port"` log line, then verifies the proxy via a TCP probe (3 retries, 1 s apart) before opening the browser
3. Opens `https://<host>/remote/saml/start?redirect=1` in the default browser
4. Monitors process output for connection status changes
5. On disconnect, sends SIGTERM to the `sudo` process (which forwards to `openfortivpn`), then uses `pgrep` + `sudo kill` as a fallback, followed by SIGKILL after a timeout

### Privilege Escalation

The app uses a **sudoers NOPASSWD rule** instead of `osascript` password
dialogs. This avoids a password prompt on every connect. The rule is installed
once via `make install-sudoers` and placed in `/etc/sudoers.d/openfortivpn-gui`:

```
<username> ALL=(root) NOPASSWD: /opt/homebrew/bin/openfortivpn, /usr/bin/kill
```

### Process Termination

Disconnect is handled in three stages:
1. `process.terminate()` -- sends SIGTERM to the `sudo` wrapper, which forwards it to `openfortivpn`
2. `pgrep -x openfortivpn` + `sudo kill -15 <pid>` -- catches any orphaned processes
3. After a 3-second timeout, `sudo kill -9 <pid>` -- force-kills anything remaining

## License

This project is licensed under the [GNU General Public License v3.0](../LICENSE).
