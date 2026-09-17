#!/bin/bash
set -euo pipefail

SUPPORT_DIR="$HOME/Library/Application Support/TerminalSolarProfiles"
AGENT="$HOME/Library/LaunchAgents/com.local.terminalsolarprofiles.plist"
STATE="$SUPPORT_DIR/original-profiles.txt"

# Unload the LaunchAgent supervisor first so it cannot restart the stay-open
# helper while uninstalling.
if [[ -f "$AGENT" ]]; then
    (/bin/launchctl bootout "gui/$(id -u)" "$AGENT" >/dev/null 2>&1) || true
    rm -f "$AGENT"
fi

# Stop the stay-open helper before restoring Terminal settings.
HELPER_RUNNING=$(/usr/bin/osascript -e 'application "Terminal Solar Profiles" is running' 2>/dev/null || echo false)
if [[ "$HELPER_RUNNING" == "true" ]]; then
    /usr/bin/osascript -e 'tell application "Terminal Solar Profiles" to quit' >/dev/null 2>&1 || true
fi

# Restore the Terminal default/startup profiles captured at installation.
TERMINAL_RUNNING=$(/usr/bin/osascript -e 'application "Terminal" is running' 2>/dev/null || echo false)
if [[ -f "$STATE" ]] && [[ "$TERMINAL_RUNNING" == "true" ]]; then
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
