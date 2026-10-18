#target photoshop
// Starts Spotting Export – appears in Photoshop under File → Scripts.
// Assign a shortcut: Edit → Keyboard Shortcuts → Application Menus → File → Scripts.
(function () {
    var path = '~/Library/Application Support/SpottingExport/Spotting Export Launcher.app';
    if (!new Folder(path).exists) {
        alert('Launcher not found. Please run install.sh again.');
        return;
    }
    new File(path).execute();
})();
