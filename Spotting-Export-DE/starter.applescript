-- Rückfallebene: startet das Skript direkt im Hintergrund (ohne Kurzbefehle-App)
do shell script "/usr/bin/nohup /usr/bin/python3 " & quoted form of (POSIX path of (path to home folder) & "Library/Application Support/SpottingExport/spotting_export.py") & " > /dev/null 2>&1 &"
