on run
    -- Do not launch Terminal just to change its profile.
    if application "Terminal" is not running then return

    set interfaceStyle to ""
    try
        set interfaceStyle to do shell script "/usr/bin/defaults read -g AppleInterfaceStyle 2>/dev/null || true"
    end try

    if interfaceStyle contains "Dark" then
        set profileName to "Solarized Dark ansi"
    else
        set profileName to "Solarized Light ansi"
    end if

    tell application "Terminal"
        try
            set targetSettings to settings set profileName
        on error
            error "Terminal profile not found: " & profileName
        end try

        -- Make future Terminal windows/startups use the matching profile.
        set default settings to targetSettings
        set startup settings to targetSettings

        -- Switch every currently open tab as well.
        repeat with w in windows
            repeat with t in tabs of w
                try
                    set current settings of t to targetSettings
                end try
            end repeat
        end repeat
    end tell
end run
