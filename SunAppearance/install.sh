#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE="$HOME/Library/Application Support/SunAppearance"
APP="$BASE/Sun Appearance.app"
APPLET="$APP/Contents/MacOS/applet"
AGENT="$HOME/Library/LaunchAgents/com.local.sunappearance.plist"
STATUS_FILE="$BASE/status.txt"

mkdir -p "$BASE" "$HOME/Library/LaunchAgents"
UID_NUM="$(/usr/bin/id -u)"

# Stop any existing recurring job before replacing installed files. If the
# interactive helper test fails below, the LaunchAgent remains unloaded.
if [ -f "$AGENT" ]; then
    /bin/launchctl bootout "gui/$UID_NUM" "$AGENT" >/dev/null 2>&1 || true
fi

# Preserve the compiled helper app when its AppleScript source has not changed.
# Recompiling an ad-hoc-signed helper unnecessarily can disturb Location and
# Automation/TCC authorization.
NEEDS_REBUILD=1
if [ -d "$APP" ] && [ -x "$APPLET" ] && [ -f "$BASE/sun_appearance.applescript" ] \
    && /usr/bin/cmp -s "$SCRIPT_DIR/sun_appearance.applescript" "$BASE/sun_appearance.applescript"; then
    NEEDS_REBUILD=0
fi

cp "$SCRIPT_DIR/sun_state.js" "$BASE/sun_state.js"
cp "$SCRIPT_DIR/status.sh" "$BASE/status.sh"
chmod +x "$BASE/status.sh"

if [ "$NEEDS_REBUILD" -eq 1 ]; then
    cp "$SCRIPT_DIR/sun_appearance.applescript" "$BASE/sun_appearance.applescript"
    rm -rf "$APP"

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
    echo "Rebuilt Sun Appearance helper because its AppleScript source changed."
else
    echo "Preserved existing Sun Appearance helper; AppleScript source is unchanged."
fi

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
        <string>-n</string>
        <string>-W</string>
        <string>-g</string>
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

cat <<'MSG'

Testing Sun Appearance before enabling its recurring LaunchAgent.

macOS may ask for two permissions:
  1. Location Services: choose Allow.
  2. Automation/System Events: choose OK/Allow.

Those permissions let this local app read your Mac's current location and change
Light/Dark appearance. No location is sent over the internet.
MSG

# Launch through Launch Services as a fresh app instance. -n guarantees that the
# app's on-run handler executes even if Launch Services still considers a prior
# helper instance open, and -W lets the installer verify the completed run.
rm -f "$STATUS_FILE"
set +e
/usr/bin/open -n -W -g "$APP"
HELPER_STATUS=$?
set -e

if [ "$HELPER_STATUS" -ne 0 ] || [ ! -s "$STATUS_FILE" ]; then
    echo
    echo "Sun Appearance helper test failed."
    echo "The recurring LaunchAgent was NOT loaded."
    exit 1
fi

if /usr/bin/grep -q '^result=ERROR ' "$STATUS_FILE"; then
    echo
    echo "Sun Appearance helper test reported an error:"
    /bin/cat "$STATUS_FILE"
    echo
    echo "The recurring LaunchAgent was NOT loaded."
    exit 1
fi

if ! /bin/launchctl bootstrap "gui/$UID_NUM" "$AGENT"; then
    echo "launchctl bootstrap failed; trying legacy load..." >&2
    /bin/launchctl load "$AGENT"
fi

echo
echo "Done. The appearance is checked every minute; location is refreshed every 30 minutes."
echo "Status:  \"$BASE/status.sh\""
echo "Remove:  run uninstall.sh from this folder."
