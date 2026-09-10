#!/bin/bash
set -u

SUPPORT_DIR="$HOME/Library/Application Support/TerminalSolarProfiles"
APP="$SUPPORT_DIR/Terminal Solar Profiles.app"
LOG="$SUPPORT_DIR/last-run.log"
ERRLOG="$SUPPORT_DIR/helper.err.log"
APPLESCRIPT_ERR="$SUPPORT_DIR/helper.applescript.err.log"

mkdir -p "$SUPPORT_DIR"

# Avoid launching Terminal when it isn't already open.
TERMINAL_RUNNING=$(/usr/bin/osascript -e 'application "Terminal" is running' 2>/dev/null || echo false)
if [[ "$TERMINAL_RUNNING" != "true" ]]; then
    {
        /bin/date
        echo "Terminal is not running; nothing to change."
    } > "$LOG"
    exit 0
fi

if [[ ! -d "$APP" ]]; then
    {
        /bin/date
        echo "ERROR: helper app not found: $APP"
    } > "$LOG"
    exit 1
fi

# Launch a fresh instance of the helper through Launch Services.
#
# `open -n` forces a new app instance so every launchd interval runs the
# AppleScript's `on run` handler. `-W` waits for that instance to exit, and `-g`
# keeps it in the background. Launching the app bundle this way preserves the
# helper application's Automation/TCC identity; invoking Contents/MacOS/applet
# directly from launchd can fail with Apple event error -1743 even when the app
# itself has permission to control Terminal.
#
# The AppleScript handles its own errors so scheduled failures do not create
# repeating GUI dialogs. It writes the real AppleScript error to a marker file,
# which this runner treats as a failed run.
: > "$ERRLOG"
rm -f "$APPLESCRIPT_ERR"

/usr/bin/open -n -W -g "$APP" 2>"$ERRLOG"
STATUS=$?

if [[ "$STATUS" -eq 0 && ! -s "$APPLESCRIPT_ERR" ]]; then
    {
        /bin/date
        echo "Terminal Solar Profiles helper completed."
    } > "$LOG"
    exit 0
fi

{
    /bin/date
    echo "ERROR: Terminal Solar Profiles helper failed."
    if [[ "$STATUS" -ne 0 ]]; then
        echo "Helper launch status: $STATUS"
    fi
    if [[ -s "$APPLESCRIPT_ERR" ]]; then
        echo
        echo "AppleScript error:"
        /bin/cat "$APPLESCRIPT_ERR"
    fi
    if [[ -s "$ERRLOG" ]]; then
        echo
        echo "helper stderr:"
        /bin/cat "$ERRLOG"
    fi
} > "$LOG"

exit 1
