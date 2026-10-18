-- Startet den Kurzbefehl im Hintergrund, damit Photoshop sofort wieder frei ist
set kurzbefehl to "Spotting Export"
try
	set kurzbefehl to do shell script "cat " & quoted form of (POSIX path of (path to home folder) & "Library/Application Support/SpottingExport/kurzbefehl_name.txt")
end try
do shell script "/usr/bin/shortcuts run " & quoted form of kurzbefehl & " > /dev/null 2>&1 &"
