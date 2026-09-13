SUN APPEARANCE FOR macOS MONTEREY
=================================

Purpose
-------
Switch macOS to Light at the conventional local sunrise and Dark at the
conventional local sunset without waiting for macOS's one-minute idle period.

The scheduler:
- checks once per minute;
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

Before loading the recurring LaunchAgent, the installer runs the helper once
through Launch Services and verifies that it produced a successful status file.
If that test fails, the LaunchAgent remains unloaded.

Scheduled-run reliability
-------------------------
The LaunchAgent uses:

  /usr/bin/open -n -W -g "Sun Appearance.app"

Launching the application bundle through Launch Services preserves its macOS
permission identity. The -n option forces a fresh application instance so the
AppleScript on-run handler executes on every interval; -W waits for that run to
finish; and -g keeps the helper in the background.

The older -gj invocation could return success while reusing an already-known
application instance without executing on run again. In that state launchd
continued to report successful 60-second runs while status.txt and the cached
location stopped updating.

Status
------
Run:

  "$HOME/Library/Application Support/SunAppearance/status.sh"

The status file shows the location source, coordinates, solar elevation,
desired appearance, and whether the most recent run switched the appearance.

The status command also checks launchd for the installed service. On Monterey,
it identifies the loaded service from launchctl's returned service information
rather than relying only on launchctl's exit status.

Removal
-------
Run:

  ./uninstall.sh

This removes the LaunchAgent/helper and restores macOS Appearance=Auto.

Opera
-----
This fixes the macOS transition. It does not work around Opera's separate bug
where Opera may fail to react to a live system appearance change. As observed,
restarting Opera makes it read the current system appearance correctly.


Monterey launchctl note:
This build uses /bin/launchctl and the per-user gui domain (bootstrap/bootout).
