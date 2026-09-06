#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPPORT_DIR="$HOME/Library/Application Support/TerminalSolarProfiles"
APP="$SUPPORT_DIR/Terminal Solar Profiles.app"
AGENT="$HOME/Library/LaunchAgents/com.local.terminalsolarprofiles.plist"
STATE="$SUPPORT_DIR/original-profiles.txt"

DARK_PROFILE="Solarized Dark ansi"
LIGHT_PROFILE="Solarized Light ansi"

mkdir -p "$SUPPORT_DIR" "$HOME/Library/LaunchAgents"

# Terminal is necessarily running when this installer is launched from Terminal.
# Verify the exact profiles exist and remember the user's prior default/startup
# profiles so uninstall.sh can restore them.
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

cp "$SCRIPT_DIR/TerminalSolarProfiles.applescript" "$SUPPORT_DIR/TerminalSolarProfiles.applescript"
cp "$SCRIPT_DIR/run-terminal-solar-profiles.sh" "$SUPPORT_DIR/run-terminal-solar-profiles.sh"
cp "$SCRIPT_DIR/status.sh" "$SUPPORT_DIR/status.sh"
chmod 755 "$SUPPORT_DIR/run-terminal-solar-profiles.sh" "$SUPPORT_DIR/status.sh"

rm -rf "$APP"
/usr/bin/osacompile -o "$APP" "$SUPPORT_DIR/TerminalSolarProfiles.applescript"

# Keep the helper out of the Dock when launchd runs it.
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.local.TerminalSolarProfiles" "$APP/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.local.TerminalSolarProfiles" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$APP/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :LSUIElement true" "$APP/Contents/Info.plist"

# Re-sign after editing Info.plist. Ad-hoc signing is sufficient for this local helper.
/usr/bin/codesign --force --deep --sign - "$APP" >/dev/null 2>&1

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

    <key>StartInterval</key>
    <integer>30</integer>

    <key>StandardOutPath</key>
    <string>$SUPPORT_DIR/launchd.out.log</string>
    <key>StandardErrorPath</key>
    <string>$SUPPORT_DIR/launchd.err.log</string>
</dict>
</plist>
EOF

# Replace an older loaded copy if present.
(/bin/launchctl bootout "gui/$(id -u)" "$AGENT" >/dev/null 2>&1) || true
/bin/launchctl bootstrap "gui/$(id -u)" "$AGENT"

echo
echo "Terminal Solar Profiles is installed."
echo
echo "The helper will run once now. macOS may ask whether"
echo "\"Terminal Solar Profiles\" may control Terminal. Choose OK/Allow."
echo

# Run once interactively so the Automation permission prompt can be shown.
/usr/bin/open -W -g "$APP" || true

echo
echo "It will check every 30 seconds while you are logged in."
echo "When Terminal is open:"
echo "  Dark macOS appearance  -> $DARK_PROFILE"
echo "  Light macOS appearance -> $LIGHT_PROFILE"
echo
echo "It also changes Terminal's default/startup profile and all open tabs."
echo "If Terminal is closed, it does not launch Terminal."
echo
echo "Status:"
echo "  \"$SUPPORT_DIR/status.sh\""
