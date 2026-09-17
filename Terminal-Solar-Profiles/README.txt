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
- Runs as one stay-open background AppleScript applet.
- Checks every 30 seconds from the applet's idle handler.
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
- It stops the existing LaunchAgent supervisor and helper before changing files.
- It preserves the compiled helper app when TerminalSolarProfiles.applescript has
  not changed, avoiding unnecessary rebuilds that can disturb macOS Automation
  authorization.
- It tests the helper's initial profile check before loading the LaunchAgent.
- If that test fails, both the helper and LaunchAgent remain stopped.

If the AppleScript source itself changed, the helper must be rebuilt. macOS may
ask again whether "Terminal Solar Profiles" may control Terminal. Allow it. If the
test still fails with an Automation error, enable Terminal Solar Profiles for
Terminal in:

  System Preferences -> Security & Privacy -> Privacy -> Automation

and run ./install.sh again.

Status
------
  "$HOME/Library/Application Support/TerminalSolarProfiles/status.sh"

The status output includes both:
  launch_agent=loaded
  helper=running

Uninstall
---------
  ./uninstall.sh

Stay-open scheduling
--------------------
Terminal Solar Profiles is compiled with:

  osacompile -s

The -s option creates a stay-open applet. The applet runs one profile sync from
its on-run handler, then its on-idle handler repeats the sync every 30 seconds.

The LaunchAgent no longer starts a fresh AppleScript applet every 30 seconds.
Instead it supervises one long-lived helper. The helper is launched through
Launch Services so macOS retains the app bundle's Automation/TCC identity.

This avoids two earlier failure modes:
- open -gj could report success without proving that the applet's on-run handler
  actually executed.
- open -n -W -g reliably executed a fresh applet, but repeatedly launching an
  AppleScript applet could expose macOS's Run/Quit startup dialog when the Control
  key happened to be held at launch, which is especially disruptive during Emacs
  use.

The stay-open helper performs the recurring work internally, so normal modifier
key use does not coincide with a new applet launch every 30 seconds.

The helper catches AppleScript/Automation failures and writes the real error to
helper.applescript.err.log rather than displaying an AppleScript error dialog.
last-run.log is updated after every check with either a success, a skipped check
because Terminal is closed, or the captured error.

The LaunchAgent's runner stays alive while the helper is running. If the helper
unexpectedly exits, launchd restarts the supervisor, which relaunches the helper
through Launch Services.

Terminal-running detection uses AppleScript rather than pgrep, avoiding false
terminal=not_running results seen on some Monterey systems.
