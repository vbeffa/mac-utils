#!/bin/bash
set -euo pipefail
BASE="$HOME/Library/Application Support/SunAppearance"
AGENT="$HOME/Library/LaunchAgents/com.local.sunappearance.plist"

UID_NUM="$(/usr/bin/id -u)"
/bin/launchctl bootout "gui/$UID_NUM" "$AGENT" >/dev/null 2>&1 ||     /bin/launchctl unload "$AGENT" >/dev/null 2>&1 || true
rm -f "$AGENT"
rm -rf "$BASE"

# Restore the macOS Auto setting the user was using before this scheduler.
/usr/bin/defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool true

echo "Sun Appearance removed. macOS Appearance has been returned to Auto."
