#!/bin/bash
set -u

SUPPORT_DIR="$HOME/Library/Application Support/TerminalSolarProfiles"
APP="$SUPPORT_DIR/Terminal Solar Profiles.app"
LOG="$SUPPORT_DIR/last-run.log"
ERRLOG="$SUPPORT_DIR/helper.err.log"

mkdir -p "$SUPPORT_DIR"

if [[ ! -d "$APP" ]]; then
    {
        /bin/date
        echo "ERROR: helper app not found: $APP"
    } > "$LOG"
    exit 1
fi

helper_running() {
    [[ "$(/usr/bin/osascript -e 'application "Terminal Solar Profiles" is running' 2>/dev/null || echo false)" == "true" ]]
}

# The helper is a stay-open AppleScript applet. The LaunchAgent runs this
# supervisor continuously rather than launching a new applet every 30 seconds.
#
# If the installer already started the helper, wait until it exits. Otherwise
# launch it once through Launch Services so macOS uses the app bundle's
# Automation/TCC identity. open -W then remains attached until the app exits.
if helper_running; then
    while helper_running; do
        /bin/sleep 5
    done
    exit 0
fi

: > "$ERRLOG"
/usr/bin/open -W -g "$APP" 2>"$ERRLOG"
STATUS=$?

if [[ "$STATUS" -ne 0 ]]; then
    {
        /bin/date
        echo "ERROR: Terminal Solar Profiles helper launch failed."
        echo "Helper launch status: $STATUS"
        if [[ -s "$ERRLOG" ]]; then
            echo
            echo "helper stderr:"
            /bin/cat "$ERRLOG"
        fi
    } > "$LOG"
fi

exit "$STATUS"
