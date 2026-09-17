#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPPORT_DIR="$HOME/Library/Application Support/TerminalSolarProfiles"
APP="$SUPPORT_DIR/Terminal Solar Profiles.app"
APPLET="$APP/Contents/MacOS/applet"
AGENT="$HOME/Library/LaunchAgents/com.local.terminalsolarprofiles.plist"
STATE="$SUPPORT_DIR/original-profiles.txt"
APPLESCRIPT_ERR="$SUPPORT_DIR/helper.applescript.err.log"
INSTALL_STDERR="$SUPPORT_DIR/install-helper.err.log"
LAST_RUN="$SUPPORT_DIR/last-run.log"

DARK_PROFILE="Solarized Dark ansi"
LIGHT_PROFILE="Solarized Light ansi"

mkdir -p "$SUPPORT_DIR" "$HOME/Library/LaunchAgents"

helper_running() {
    [[ "$(/usr/bin/osascript -e 'application "Terminal Solar Profiles" is running' 2>/dev/null || echo false)" == "true" ]]
}

stop_helper() {
    if helper_running; then
        /usr/bin/osascript -e 'tell application "Terminal Solar Profiles" to quit' >/dev/null 2>&1 || true
        for _ in {1..20}; do
            helper_running || return 0
            /bin/sleep 0.25
        done
    fi
}

PROFILE_INFO=$(/usr/bin/osascript <<'APPLESCRIPT'
tell application "Terminal"
    set darkOK to exists settings set "Solarized Dark ansi"
    set lightOK to exists settings set "Solarized Light ansi"
    if darkOK is false then error "Missing Terminal profile: Solarized Dark ansi"
    if lightOK is false then error "Missing Terminal profile: Solarized Light ansi"
    set d to name of default settings
    set s to name of startup settings
    return d & linefeed & s
end tell
APPLESCRIPT
)

if [[ ! -f "$STATE" ]]; then
    printf '%s\n' "$PROFILE_INFO" > "$STATE"
fi

# Stop the supervisor and any existing helper before replacing files. If the
# install/test fails below, neither is left running.
if [[ -f "$AGENT" ]]; then
    (/bin/launchctl bootout "gui/$(id -u)" "$AGENT" >/dev/null 2>&1) || true
fi
rm -f "$AGENT"
stop_helper

# Preserve the compiled helper app when its AppleScript source has not changed.
# Recompiling an ad-hoc-signed app unnecessarily can disturb Automation/TCC
# authorization even when only the runner or documentation changed.
NEEDS_REBUILD=1
if [[ -d "$APP" && -x "$APPLET" && -f "$SUPPORT_DIR/TerminalSolarProfiles.applescript" ]] \
    && /usr/bin/cmp -s "$SCRIPT_DIR/TerminalSolarProfiles.applescript" "$SUPPORT_DIR/TerminalSolarProfiles.applescript"; then
    NEEDS_REBUILD=0
fi

cp "$SCRIPT_DIR/run-terminal-solar-profiles.sh" "$SUPPORT_DIR/run-terminal-solar-profiles.sh"
cp "$SCRIPT_DIR/status.sh" "$SUPPORT_DIR/status.sh"
chmod 755 "$SUPPORT_DIR/run-terminal-solar-profiles.sh" "$SUPPORT_DIR/status.sh"

if [[ "$NEEDS_REBUILD" -eq 1 ]]; then
    cp "$SCRIPT_DIR/TerminalSolarProfiles.applescript" "$SUPPORT_DIR/TerminalSolarProfiles.applescript"
    rm -rf "$APP"

    # -s creates a stay-open applet. Its idle handler performs the recurring
    # 30-second profile checks without repeatedly launching a new applet.
    /usr/bin/osacompile -s -o "$APP" "$SUPPORT_DIR/TerminalSolarProfiles.applescript"

    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.local.TerminalSolarProfiles" "$APP/Contents/Info.plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.local.TerminalSolarProfiles" "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$APP/Contents/Info.plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Set :LSUIElement true" "$APP/Contents/Info.plist"

    /usr/bin/codesign --force --deep --sign - "$APP" >/dev/null 2>&1
    echo "Rebuilt Terminal Solar Profiles as a stay-open helper."
else
    echo "Preserved existing Terminal Solar Profiles helper; AppleScript source is unchanged."
fi

echo
echo "Testing Terminal Solar Profiles before enabling its LaunchAgent."
echo "macOS may ask whether \"Terminal Solar Profiles\" may control Terminal."
echo "Choose OK/Allow if prompted."
echo

rm -f "$APPLESCRIPT_ERR" "$LAST_RUN"
: > "$INSTALL_STDERR"

set +e
/usr/bin/open -g "$APP" 2>"$INSTALL_STDERR"
HELPER_STATUS=$?
set -e

if [[ "$HELPER_STATUS" -eq 0 ]]; then
    # The helper stays open, so wait for its initial on-run check to write a
    # result instead of waiting for the application to exit.
    for _ in {1..60}; do
        [[ -s "$APPLESCRIPT_ERR" || -s "$LAST_RUN" ]] && break
        /bin/sleep 0.5
    done
fi

if [[ "$HELPER_STATUS" -ne 0 || -s "$APPLESCRIPT_ERR" || ! -s "$LAST_RUN" ]] \
    || /usr/bin/grep -q '^ERROR: Terminal Solar Profiles helper failed\.$' "$LAST_RUN"; then
    echo
    echo "Terminal Solar Profiles helper test failed."
    echo "The LaunchAgent was NOT loaded."
    echo
    if [[ -s "$APPLESCRIPT_ERR" ]]; then
        echo "AppleScript error:"
        /bin/cat "$APPLESCRIPT_ERR"
        echo
    fi
    if [[ -s "$INSTALL_STDERR" ]]; then
        echo "Helper stderr:"
        /bin/cat "$INSTALL_STDERR"
        echo
    fi
    if [[ -s "$LAST_RUN" ]]; then
        echo "Last run:"
        /bin/cat "$LAST_RUN"
        echo
    fi
    stop_helper
    echo "If this is an Automation permission error, enable Terminal Solar Profiles"
    echo "for Terminal in System Preferences -> Security & Privacy -> Privacy -> Automation,"
    echo "then run ./install.sh again."
    exit 1
fi

cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.local.terminalsolarprofiles</string>

    <key>ProgramArguments</key>
    <array>
        <string>$SUPPORT_DIR/run-terminal-solar-profiles.sh</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>ThrottleInterval</key>
    <integer>10</integer>

    <key>StandardOutPath</key>
    <string>$SUPPORT_DIR/launchd.out.log</string>
    <key>StandardErrorPath</key>
    <string>$SUPPORT_DIR/launchd.err.log</string>
</dict>
</plist>
EOF

/bin/launchctl bootstrap "gui/$(id -u)" "$AGENT"

echo
echo "Terminal Solar Profiles is installed and its stay-open helper is running."
echo
echo "It checks every 30 seconds while you are logged in."
echo "When Terminal is open:"
echo "  Dark macOS appearance  -> $DARK_PROFILE"
echo "  Light macOS appearance -> $LIGHT_PROFILE"
echo
echo "It also changes Terminal's default/startup profile and all open tabs."
echo "If Terminal is closed, it does not launch Terminal."
echo
echo "Status:"
echo "  \"$SUPPORT_DIR/status.sh\""
