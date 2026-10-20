-- Fallback: starts the script directly in the background (no Shortcuts app)
do shell script "/usr/bin/nohup /usr/bin/python3 " & quoted form of (POSIX path of (path to home folder) & "Library/Application Support/SpottingExport/spotting_export.py") & " > /dev/null 2>&1 &"
