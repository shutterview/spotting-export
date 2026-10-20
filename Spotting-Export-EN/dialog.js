// Spotting Export – input window
// Usage: osascript -l JavaScript dialog.js '<json>'  ->  returns JSON {button, values}
ObjC.import('Cocoa');

function run(argv) {
    var cfg = JSON.parse(argv[0]);
    var app = $.NSApplication.sharedApplication;
    app.setActivationPolicy(1);                 // accessory: window without Dock icon
    app.activateIgnoringOtherApps(true);

    var alert = $.NSAlert.alloc.init;
    alert.messageText = 'Spotting Export';
    alert.informativeText = cfg.info || '';
    alert.addButtonWithTitle('OK');
    alert.addButtonWithTitle('Cancel');
    alert.addButtonWithTitle('Change export folder …');
    alert.buttons.objectAtIndex(1).keyEquivalent = '\u001b';   // Esc = Cancel

    var rows = [
        ['kennzeichen', 'Registration', 'text'],
        ['airline', 'Airline', 'combo', cfg.airlines || []],
        ['familie', 'Aircraft type', 'combo', cfg.familien || []],
        ['flughafen', 'Airport', 'combo', cfg.flughaefen || []],
        ['runway', 'Runway', 'text'],
        ['richtung', 'Direction', 'popup', ['right', 'left']],
        ['format', 'Format', 'popup', ['8x5', '12x5', '16x5', '20x5']],
        ['freitext', 'Extra', 'text']
    ];
    var RH = 32, VW = 440, VH = rows.length * RH;
    var view = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, VW, VH));
    var ctrls = {};
    var values = cfg.values || {};
    var ph = cfg.placeholder || {};

    rows.forEach(function (r, i) {
        var y = VH - (i + 1) * RH + 4;
        var lab = $.NSTextField.labelWithString(r[1]);
        lab.frame = $.NSMakeRect(0, y + 3, 110, 20);
        view.addSubview(lab);
        var rect = $.NSMakeRect(115, y, VW - 115, 24);
        var v = values[r[0]] || '';
        var c;
        if (r[2] === 'popup') {
            c = $.NSPopUpButton.alloc.initWithFramePullsDown(rect, false);
            c.addItemsWithTitles($(r[3]));
            if (v) c.selectItemWithTitle(v);
        } else if (r[2] === 'combo') {
            c = $.NSComboBox.alloc.initWithFrame(rect);
            if (r[3].length) c.addItemsWithObjectValues($(r[3]));
            c.completes = true;
            c.numberOfVisibleItems = 12;
            c.stringValue = v;
        } else {
            c = $.NSTextField.alloc.initWithFrame(rect);
            c.stringValue = v;
        }
        if (r[2] !== 'popup' && ph[r[0]]) c.placeholderString = ph[r[0]];
        view.addSubview(c);
        ctrls[r[0]] = [c, r[2]];
    });

    alert.accessoryView = view;
    alert.window.autorecalculatesKeyViewLoop = true;
    alert.window.initialFirstResponder = ctrls[cfg.fokus || 'kennzeichen'][0];

    var resp = alert.runModal;
    var out = { button: resp == 1000 ? 'ok' : (resp == 1002 ? 'speicherort' : 'abbrechen'), values: {} };
    for (var k in ctrls) {
        var c = ctrls[k][0];
        out.values[k] = ctrls[k][1] === 'popup' ? ObjC.unwrap(c.titleOfSelectedItem) : ObjC.unwrap(c.stringValue);
    }
    return JSON.stringify(out);
}
