#!/bin/bash
set -euo pipefail

SUPPORT_DIR="$HOME/Library/Application Support/TerminalSolarProfiles"
AGENT="$HOME/Library/LaunchAgents/com.local.terminalsolarprofiles.plist"
STATE="$SUPPORT_DIR/original-profiles.txt"

# Unload the LaunchAgent.
if [[ -f "$AGENT" ]]; then
    (/bin/launchctl bootout "gui/$(id -u)" "$AGENT" >/dev/null 2>&1) || true
    rm -f "$AGENT"
fi

# Restore the Terminal default/startup profiles captured at installation.
# Running this script from Terminal means Terminal is already open.
if [[ -f "$STATE" ]] && /usr/bin/pgrep -x Terminal >/dev/null 2>&1; then
    DEFAULT_PROFILE="$(/usr/bin/sed -n '1p' "$STATE")"
    STARTUP_PROFILE="$(/usr/bin/sed -n '2p' "$STATE")"

    if [[ -n "$DEFAULT_PROFILE" && -n "$STARTUP_PROFILE" ]]; then
        /usr/bin/osascript - "$DEFAULT_PROFILE" "$STARTUP_PROFILE" <<'APPLESCRIPT' || true
on run argv
    set defaultName to item 1 of argv
    set startupName to item 2 of argv
    tell application "Terminal"
        try
            set default settings to settings set defaultName
        end try
        try
            set startup settings to settings set startupName
        end try
    end tell
end run
APPLESCRIPT
    fi
fi

rm -rf "$SUPPORT_DIR"

echo "Terminal Solar Profiles has been uninstalled."
echo "Your original Terminal default/startup profiles were restored when possible."
echo "Existing open tabs are left as they are."
