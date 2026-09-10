#!/bin/bash
set -u

SUPPORT_DIR="$HOME/Library/Application Support/TerminalSolarProfiles"
APP="$SUPPORT_DIR/Terminal Solar Profiles.app"
APPLET="$APP/Contents/MacOS/applet"
LOG="$SUPPORT_DIR/last-run.log"
ERRLOG="$SUPPORT_DIR/helper.err.log"

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

if [[ ! -x "$APPLET" ]]; then
    {
        /bin/date
        echo "ERROR: helper executable not found: $APPLET"
    } > "$LOG"
    exit 1
fi

# Run the compiled AppleScript helper executable directly.
#
# Using `open -gj` can return success without proving that the app's `on run`
# handler actually executed. In practice this caused scheduled runs to be
# logged as "Triggered" while Terminal remained on the old profile.
#
# Running the applet executable directly makes each launchd interval execute
# one fresh helper process and lets us observe its actual exit status.
: > "$ERRLOG"
if "$APPLET" 2>"$ERRLOG"; then
    {
        /bin/date
        echo "Terminal Solar Profiles helper completed."
    } > "$LOG"
    exit 0
else
    STATUS=$?
    {
        /bin/date
        echo "ERROR: Terminal Solar Profiles helper exited with status $STATUS."
        if [[ -s "$ERRLOG" ]]; then
            echo
            echo "helper stderr:"
            /bin/cat "$ERRLOG"
        fi
    } > "$LOG"
    exit "$STATUS"
fi
