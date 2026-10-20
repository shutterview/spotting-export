#target photoshop
// Spotting Export v1.1
// Spotting Export starten – erscheint in Photoshop unter Datei → Skripten.
// Photoshop startet das Skript selbst im Hintergrund – keine Kurzbefehle-App nötig.
// Tastenkürzel: Bearbeiten → Tastaturbefehle → Anwendungsmenüs → Datei → Skripten.
(function () {
    var appDir = new Folder('~/Library/Application Support/SpottingExport').fsName;
    var script = appDir + '/spotting_export.py';
    if (!new File(script).exists) {
        alert('Spotting Export ist nicht installiert. Bitte install.sh ausführen.');
        return;
    }
    var started = false;
    try {
        if (typeof app.system === 'function') {
            app.system("/usr/bin/nohup /usr/bin/python3 '" + script + "' > /dev/null 2>&1 &");
            started = true;
        }
    } catch (e) {}
    if (!started) {
        var starter = new Folder(appDir + '/Spotting Export Starter.app');
        if (starter.exists) { new File(starter.fsName).execute(); started = true; }
    }
    if (!started) alert('Spotting Export konnte nicht gestartet werden. Bitte install.sh erneut ausführen.');
})();
