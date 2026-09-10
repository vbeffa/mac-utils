#!/bin/bash
set -u

SUPPORT_DIR="$HOME/Library/Application Support/TerminalSolarProfiles"
AGENT="$HOME/Library/LaunchAgents/com.local.terminalsolarprofiles.plist"
APPLESCRIPT_ERR="$SUPPORT_DIR/helper.applescript.err.log"

if /usr/bin/defaults read -g AppleInterfaceStyle 2>/dev/null | /usr/bin/grep -q Dark; then
    MODE="dark"
    DESIRED="Solarized Dark ansi"
else
    MODE="light"
    DESIRED="Solarized Light ansi"
fi

echo "macOS_mode=$MODE"
echo "desired_terminal_profile=$DESIRED"

if /bin/launchctl print "gui/$(id -u)/com.local.terminalsolarprofiles" >/dev/null 2>&1; then
    echo "launch_agent=loaded"
else
    echo "launch_agent=not_loaded"
fi

TERMINAL_RUNNING=$(/usr/bin/osascript -e 'application "Terminal" is running' 2>/dev/null || echo false)
if [[ "$TERMINAL_RUNNING" == "true" ]]; then
    echo "terminal=running"
    /usr/bin/osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "Terminal"
    try
        set d to name of default settings
        set s to name of startup settings
        if (count of windows) > 0 then
            set c to name of current settings of selected tab of front window
        else
            set c to "(no open window)"
        end if
        return "default_profile=" & d & linefeed & "startup_profile=" & s & linefeed & "front_tab_profile=" & c
    end try
end tell
APPLESCRIPT
else
    echo "terminal=not_running"
fi

if [[ -s "$APPLESCRIPT_ERR" ]]; then
    echo
    echo "helper_error:"
    /bin/cat "$APPLESCRIPT_ERR"
fi

if [[ -f "$SUPPORT_DIR/last-run.log" ]]; then
    echo
    echo "last_run:"
    /bin/cat "$SUPPORT_DIR/last-run.log"
fi
