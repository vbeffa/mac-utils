#!/bin/bash
set -euo pipefail
BASE="$HOME/Library/Application Support/SunAppearance"
AGENT="$HOME/Library/LaunchAgents/com.local.sunappearance.plist"

UID_NUM="$(/usr/bin/id -u)"

# Stop the LaunchAgent supervisor first so it cannot restart the stay-open helper.
/bin/launchctl bootout "gui/$UID_NUM" "$AGENT" >/dev/null 2>&1 || \
    /bin/launchctl unload "$AGENT" >/dev/null 2>&1 || true
rm -f "$AGENT"

# Stop the stay-open helper before removing its application bundle.
HELPER_RUNNING=$(/usr/bin/osascript -e 'application "Sun Appearance" is running' 2>/dev/null || echo false)
if [[ "$HELPER_RUNNING" == "true" ]]; then
    /usr/bin/osascript -e 'tell application "Sun Appearance" to quit' >/dev/null 2>&1 || true
    for _ in {1..20}; do
        HELPER_RUNNING=$(/usr/bin/osascript -e 'application "Sun Appearance" is running' 2>/dev/null || echo false)
        [[ "$HELPER_RUNNING" != "true" ]] && break
        /bin/sleep 0.25
    done
fi

rm -rf "$BASE"

# Restore macOS automatic appearance switching.
/usr/bin/defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool true

echo "Sun Appearance removed. macOS Appearance has been returned to Auto."
