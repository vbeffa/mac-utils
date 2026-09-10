on run
    set helperErrorFile to (POSIX path of (path to home folder)) & "Library/Application Support/TerminalSolarProfiles/helper.applescript.err.log"

    -- Clear any stale error marker from a previous run.
    try
        do shell script "/bin/rm -f " & quoted form of helperErrorFile
    end try

    try
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
            set profileExists to exists settings set profileName
            if profileExists is false then
                error "Terminal profile not found: " & profileName number -2700
            end if

            set targetSettings to settings set profileName

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
    on error errMsg number errNum
        my writeError(helperErrorFile, "AppleScript error " & errNum & ": " & errMsg)
    end try
end run

on writeError(errorFile, messageText)
    try
        set errorDir to do shell script "/usr/bin/dirname " & quoted form of errorFile
        do shell script "/bin/mkdir -p " & quoted form of errorDir
        do shell script "/usr/bin/printf '%s\\n' " & quoted form of messageText & " > " & quoted form of errorFile
    end try
end writeError
