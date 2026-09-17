SUN APPEARANCE FOR macOS MONTEREY
=================================

Purpose
-------
Switch macOS to Light at the conventional local sunrise and Dark at the
conventional local sunset without waiting for macOS's one-minute idle period.

The scheduler:
- runs as one stay-open background AppleScript applet;
- checks once per minute from the applet's idle handler;
- gets the current position from Apple's Core Location framework;
- refreshes the position every 30 minutes;
- keeps the last successful location if a refresh temporarily fails;
- falls back to Sedona, Arizona (34.8697, -111.7609) only if no cached location
  is available;
- uses the standard sunrise/sunset apparent-horizon definition (sun center at
  -0.833 degrees);
- does not call a web geolocation service or send your coordinates anywhere.

Installation
------------
1. Open Terminal.
2. cd to this folder.
3. Run:

   ./install.sh

On first run, macOS may ask for Location Services and Automation/System Events
permission for "Sun Appearance". Allow both.

The installer disables macOS Appearance=Auto because this scheduler replaces
it. The current Light/Dark selection will therefore show as Light or Dark in
System Preferences. Night Shift can remain set to Sunset to Sunrise; it is
independent of this scheduler.

Updates preserve the existing compiled "Sun Appearance" helper when
sun_appearance.applescript has not changed. This avoids unnecessary helper
rebuilds that can disturb macOS Location/Automation authorization.

Before loading the LaunchAgent, the installer starts the stay-open helper once
through Launch Services and waits for its initial on-run check to produce a
successful status file. If that test fails, both the helper and LaunchAgent are
left stopped.

Stay-open scheduling
--------------------
Sun Appearance is compiled with:

  osacompile -s

The -s option creates a stay-open applet. The applet performs one appearance
check from its on-run handler, then its on-idle handler repeats the check every
60 seconds. Core Location is still refreshed only when the cached location is
30 minutes old.

The LaunchAgent no longer starts a fresh AppleScript applet every minute.
Instead it supervises one long-lived helper. The helper is launched through
Launch Services so macOS retains the app bundle's Location/Automation identity.

This avoids two earlier launch problems:
- open -gj could report success without proving that the applet's on-run handler
  actually executed, leaving status.txt stale while launchd reported successful
  runs;
- open -n -W -g forced a fresh applet instance and fixed that problem, but
  repeatedly launching an AppleScript applet can expose macOS's Run/Quit startup
  dialog if the Control key happens to be held at launch.

The stay-open helper performs the recurring work internally, so normal modifier
key use does not coincide with a new applet launch every minute.

The LaunchAgent's supervisor stays alive while the helper is running. If the
helper unexpectedly exits, launchd restarts the supervisor, which relaunches the
helper through Launch Services.

Status
------
Run:

  "$HOME/Library/Application Support/SunAppearance/status.sh"

The status file shows the location source, coordinates, solar elevation,
desired appearance, and whether the most recent run switched the appearance.

The status command also reports both:

  launch_agent=loaded
  helper=running

On Monterey, the launch-agent check identifies the loaded service from
launchctl's returned service information rather than relying only on launchctl's
exit status.

Removal
-------
Run:

  ./uninstall.sh

This stops the LaunchAgent supervisor and stay-open helper, removes the installed
files, and restores macOS Appearance=Auto.

Opera
-----
This fixes the macOS transition. It does not work around Opera's separate bug
where Opera may fail to react to a live system appearance change. As observed,
restarting Opera makes it read the current system appearance correctly.

Monterey launchctl note:
This build uses /bin/launchctl and the per-user gui domain (bootstrap/bootout).
