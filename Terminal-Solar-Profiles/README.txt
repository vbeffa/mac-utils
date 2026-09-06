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

Status
------
  "$HOME/Library/Application Support/TerminalSolarProfiles/status.sh"

Uninstall
---------
  ./uninstall.sh
