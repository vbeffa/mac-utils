use AppleScript version "2.4"
use framework "Foundation"
use framework "CoreLocation"
use scripting additions

property fallbackLat : 34.8697
property fallbackLon : -111.7609
property cacheMaxAge : 1800 -- refresh Core Location every 30 minutes
property locationTimeout : 15 -- seconds to wait for a fresh location

on run
    set homePath to POSIX path of (path to home folder)
    set basePath to homePath & "Library/Application Support/SunAppearance"
    set cachePath to basePath & "/location.txt"
    set solarScript to basePath & "/sun_state.js"
    set statusPath to basePath & "/status.txt"

    do shell script "/bin/mkdir -p " & quoted form of basePath

    set lat to fallbackLat
    set lon to fallbackLon
    set locSource to "Sedona fallback"
    set needLocation to true

    -- Use a recent Core Location fix without waking Location Services every minute.
    try
        set mtime to (do shell script "/usr/bin/stat -f %m " & quoted form of cachePath) as integer
        set nowEpoch to (do shell script "/bin/date +%s") as integer
        if (nowEpoch - mtime) < cacheMaxAge then
            set cacheData to do shell script "/bin/cat " & quoted form of cachePath
            set parsedLocation to my parseLocation_(cacheData)
            set lat to item 1 of parsedLocation
            set lon to item 2 of parsedLocation
            set locSource to "cached Core Location"
            set needLocation to false
        end if
    end try

    if needLocation then
        set freshLocation to my getCurrentLocation_(locationTimeout)
        if freshLocation is not missing value then
            set lat to item 1 of freshLocation
            set lon to item 2 of freshLocation
            set locSource to "Core Location"
            do shell script "/usr/bin/printf '%s %s\\n' " & quoted form of (lat as text) & " " & quoted form of (lon as text) & " > " & quoted form of cachePath
        else
            -- If Location Services is temporarily unavailable, retain the last
            -- successful position.  Sedona is used only when no cache exists.
            try
                set cacheData to do shell script "/bin/cat " & quoted form of cachePath
                set parsedLocation to my parseLocation_(cacheData)
                set lat to item 1 of parsedLocation
                set lon to item 2 of parsedLocation
                set locSource to "stale Core Location cache"
            end try
        end if
    end if

    set solarInfo to do shell script "/usr/bin/osascript -l JavaScript " & quoted form of solarScript & " " & quoted form of (lat as text) & " " & quoted form of (lon as text)
    set oldTIDs to AppleScript's text item delimiters
    set AppleScript's text item delimiters to "|"
    set solarParts to text items of solarInfo
    set AppleScript's text item delimiters to oldTIDs

    set desiredMode to item 1 of solarParts
    set solarElevation to item 2 of solarParts
    set switchResult to "unchanged"

    try
        tell application "System Events"
            tell appearance preferences
                set isDark to dark mode
                if desiredMode is "dark" and isDark is false then
                    set dark mode to true
                    set switchResult to "switched to dark"
                else if desiredMode is "light" and isDark is true then
                    set dark mode to false
                    set switchResult to "switched to light"
                end if
            end tell
        end tell
        -- This scheduler deliberately replaces macOS Auto so the built-in
        -- one-minute-idle delay cannot undo or postpone the transition.
        do shell script "/usr/bin/defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool false"
    on error errText number errNum
        set switchResult to "ERROR " & errNum & ": " & errText
    end try

    set stamp to do shell script "/bin/date '+%Y-%m-%d %H:%M:%S %Z'"
    set statusText to stamp & linefeed & ¬
        "location_source=" & locSource & linefeed & ¬
        "latitude=" & (lat as text) & linefeed & ¬
        "longitude=" & (lon as text) & linefeed & ¬
        "solar_elevation_deg=" & solarElevation & linefeed & ¬
        "desired_mode=" & desiredMode & linefeed & ¬
        "result=" & switchResult & linefeed

    do shell script "/usr/bin/printf %s " & quoted form of statusText & " > " & quoted form of statusPath
end run

on parseLocation_(cacheData)
    set oldTIDs to AppleScript's text item delimiters
    set AppleScript's text item delimiters to {" ", tab, linefeed, return}
    set pieces to text items of cacheData
    set AppleScript's text item delimiters to oldTIDs

    set cleanPieces to {}
    repeat with p in pieces
        if (p as text) is not "" then set end of cleanPieces to (p as text)
    end repeat
    if (count of cleanPieces) < 2 then error "Invalid cached location"
    return {(item 1 of cleanPieces) as real, (item 2 of cleanPieces) as real}
end parseLocation_

on getCurrentLocation_(timeoutSeconds)
    try
        set manager to current application's CLLocationManager's alloc()'s init()
        manager's setDesiredAccuracy_(1000.0)

        set authStatus to (current application's CLLocationManager's authorizationStatus()) as integer
        if authStatus is 0 then
            manager's requestWhenInUseAuthorization()
        else if authStatus is 1 or authStatus is 2 then
            return missing value
        end if

        manager's startUpdatingLocation()
        set deadline to current application's NSDate's dateWithTimeIntervalSinceNow_(timeoutSeconds)
        set goodLocation to missing value

        repeat while ((deadline's timeIntervalSinceNow()) as real) > 0
            current application's NSRunLoop's currentRunLoop()'s runUntilDate_(current application's NSDate's dateWithTimeIntervalSinceNow_(0.25))
            set candidate to manager's |location|()
            if candidate is not missing value then
                try
                    set ageSeconds to -1 * ((candidate's |timestamp|()'s timeIntervalSinceNow()) as real)
                    if ageSeconds > -60 and ageSeconds < 600 then
                        set goodLocation to candidate
                        exit repeat
                    end if
                end try
            end if
        end repeat

        manager's stopUpdatingLocation()
        if goodLocation is missing value then return missing value

        -- CLLocationCoordinate2D is bridged as an NSValue in AppleScriptObjC.
        try
            set coordPoint to goodLocation's coordinate's pointValue()
            set lat to (coordPoint's x) as real
            set lon to (coordPoint's y) as real
            return {lat, lon}
        on error
            -- Fallback for AppleScriptObjC bridge differences on older systems.
            set descText to goodLocation's |description|() as text
            set ltPos to (offset of "<" in descText)
            set commaPos to (offset of "," in descText)
            set gtPos to (offset of ">" in descText)
            if ltPos = 0 or commaPos = 0 or gtPos = 0 then return missing value
            set latText to text (ltPos + 1) thru (commaPos - 1) of descText
            set lonText to text (commaPos + 1) thru (gtPos - 1) of descText
            return {latText as real, lonText as real}
        end try
    on error
        try
            manager's stopUpdatingLocation()
        end try
        return missing value
    end try
end getCurrentLocation_
