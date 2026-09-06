#!/bin/bash
set -u

SUPPORT_DIR="$HOME/Library/Application Support/TerminalSolarProfiles"
APP="$SUPPORT_DIR/Terminal Solar Profiles.app"
LOG="$SUPPORT_DIR/last-run.log"

mkdir -p "$SUPPORT_DIR"

# Avoid launching Terminal when it isn't already open.
if ! /usr/bin/pgrep -x Terminal >/dev/null 2>&1; then
    {
        /bin/date
        echo "Terminal is not running; nothing to change."
    } > "$LOG"
    exit 0
fi

# Launch the background AppleScript helper. It reads the current macOS
# Light/Dark state, which SunAppearance already keeps synchronized to
# actual sunrise/sunset.
if /usr/bin/open -gj "$APP" 2>>"$LOG"; then
    {
        /bin/date
        echo "Triggered Terminal Solar Profiles helper."
    } > "$LOG"
else
    {
        /bin/date
        echo "ERROR: Could not launch helper app: $APP"
    } > "$LOG"
    exit 1
fi
