on run arguments
    if (count of arguments) is not 2 then error "Expected the mounted volume name and path."

    set volumeName to item 1 of arguments
    set mountPath to item 2 of arguments
    set mountedVolume to POSIX file mountPath as alias

    tell application "Finder"
        open mountedVolume
        tell disk (volumeName as text)
            set dmgWindow to container window
            set current view of dmgWindow to icon view
            set toolbar visible of dmgWindow to false
            set statusbar visible of dmgWindow to false
            set pathbar visible of dmgWindow to false
            set bounds of dmgWindow to {100, 100, 740, 500}

            set viewOptions to icon view options of dmgWindow
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 128
            set text size of viewOptions to 15
            set background picture of viewOptions to file ".background:background.png"

            set position of item "ClipApp.app" to {160, 205}
            set position of item "Applications" to {480, 205}
            set extension hidden of item "ClipApp.app" to true

            update without registering applications
            delay 2
            close dmgWindow
        end tell
    end tell
end run
