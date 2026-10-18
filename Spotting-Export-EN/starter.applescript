-- Runs the shortcut in the background so Photoshop is free again immediately
set shortcutName to "Spotting Export"
try
	set shortcutName to do shell script "cat " & quoted form of (POSIX path of (path to home folder) & "Library/Application Support/SpottingExport/shortcut_name.txt")
end try
do shell script "/usr/bin/shortcuts run " & quoted form of shortcutName & " > /dev/null 2>&1 &"
