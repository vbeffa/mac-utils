#!/bin/bash
set -u

BASE="$HOME/Library/Application Support/SunAppearance"
APP="$BASE/Sun Appearance.app"
LOG="$BASE/launchd-helper.log"
ERRLOG="$BASE/helper.err.log"

mkdir -p "$BASE"

if [[ ! -d "$APP" ]]; then
    {
        /bin/date
        echo "ERROR: helper app not found: $APP"
    } > "$LOG"
    exit 1
fi

helper_running() {
    [[ "$(/usr/bin/osascript -e 'application "Sun Appearance" is running' 2>/dev/null || echo false)" == "true" ]]
}

# Sun Appearance is a stay-open AppleScript applet. The LaunchAgent runs this
# supervisor continuously instead of launching a fresh applet every minute.
#
# If the installer has already started the helper, wait until it exits. Otherwise
# launch it once through Launch Services so macOS uses the app bundle's
# Location/Automation identity. `open -W` remains attached until the app exits.
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
        echo "ERROR: Sun Appearance helper launch failed."
        echo "Helper launch status: $STATUS"
        if [[ -s "$ERRLOG" ]]; then
            echo
            echo "helper stderr:"
            /bin/cat "$ERRLOG"
        fi
    } > "$LOG"
fi

exit "$STATUS"
