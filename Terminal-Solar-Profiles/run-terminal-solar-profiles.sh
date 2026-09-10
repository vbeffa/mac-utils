#!/bin/bash
set -u

SUPPORT_DIR="$HOME/Library/Application Support/TerminalSolarProfiles"
APP="$SUPPORT_DIR/Terminal Solar Profiles.app"
APPLET="$APP/Contents/MacOS/applet"
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
# handler actually executed. Running the applet directly makes each launchd
# interval execute one fresh helper process.
#
# The AppleScript handles its own errors so scheduled failures do not create
# repeating GUI dialogs. It writes the real AppleScript error to a marker file,
# which this runner treats as a failed run.
: > "$ERRLOG"
rm -f "$APPLESCRIPT_ERR"

"$APPLET" 2>"$ERRLOG"
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
        echo "Helper exit status: $STATUS"
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
