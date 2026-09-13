#!/bin/bash
BASE="$HOME/Library/Application Support/SunAppearance"
AGENT="$HOME/Library/LaunchAgents/com.local.sunappearance.plist"

echo "Sun Appearance"
echo "--------------"
if [ -f "$BASE/status.txt" ]; then
    cat "$BASE/status.txt"
else
    echo "No status file yet."
fi

echo
if [ "$(/usr/bin/defaults read -g AppleInterfaceStyle 2>/dev/null || true)" = "Dark" ]; then
    echo "current_appearance=dark"
else
    echo "current_appearance=light"
fi

echo "macos_auto_enabled=$(/usr/bin/defaults read -g AppleInterfaceStyleSwitchesAutomatically 2>/dev/null || echo false)"

UID_NUM="$(/usr/bin/id -u)"
AGENT_INFO="$(/bin/launchctl print "gui/$UID_NUM/com.local.sunappearance" 2>&1 || true)"
if [[ "$AGENT_INFO" == *"gui/$UID_NUM/com.local.sunappearance"* || "$AGENT_INFO" == *"path = $AGENT"* ]]; then
    echo "launch_agent=loaded"
else
    echo "launch_agent=not_loaded"
fi

if [ -f "$BASE/location.txt" ]; then
    echo "cached_location=$(cat "$BASE/location.txt")"
    now=$(/bin/date +%s)
    mtime=$(/usr/bin/stat -f %m "$BASE/location.txt" 2>/dev/null || echo "$now")
    echo "cached_location_age_seconds=$((now-mtime))"
fi
