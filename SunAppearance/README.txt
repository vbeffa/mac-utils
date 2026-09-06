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

Status
------
Run:

  "$HOME/Library/Application Support/SunAppearance/status.sh"

The status file shows the location source, coordinates, solar elevation,
desired appearance, and whether the most recent run switched the appearance.

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
