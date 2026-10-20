#target photoshop
// Schriftvorschau für die Infokachel – in Photoshop über Datei → Skripten → Durchsuchen … öffnen.
// Zeigt den Beispieltext in den Schriften, die auf diesem Mac installiert sind.
(function () {
    var fonts = [
        ['HelveticaNeue-Light', 'Helvetica Neue Light'],
        ['HelveticaNeue', 'Helvetica Neue'],
        ['SFProDisplay-Light', 'SF Pro Display Light'],
        ['SFProDisplay-Regular', 'SF Pro Display'],
        ['AvenirNext-Regular', 'Avenir Next']
    ];
    function installed(ps) {
        for (var i = 0; i < app.fonts.length; i++) if (app.fonts[i].postScriptName === ps) return true;
        return false;
    }
    var oldUnits = app.preferences.rulerUnits, oldType = app.preferences.typeUnits;
    app.preferences.rulerUnits = Units.PIXELS; app.preferences.typeUnits = TypeUnits.PIXELS;
    var W = 1620, rowH = 330, H = 140 + fonts.length * rowH;
    var bgc = new SolidColor(); bgc.rgb.red = 150; bgc.rgb.green = 162; bgc.rgb.blue = 185;
    var doc = app.documents.add(W, H, 72, 'Schriftvorschau', NewDocumentMode.RGB, DocumentFill.WHITE);
    doc.selection.selectAll(); doc.selection.fill(bgc); doc.selection.deselect();
    var white = new SolidColor(); white.rgb.red = 255; white.rgb.green = 255; white.rgb.blue = 255;
    var dark = new SolidColor(); dark.rgb.red = 30; dark.rgb.green = 40; dark.rgb.blue = 60;
    function text(str, x, y, size, font, color) {
        var l = doc.artLayers.add(); l.kind = LayerKind.TEXT;
        var t = l.textItem; t.contents = str; t.font = font; t.size = size; t.color = color; t.position = [x, y];
    }
    text('Schriftvorschau Infokachel', 60, 90, 54, 'HelveticaNeue-Bold', dark);
    for (var i = 0; i < fonts.length; i++) {
        var y = 140 + i * rowH;
        var ok = installed(fonts[i][0]);
        text(fonts[i][1] + (ok ? '' : '  (nicht installiert)'), 60, y + 60, 34, 'HelveticaNeue-Medium', dark);
        if (!ok) continue;
        text('\u0192 11.0   1/1000s   ISO 1000   500mm', 60, y + 175, 100, fonts[i][0], white);
        text('Canon EOS R5m2  \u00b7  RF200-800mm F6.3-9 IS USM  \u00b7  shutterview.aviation', 60, y + 265, 46, fonts[i][0], white);
    }
    app.preferences.rulerUnits = oldUnits; app.preferences.typeUnits = oldType;
})();
