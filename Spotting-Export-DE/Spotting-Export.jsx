#target photoshop
// Spotting Export starten – erscheint in Photoshop unter Datei → Skripten.
// Tastenkürzel vergeben: Bearbeiten → Tastaturbefehle → Anwendungsmenüs → Datei → Skripten.
(function () {
    var path = '~/Library/Application Support/SpottingExport/Spotting Export Starter.app';
    if (!new Folder(path).exists) {
        alert('Starter nicht gefunden. Bitte install.sh erneut ausführen.');
        return;
    }
    new File(path).execute();
})();
