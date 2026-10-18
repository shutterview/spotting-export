// Klickt in Lightroom Classic den Menüpunkt des Spotting Export-Plugins an.
// Aufruf: osascript -l JavaScript lr_menu.js <bundle-id> <menütitel>
function run(argv) {
    var bid = argv[0], title = argv[1];
    function same(a) { return String(a || '').normalize('NFC').toLowerCase().indexOf(String(title).normalize('NFC').toLowerCase()) === 0; }
    var se = Application('System Events');
    var procs = se.processes.whose({ bundleIdentifier: bid });
    if (procs.length === 0) return 'kein-prozess';
    var bar = procs[0].menuBars[0];
    var tops = bar.menuBarItems();
    for (var i = 0; i < tops.length; i++) {
        var items;
        try { items = tops[i].menus[0].menuItems; } catch (e) { continue; }
        var names;
        try { names = items.name(); } catch (e) { continue; }
        for (var j = 0; j < names.length; j++) {
            var n = String(names[j] || '');
            if (same(n)) { items[j].click(); return 'ok'; }
            // Untermenü "Zusatzmoduloptionen" / "Plug-in Extras" durchsuchen
            if (/zusatzmodul|plug-?in/i.test(n)) {
                try {
                    var sub = items[j].menus[0].menuItems;
                    var subNames = sub.name();
                    for (var k = 0; k < subNames.length; k++) {
                        if (same(subNames[k]) && sub[k].enabled()) { sub[k].click(); return 'ok'; }
                    }
                } catch (e) {}
            }
        }
    }
    return 'nicht-gefunden';
}
