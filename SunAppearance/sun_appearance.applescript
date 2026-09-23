use AppleScript version "2.4"
use framework "Foundation"
use framework "CoreLocation"
use scripting additions

property fallbackLat : 34.8697
property fallbackLon : -111.7609
property cacheMaxAge : 1800 -- refresh Core Location every 30 minutes
property locationTimeout : 15 -- seconds to wait for a fresh location
property checkInterval : 60 -- evaluate appearance once per minute

on run
    my checkAppearance_()
end run

on idle
    my checkAppearance_()
    return checkInterval
end idle

on checkAppearance_()
    set homePath to POSIX path of (path to home folder)
    set basePath to homePath & "Library/Application Support/SunAppearance"
    set cachePath to basePath & "/location.txt"
    set debugLogPath to basePath & "/location-debug.log"
    set solarScript to basePath & "/sun_state.js"
    set statusPath to basePath & "/status.txt"

    try
        do shell script "/bin/mkdir -p " & quoted form of basePath

        set lat to fallbackLat
        set lon to fallbackLon
        set locSource to "Sedona fallback"
        set needLocation to true

        -- Use a recent Core Location fix without waking Location Services every minute.
        try
            set mtime to (do shell script "/usr/bin/stat -f %m " & quoted form of cachePath) as integer
            set nowEpoch to (do shell script "/bin/date +%s") as integer
            set cacheAge to nowEpoch - mtime
            if cacheAge < cacheMaxAge then
                set cacheData to do shell script "/bin/cat " & quoted form of cachePath
                set parsedLocation to my parseLocation_(cacheData)
                set lat to item 1 of parsedLocation
                set lon to item 2 of parsedLocation
                set locSource to "cached Core Location"
                set needLocation to false
            else
                my logLocation_(debugLogPath, "refresh_due cache_age=" & (cacheAge as text))
            end if
        on error errText number errNum
            my logLocation_(debugLogPath, "cache_unavailable error=" & (errNum as text) & " message=" & errText)
        end try

        if needLocation then
            set freshLocation to my getCurrentLocation_(locationTimeout, debugLogPath)
            if freshLocation is not missing value then
                set lat to item 1 of freshLocation
                set lon to item 2 of freshLocation
                set locSource to "Core Location"
                do shell script "/usr/bin/printf '%s %s\\n' " & quoted form of (lat as text) & " " & quoted form of (lon as text) & " > " & quoted form of cachePath
                my logLocation_(debugLogPath, "location_cache_updated")
            else
                -- If Location Services is temporarily unavailable, retain the last
                -- successful position. Sedona is used only when no cache exists.
                try
                    set cacheData to do shell script "/bin/cat " & quoted form of cachePath
                    set parsedLocation to my parseLocation_(cacheData)
                    set lat to item 1 of parsedLocation
                    set lon to item 2 of parsedLocation
                    set locSource to "stale Core Location cache"
                    my logLocation_(debugLogPath, "fresh_location_unavailable using=stale_cache")
                on error
                    my logLocation_(debugLogPath, "fresh_location_unavailable using=sedona_fallback")
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
    on error errText number errNum
        -- A stay-open helper must never surface an AppleScript error dialog on a
        -- scheduled idle run. Record the failure in status.txt instead.
        try
            set stamp to do shell script "/bin/date '+%Y-%m-%d %H:%M:%S %Z'"
            set statusText to stamp & linefeed & "result=ERROR " & errNum & ": " & errText & linefeed
            do shell script "/usr/bin/printf %s " & quoted form of statusText & " > " & quoted form of statusPath
        end try
    end try
end checkAppearance_

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

on getCurrentLocation_(timeoutSeconds, debugLogPath)
    try
        set manager to current application's CLLocationManager's alloc()'s init()
        manager's setDesiredAccuracy_(1000.0)
        my logLocation_(debugLogPath, "manager_created")

        -- Keep the existing authorization behavior unchanged for this diagnostic
        -- change. The log records exactly what Monterey reports before a refresh.
        set authStatus to (current application's CLLocationManager's authorizationStatus()) as integer
        set authText to my authStatusText_(authStatus)
        my logLocation_(debugLogPath, "authorization_before=" & authText & " code=" & (authStatus as text))

        if authStatus is 0 then
            my logLocation_(debugLogPath, "requestWhenInUseAuthorization")
            manager's requestWhenInUseAuthorization()
            try
                set postRequestStatus to (current application's CLLocationManager's authorizationStatus()) as integer
                set postRequestText to my authStatusText_(postRequestStatus)
                my logLocation_(debugLogPath, "authorization_after_request=" & postRequestText & " code=" & (postRequestStatus as text))
            end try
        else if authStatus is 1 or authStatus is 2 then
            my logLocation_(debugLogPath, "refresh_aborted authorization=" & authText)
            return missing value
        end if

        my logLocation_(debugLogPath, "startUpdatingLocation")
        manager's startUpdatingLocation()
        set deadline to current application's NSDate's dateWithTimeIntervalSinceNow_(timeoutSeconds)
        set goodLocation to missing value
        set goodAge to missing value

        repeat while ((deadline's timeIntervalSinceNow()) as real) > 0
            current application's NSRunLoop's currentRunLoop()'s runUntilDate_(current application's NSDate's dateWithTimeIntervalSinceNow_(0.25))
            set candidate to manager's |location|()
            if candidate is not missing value then
                try
                    set ageSeconds to -1 * ((candidate's |timestamp|()'s timeIntervalSinceNow()) as real)
                    if ageSeconds > -60 and ageSeconds < 600 then
                        set goodLocation to candidate
                        set goodAge to ageSeconds
                        exit repeat
                    end if
                end try
            end if
        end repeat

        manager's stopUpdatingLocation()

        if goodLocation is missing value then
            try
                set finalStatus to (current application's CLLocationManager's authorizationStatus()) as integer
                set finalText to my authStatusText_(finalStatus)
                my logLocation_(debugLogPath, "location_timeout authorization_after=" & finalText & " code=" & (finalStatus as text))
            on error
                my logLocation_(debugLogPath, "location_timeout")
            end try
            return missing value
        end if

        if goodAge is not missing value then
            my logLocation_(debugLogPath, "location_received age_seconds=" & (goodAge as text))
        else
            my logLocation_(debugLogPath, "location_received")
        end if

        try
            set finalStatus to (current application's CLLocationManager's authorizationStatus()) as integer
            set finalText to my authStatusText_(finalStatus)
            my logLocation_(debugLogPath, "refresh_complete authorization_after=" & finalText & " code=" & (finalStatus as text))
        end try

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
    on error errText number errNum
        try
            manager's stopUpdatingLocation()
        end try
        my logLocation_(debugLogPath, "refresh_error number=" & (errNum as text) & " message=" & errText)
        return missing value
    end try
end getCurrentLocation_

on authStatusText_(authStatus)
    if authStatus is 0 then return "not_determined"
    if authStatus is 1 then return "restricted"
    if authStatus is 2 then return "denied"
    if authStatus is 3 then return "authorized_always"
    if authStatus is 4 then return "authorized_when_in_use"
    return "unknown"
end authStatusText_

on logLocation_(logPath, messageText)
    try
        set stamp to do shell script "/bin/date '+%Y-%m-%d %H:%M:%S %Z'"
        set processID to (current application's NSProcessInfo's processInfo()'s processIdentifier()) as integer
        set logLine to stamp & " pid=" & (processID as text) & " " & messageText
        do shell script "/usr/bin/printf '%s\\n' " & quoted form of logLine & " >> " & quoted form of logPath
    end try
end logLocation_
