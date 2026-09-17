#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE="$HOME/Library/Application Support/SunAppearance"
APP="$BASE/Sun Appearance.app"
APPLET="$APP/Contents/MacOS/applet"
AGENT="$HOME/Library/LaunchAgents/com.local.sunappearance.plist"
STATUS_FILE="$BASE/status.txt"
RUNNER="$BASE/run-sun-appearance.sh"

mkdir -p "$BASE" "$HOME/Library/LaunchAgents"
UID_NUM="$(/usr/bin/id -u)"

helper_running() {
    [[ "$(/usr/bin/osascript -e 'application "Sun Appearance" is running' 2>/dev/null || echo false)" == "true" ]]
}

stop_helper() {
    if helper_running; then
        /usr/bin/osascript -e 'tell application "Sun Appearance" to quit' >/dev/null 2>&1 || true
        for _ in {1..20}; do
            helper_running || return 0
            /bin/sleep 0.25
        done
    fi
}

# Stop the supervisor and any existing helper before replacing files. If the
# interactive helper test fails below, neither is left running.
if [ -f "$AGENT" ]; then
    /bin/launchctl bootout "gui/$UID_NUM" "$AGENT" >/dev/null 2>&1 || true
fi
rm -f "$AGENT"
stop_helper

# Preserve the compiled helper app when its AppleScript source has not changed.
# Recompiling an ad-hoc-signed helper unnecessarily can disturb Location and
# Automation/TCC authorization.
NEEDS_REBUILD=1
if [ -d "$APP" ] && [ -x "$APPLET" ] && [ -f "$BASE/sun_appearance.applescript" ] \
    && /usr/bin/cmp -s "$SCRIPT_DIR/sun_appearance.applescript" "$BASE/sun_appearance.applescript"; then
    NEEDS_REBUILD=0
fi

cp "$SCRIPT_DIR/sun_state.js" "$BASE/sun_state.js"
cp "$SCRIPT_DIR/run-sun-appearance.sh" "$RUNNER"
cp "$SCRIPT_DIR/status.sh" "$BASE/status.sh"
chmod +x "$RUNNER" "$BASE/status.sh"

if [ "$NEEDS_REBUILD" -eq 1 ]; then
    cp "$SCRIPT_DIR/sun_appearance.applescript" "$BASE/sun_appearance.applescript"
    rm -rf "$APP"

    # -s creates a stay-open applet. Its idle handler performs the recurring
    # 60-second appearance checks without repeatedly launching a new applet.
    /usr/bin/osacompile -s -o "$APP" "$BASE/sun_appearance.applescript"
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
    echo "Rebuilt Sun Appearance as a stay-open helper."
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
        <string>$RUNNER</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
PLISTEOF

/usr/bin/defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool false

cat <<'MSG'

Testing Sun Appearance before enabling its LaunchAgent.

macOS may ask for two permissions:
  1. Location Services: choose Allow.
  2. Automation/System Events: choose OK/Allow.

Those permissions let this local app read your Mac's current location and change
Light/Dark appearance. No location is sent over the internet.
MSG

# The helper stays open. Launch it once through Launch Services, then wait for
# its initial on-run check to produce a status file instead of waiting for exit.
rm -f "$STATUS_FILE"
set +e
/usr/bin/open -g "$APP"
HELPER_STATUS=$?
set -e

if [ "$HELPER_STATUS" -eq 0 ]; then
    for _ in {1..240}; do
        [ -s "$STATUS_FILE" ] && break
        /bin/sleep 0.5
    done
fi

if [ "$HELPER_STATUS" -ne 0 ] || [ ! -s "$STATUS_FILE" ]; then
    echo
    echo "Sun Appearance helper test failed."
    echo "The LaunchAgent was NOT loaded."
    stop_helper
    exit 1
fi

if /usr/bin/grep -q '^result=ERROR ' "$STATUS_FILE"; then
    echo
    echo "Sun Appearance helper test reported an error:"
    /bin/cat "$STATUS_FILE"
    echo
    echo "The LaunchAgent was NOT loaded."
    stop_helper
    exit 1
fi

if ! /bin/launchctl bootstrap "gui/$UID_NUM" "$AGENT"; then
    echo "launchctl bootstrap failed; trying legacy load..." >&2
    /bin/launchctl load "$AGENT"
fi

echo
echo "Done. Sun Appearance is running as one stay-open background helper."
echo "The appearance is checked every minute; location is refreshed every 30 minutes."
echo "Status:  \"$BASE/status.sh\""
echo "Remove:  run uninstall.sh from this folder."
