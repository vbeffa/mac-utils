Terminal Solar Profiles
=======================

Companion to SunAppearance-Monterey.

Purpose
-------
When macOS is in Dark appearance, Terminal uses:
  Solarized Dark ansi

When macOS is in Light appearance, Terminal uses:
  Solarized Light ansi

Because SunAppearance-Monterey already forces macOS Light/Dark according to the
actual solar position at your current location, this companion follows those same
sunrise/sunset transitions without duplicating location or astronomy code.

Behavior
--------
- Checks every 30 seconds.
- Does not launch Terminal if Terminal is closed.
- When Terminal is running, updates:
  * every open Terminal tab
  * Terminal's default settings
  * Terminal's startup settings
- On first installation macOS may ask for Automation permission so the helper can
  control Terminal.
- uninstall.sh restores the default/startup profiles that were active before
  installation when possible. It does not alter existing open tabs on uninstall.

Install
-------
  ./install.sh

The installer is fail-safe:
- It stops and removes any existing recurring LaunchAgent before changing files.
- It preserves the compiled helper app when TerminalSolarProfiles.applescript has
  not changed, avoiding unnecessary rebuilds that can disturb macOS Automation
  authorization.
- It tests the helper before recreating/loading the 30-second LaunchAgent.
- If the helper test fails, the LaunchAgent remains unloaded and its plist remains
  absent, so a failed install cannot leave a repeating error loop behind.

If the AppleScript source itself changed, the helper must be rebuilt. macOS may
ask again whether "Terminal Solar Profiles" may control Terminal. Allow it. If the
test still fails with an Automation error, enable Terminal Solar Profiles for
Terminal in:

  System Preferences -> Security & Privacy -> Privacy -> Automation

and run ./install.sh again.

Status
------
  "$HOME/Library/Application Support/TerminalSolarProfiles/status.sh"

Uninstall
---------
  ./uninstall.sh

Scheduled-run reliability
-------------------------
The LaunchAgent starts the helper through Launch Services with:

  open -n -W -g "Terminal Solar Profiles.app"

The flags are important:
- `-n` forces a fresh application instance, so every scheduled run executes the
  AppleScript's `on run` handler.
- `-W` waits for that instance to finish before the runner checks the error marker.
- `-g` keeps the helper in the background.

An earlier implementation used `open -gj`, which could report success without
proving that `on run` actually executed. A later attempt invoked the compiled
`Contents/MacOS/applet` executable directly; when launched by launchd, that could
lose the app bundle's Automation/TCC identity and fail with Apple event error
-1743 even though Terminal Solar Profiles.app itself was authorized to control
Terminal. Launching a fresh app-bundle instance through Launch Services avoids
both failure modes.

The helper catches AppleScript/Automation failures and writes the real error to
`helper.applescript.err.log` instead of showing an AppleScript error dialog every
30 seconds. The runner treats that marker as a failed run and includes it in
`last-run.log`.

`last-run.log` reports "Terminal Solar Profiles helper completed." only after a
successful helper run. Low-level Launch Services/helper stderr is captured
separately in `helper.err.log`.

Terminal-running detection uses AppleScript rather than `pgrep`, both for normal
runs and uninstall, avoiding false `terminal=not_running` results seen on some
Monterey systems.
