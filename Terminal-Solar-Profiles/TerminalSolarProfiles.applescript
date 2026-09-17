property checkInterval : 30

on run
    my syncProfile()
end run

on idle
    my syncProfile()
    return checkInterval
end idle

on syncProfile()
    set supportDir to (POSIX path of (path to home folder)) & "Library/Application Support/TerminalSolarProfiles"
    set helperErrorFile to supportDir & "/helper.applescript.err.log"
    set logFile to supportDir & "/last-run.log"

    try
        do shell script "/bin/rm -f " & quoted form of helperErrorFile
    end try

    try
        if application "Terminal" is not running then
            my writeLog(logFile, "Terminal is not running; nothing to change.")
            return
        end if

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
            set default settings to targetSettings
            set startup settings to targetSettings

            repeat with w in windows
                repeat with t in tabs of w
                    try
                        set current settings of t to targetSettings
                    end try
                end repeat
            end repeat
        end tell

        my writeLog(logFile, "Terminal Solar Profiles helper completed.")
    on error errMsg number errNum
        set errorText to "AppleScript error " & errNum & ": " & errMsg
        my writeText(helperErrorFile, errorText & linefeed)
        my writeLog(logFile, "ERROR: Terminal Solar Profiles helper failed." & linefeed & linefeed & "AppleScript error:" & linefeed & errorText)
    end try
end syncProfile

on writeLog(logFile, messageText)
    try
        set stamp to do shell script "/bin/date"
        my writeText(logFile, stamp & linefeed & messageText & linefeed)
    end try
end writeLog

on writeText(filePath, textValue)
    try
        set parentDir to do shell script "/usr/bin/dirname " & quoted form of filePath
        do shell script "/bin/mkdir -p " & quoted form of parentDir
        do shell script "/usr/bin/printf %s " & quoted form of textValue & " > " & quoted form of filePath
    end try
end writeText
