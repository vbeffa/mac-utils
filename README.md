# Sun Appearance Utilities for macOS Monterey

Two small local utilities for macOS Monterey that keep the system and Terminal appearance synchronized with the actual local sunrise and sunset.

These were built and tested for **macOS Monterey 12.7.6**.

## Utilities

### 1. SunAppearance

`SunAppearance` replaces macOS's built-in **Appearance → Auto** behavior.

macOS normally waits until the Mac has been idle before switching between Light and Dark appearance. This utility instead checks the sun's actual position and changes the system appearance without waiting for an idle period.

#### Behavior

- Checks the desired appearance every **60 seconds**.
- Uses **Apple Core Location** to obtain the Mac's current latitude and longitude.
- Refreshes the location every **30 minutes**.
- Retains the last successful location if Core Location temporarily fails.
- Falls back to **Sedona, Arizona** (`34.8697, -111.7609`) if no location has ever been obtained.
- Calculates sunrise and sunset locally using the conventional apparent-horizon value of **-0.833°**.
- Does **not** send location information to a web service.
- Changes macOS to:
  - **Light** when the sun is above the sunrise/sunset horizon.
  - **Dark** when the sun is below it.
- Corrects the appearance on the next check after sleep/wake.
- Works when traveling because it uses the Mac's current location and time zone.
- Launches each scheduled helper run as a fresh application instance through Launch Services, preserving the helper's macOS permission identity while ensuring its AppleScript `on run` handler executes.
- Preserves the compiled helper during updates when the AppleScript source has not changed, avoiding unnecessary Location/Automation permission churn.

The installer disables macOS's built-in automatic appearance switching because this utility replaces it. System Settings will therefore show either **Light** or **Dark**, not **Auto**.

Night Shift is independent. It may be **Off**, **Sunset to Sunrise**, or set to any other schedule you prefer.

### 2. Terminal Solar Profiles

`Terminal-Solar-Profiles` is a companion utility that makes Terminal follow the current macOS Light/Dark appearance.

It uses these exact Terminal profiles:

- Dark mode: **Solarized Dark ansi**
- Light mode: **Solarized Light ansi**

#### Behavior

- Checks the current macOS appearance every **30 seconds**.
- Does not perform its own sunrise/sunset calculation; it follows the system appearance managed by SunAppearance.
- Does **not** launch Terminal if Terminal is closed.
- When Terminal is running, it changes:
  - every currently open Terminal tab;
  - Terminal's default profile;
  - Terminal's startup profile.
- Remembers the default and startup profiles that were active before installation so they can be restored during uninstall.
- Uses AppleScript's application-running check rather than `pgrep`, avoiding false `terminal=not_running` results seen on some Monterey systems.

---

## Recommended installation order

Install **SunAppearance first**, then **Terminal-Solar-Profiles**.

Extract each ZIP file before running its installer.

## Installing SunAppearance

Open Terminal, change to the extracted `SunAppearance` directory, and run:

```bash
./install.sh
```

On the first run, macOS may ask for permission for **Sun Appearance** to:

1. use Location Services;
2. control **System Events**.

Allow both.

The LaunchAgent is installed as:

```text
~/Library/LaunchAgents/com.local.sunappearance.plist
```

The installed support files are stored in:

```text
~/Library/Application Support/SunAppearance/
```

On install or update, the helper is tested successfully **before** the recurring LaunchAgent is enabled. If the AppleScript source has not changed, the existing compiled helper app is retained rather than rebuilt.

### Check SunAppearance status

```bash
"$HOME/Library/Application Support/SunAppearance/status.sh"
```

Typical output includes:

```text
location_source=Core Location
latitude=34.863372802734
longitude=-111.784708774933
solar_elevation_deg=-7.006
desired_mode=dark
result=unchanged
current_appearance=dark
macos_auto_enabled=false
launch_agent=loaded
```

`result=unchanged` means the Mac was already in the desired appearance.

### Test SunAppearance

At night, manually select **Light** in System Settings → General → Appearance.

Within approximately 60 seconds, SunAppearance should return the Mac to **Dark**, even if you are actively using it.

During the day, the reverse test can be performed by manually selecting **Dark**.

---

## Installing Terminal Solar Profiles

Before installing, make sure Terminal contains profiles named exactly:

```text
Solarized Dark ansi
Solarized Light ansi
```

Then change to the extracted `Terminal-Solar-Profiles` directory and run:

```bash
./install.sh
```

On the first run, macOS may ask whether **Terminal Solar Profiles** may control Terminal. Allow it.

The LaunchAgent is installed as:

```text
~/Library/LaunchAgents/com.local.terminalsolarprofiles.plist
```

The installed support files are stored in:

```text
~/Library/Application Support/TerminalSolarProfiles/
```

### Check Terminal Solar Profiles status

```bash
"$HOME/Library/Application Support/TerminalSolarProfiles/status.sh"
```

Typical output:

```text
macOS_mode=dark
desired_terminal_profile=Solarized Dark ansi
launch_agent=loaded
terminal=running
default_profile=Solarized Dark ansi
startup_profile=Solarized Dark ansi
front_tab_profile=Solarized Dark ansi
```

If Terminal is closed, `terminal=not_running` is normal. The utility intentionally does not launch Terminal merely to change its profile.

### Test both utilities together

At night:

1. Set macOS Appearance manually to **Light**.
2. Within about 30 seconds, Terminal should switch to **Solarized Light ansi**.
3. Within about 60 seconds, SunAppearance should change macOS back to **Dark**.
4. Within another 30 seconds, Terminal should switch back to **Solarized Dark ansi**.

The timing can be shorter depending on where each LaunchAgent is in its polling interval.

---

## Checking the LaunchAgents

### SunAppearance

```bash
/bin/launchctl print "gui/$(id -u)/com.local.sunappearance"
```

### Terminal Solar Profiles

```bash
/bin/launchctl print "gui/$(id -u)/com.local.terminalsolarprofiles"
```

If the command prints a block of service information, the LaunchAgent is loaded.

---

## Uninstalling

Use the `uninstall.sh` supplied with the corresponding **v2** package.

### Remove SunAppearance

From the extracted `SunAppearance` directory:

```bash
./uninstall.sh
```

This:

- unloads and removes the SunAppearance LaunchAgent;
- removes its installed support files;
- restores macOS **Appearance → Auto**.

Location and Automation permissions can be removed separately in System Preferences if desired.

### Remove Terminal Solar Profiles

From the extracted `Terminal-Solar-Profiles` directory:

```bash
./uninstall.sh
```

This:

- unloads and removes the Terminal Solar Profiles LaunchAgent;
- removes its installed support files;
- attempts to restore the Terminal default and startup profiles that were active when the utility was first installed.

Existing open Terminal tabs are not changed by the uninstaller.

---

## Permissions

The utilities are local scripts and helper applications.

### Sun Appearance

Requires:

- **Location Services** to obtain the current coordinates;
- **Automation / System Events** permission to change macOS Light/Dark appearance.

Coordinates are used locally for the solar calculation and are not sent over the internet.

### Terminal Solar Profiles

Requires:

- **Automation** permission to control Terminal and change its profile settings.

It does not need Location Services because it follows the current macOS appearance.

---

## Troubleshooting

### SunAppearance does not change the system appearance

Run:

```bash
"$HOME/Library/Application Support/SunAppearance/status.sh"
```

Confirm that:

```text
launch_agent=loaded
```

and that `desired_mode` is appropriate for the current time.

If the status timestamp stops advancing even though `launchctl print` shows repeated runs, the helper is not actually executing. The LaunchAgent uses `open -n -W -g` so each interval starts a fresh helper instance through Launch Services.

If the location source says `Core Location`, current-location detection is working. If it uses the fallback, check the Mac's Location Services permissions.

### Terminal does not switch profiles

Run:

```bash
"$HOME/Library/Application Support/TerminalSolarProfiles/status.sh"
```

Confirm:

```text
launch_agent=loaded
terminal=running
```

Also verify that Terminal still has profiles named exactly:

```text
Solarized Dark ansi
Solarized Light ansi
```

Check System Preferences → Security & Privacy → Privacy → Automation if the helper no longer has permission to control Terminal.

---

## Interaction with other applications

The utilities control macOS Appearance and Apple Terminal only.

Applications that correctly follow macOS appearance should normally react when the system switches. Applications with their own theme-sync bugs may not.

For example, the tested version of **Opera One** reads the correct system theme when it launches but may fail to react to a Light/Dark change while already running. Quitting and reopening Opera causes it to read the current macOS appearance. These utilities do not modify Opera.

---

## Files and schedules

| Utility | LaunchAgent | Check interval |
| --- | --- | ---: |
| SunAppearance | `com.local.sunappearance` | 60 seconds |
| Terminal Solar Profiles | `com.local.terminalsolarprofiles` | 30 seconds |

SunAppearance refreshes the Core Location position approximately every **30 minutes** even though it evaluates the desired appearance every minute.

---

## Notes

These utilities use built-in macOS components including AppleScript, JavaScript for Automation, Core Location, `launchd`, `defaults`, and `osacompile`. No third-party runtime, package manager, or internet service is required.
