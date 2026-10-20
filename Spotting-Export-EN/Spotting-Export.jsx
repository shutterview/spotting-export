#target photoshop
// Spotting Export v1.1
// Starts Spotting Export – appears in Photoshop under File → Scripts.
// Photoshop starts the script itself in the background – no Shortcuts app needed.
// Keyboard shortcut: Edit → Keyboard Shortcuts → Application Menus → File → Scripts.
(function () {
    var appDir = new Folder('~/Library/Application Support/SpottingExport').fsName;
    var script = appDir + '/spotting_export.py';
    if (!new File(script).exists) {
        alert('Spotting Export is not installed. Please run install.sh.');
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
        var starter = new Folder(appDir + '/Spotting Export Launcher.app');
        if (starter.exists) { new File(starter.fsName).execute(); started = true; }
    }
    if (!started) alert('Spotting Export could not be started. Please run install.sh again.');
})();
