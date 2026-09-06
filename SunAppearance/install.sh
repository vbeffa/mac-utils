#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE="$HOME/Library/Application Support/SunAppearance"
APP="$BASE/Sun Appearance.app"
AGENT="$HOME/Library/LaunchAgents/com.local.sunappearance.plist"

mkdir -p "$BASE" "$HOME/Library/LaunchAgents"
cp "$SCRIPT_DIR/sun_state.js" "$BASE/sun_state.js"
cp "$SCRIPT_DIR/sun_appearance.applescript" "$BASE/sun_appearance.applescript"
cp "$SCRIPT_DIR/status.sh" "$BASE/status.sh"
chmod +x "$BASE/status.sh"

if [ -e "$APP" ]; then
    rm -rf "$APP"
fi

/usr/bin/osacompile -o "$APP" "$BASE/sun_appearance.applescript"
PLIST="$APP/Contents/Info.plist"

set_or_add_string() {
    local key="$1" value="$2"
    /usr/libexec/PlistBuddy -c "Set :$key $value" "$PLIST" >/dev/null 2>&1 || \
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$PLIST"
}
set_or_add_bool() {
    local key="$1" value="$2"
    /usr/libexec/PlistBuddy -c "Set :$key $value" "$PLIST" >/dev/null 2>&1 || \
    /usr/libexec/PlistBuddy -c "Add :$key bool $value" "$PLIST"
}

set_or_add_string CFBundleIdentifier com.local.sunappearance
set_or_add_string CFBundleName "Sun Appearance"
set_or_add_string CFBundleDisplayName "Sun Appearance"
set_or_add_string NSLocationUsageDescription "Uses your location only to calculate local sunrise and sunset."
set_or_add_string NSLocationWhenInUseUsageDescription "Uses your location only to calculate local sunrise and sunset."
set_or_add_bool LSUIElement true

# Re-sign after editing Info.plist so macOS sees a stable application identity.
/usr/bin/codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

cat > "$AGENT" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.local.sunappearance</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>-gj</string>
        <string>$APP</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>60</integer>
</dict>
</plist>
PLISTEOF

/usr/bin/defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool false
UID_NUM="$(/usr/bin/id -u)"
/bin/launchctl bootout "gui/$UID_NUM" "$AGENT" >/dev/null 2>&1 || true

cat <<'MSG'

Sun Appearance is installed.

The helper will now run once in the foreground. macOS may ask for two permissions:
  1. Location Services: choose Allow.
  2. Automation/System Events: choose OK/Allow.

Those permissions let this local app read your Mac's current location and change
Light/Dark appearance. No location is sent over the internet.
MSG

# Wait for the first run so the permission dialogs are visible before the agent
# begins launching the app in the background.
/usr/bin/open -W "$APP" || true

if ! /bin/launchctl bootstrap "gui/$UID_NUM" "$AGENT"; then
    echo "launchctl bootstrap failed; trying legacy load..." >&2
    /bin/launchctl load "$AGENT"
fi

echo
echo "Done. The appearance is checked every minute; location is refreshed every 30 minutes."
echo "Status:  \"$BASE/status.sh\""
echo "Remove:  run uninstall.sh from this folder."
