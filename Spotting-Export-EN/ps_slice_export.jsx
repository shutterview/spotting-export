#target photoshop
// Spotting Export – Photoshop part. Wird vom Python-Skript aufgerufen,
// Parameter (Variable P) werden vom Python-Skript vorangestellt.

var __FA_RESULT = (function () {
    function q(s) {
        s = String(s);
        var out = '"';
        for (var i = 0; i < s.length; i++) {
            var c = s.charAt(i), code = s.charCodeAt(i);
            if (c === '"' || c === '\\') out += '\\' + c;
            else if (code < 32 || code > 126) {
                var h = code.toString(16);
                while (h.length < 4) h = '0' + h;
                out += '\\u' + h;
            } else out += c;
        }
        return out + '"';
    }
    function toJSON(o) {
        var parts = [];
        for (var k in o) {
            var v = o[k];
            parts.push(q(k) + ':' + (typeof v === 'string' ? q(v) : String(v)));
        }
        return '{' + parts.join(',') + '}';
    }

    // Exakt der Weg "Für Web speichern" (Originalgröße, Qualität max.).
    // "Für Web speichern" kann max. 8192 px pro Seite – darüber JPEG-Fallback in Qualität 12.
    function saveWeb(d, path, quality) {
        var f = new File(path);
        var maxSide = Math.max(d.width.as('px'), d.height.as('px'));
        if (maxSide <= 8192) {
            var o = new ExportOptionsSaveForWeb();
            o.format = SaveDocumentType.JPEG;
            o.quality = quality;
            o.optimized = true;
            o.interlaced = false;
            o.includeProfile = true;
            o.blur = 0;
            d.exportDocument(f, ExportType.SAVEFORWEB, o);
        } else {
            var j = new JPEGSaveOptions();
            j.quality = 12;
            j.embedColorProfile = true;
            j.formatOptions = FormatOptions.STANDARDBASELINE;
            j.matte = MatteType.NONE;
            d.saveAs(f, j, true, Extension.LOWERCASE);
        }
    }

    // Aufnahmedatum als YYYYMMDD aus den Metadaten (XMP bevorzugt, dann Dokumentinfo)
    function captureDate(d) {
        try {
            var x = String(d.xmpMetadata.rawData);
            var keys = ['exif:DateTimeOriginal', 'photoshop:DateCreated', 'xmp:CreateDate'];
            for (var i = 0; i < keys.length; i++) {
                var m = x.match(new RegExp(keys[i] + '(?:="|>)(\\d{4})-(\\d{2})-(\\d{2})'));
                if (m) return m[1] + m[2] + m[3];
            }
        } catch (e) {}
        try {
            var c = String(d.info.creationDate || '');
            var m2 = c.match(/^(\d{4})-?(\d{2})-?(\d{2})/);
            if (m2) return m2[1] + m2[2] + m2[3];
        } catch (e) {}
        return '';
    }

    // Rohwerte der Aufnahmedaten aus dem XMP (Formatierung übernimmt Python)
    function xmpValue(x, key) {
        var m = x.match(new RegExp(key + '="([^"]*)"'));
        if (m) return m[1];
        m = x.match(new RegExp('<' + key + '>\\s*(?:<rdf:(?:Seq|Bag|Alt)>\\s*<rdf:li[^>]*>)?([^<]*)<'));
        return m ? m[1] : '';
    }
    function exifInfo(d) {
        var r = { fnum: '', exposure: '', iso: '', focal: '', camera: '', lens: '' };
        try {
            var x = String(d.xmpMetadata.rawData);
            r.fnum = xmpValue(x, 'exif:FNumber');
            r.exposure = xmpValue(x, 'exif:ExposureTime');
            r.iso = xmpValue(x, 'exifEX:PhotographicSensitivity') || xmpValue(x, 'exif:ISOSpeedRatings');
            r.focal = xmpValue(x, 'exif:FocalLength');
            r.camera = xmpValue(x, 'tiff:Model');
            r.lens = xmpValue(x, 'exifEX:LensModel') || xmpValue(x, 'aux:Lens');
        } catch (e) {}
        return r;
    }

    function prepare(d) {
        app.activeDocument = d;
        try { d.flatten(); } catch (e) {}
        if (d.mode !== DocumentMode.RGB) d.changeMode(ChangeMode.RGB);
        try { d.convertProfile('sRGB IEC61966-2.1', Intent.RELATIVECOLORIMETRIC, true, true); } catch (e) {}
        if (d.bitsPerChannel !== BitsPerChannelType.EIGHT) d.bitsPerChannel = BitsPerChannelType.EIGHT;
    }

    var oldUnits = app.preferences.rulerUnits;
    var oldDialogs = app.displayDialogs;
    try {
        if (typeof P === 'undefined') return toJSON({ ok: false, error: 'No parameters received from the assistant.' });

        app.preferences.rulerUnits = Units.PIXELS;
        app.displayDialogs = DialogModes.NO;

        if (P.phase === 'closeall') {
            while (app.documents.length > 0) app.activeDocument.close(SaveOptions.DONOTSAVECHANGES);
            return toJSON({ ok: true });
        }

        if (P.phase === 'carousel') {
            var oldType = app.preferences.typeUnits;
            app.preferences.typeUnits = TypeUnits.PIXELS;
            try {
                var TW = P.tile_w, TH = P.tile_h, n = P.slices, idx = 1, sc = TW / 1620;
                var outDir = new Folder(P.out_dir);
                if (!outDir.exists) outDir.create();
                var white = new SolidColor(); white.rgb.red = 255; white.rgb.green = 255; white.rgb.blue = 255;
                var black = new SolidColor(); black.rgb.red = 0; black.rgb.green = 0; black.rgb.blue = 0;

                var pad = function (i) { return (i < 10 ? '0' : '') + i + '.jpg'; };
                var openFile = function (path) { var d = app.open(new File(path)); prepare(d); return d; };
                var resizeTo = function (d, w, h) {
                    d.resizeImage(UnitValue(Math.round(w), 'px'), UnitValue(Math.round(h), 'px'), 72, ResampleMethod.BICUBIC);
                };
                var saveJpg = function (d, name) {
                    app.activeDocument = d;
                    try { d.flatten(); } catch (e) {}
                    var o = new JPEGSaveOptions();
                    o.quality = P.jpg_quality; o.embedColorProfile = true;
                    o.formatOptions = FormatOptions.STANDARDBASELINE; o.matte = MatteType.NONE;
                    d.saveAs(new File(outDir.fsName + '/' + name), o, true, Extension.LOWERCASE);
                };
                var moveLayerTo = function (layer, target) {     // Ebene in anderes Dokument kopieren
                    try { layer.isBackgroundLayer = false; } catch (e) {}
                    return layer.duplicate(target, ElementPlacement.PLACEATBEGINNING);
                };
                var centerLayer = function (layer, cx, cy) {
                    var b = layer.bounds;
                    layer.translate(cx - (b[0].as('px') + b[2].as('px')) / 2, cy - (b[1].as('px') + b[3].as('px')) / 2);
                };
                var background = function (darken) {             // Front-Slice, stark verschwommen
                    var d = openFile(P.front_file);
                    resizeTo(d, TW, TH);
                    d.activeLayer.applyGaussianBlur(P.blur * sc);
                    if (darken > 0) {
                        var l = d.artLayers.add();
                        d.selection.selectAll(); d.selection.fill(black); d.selection.deselect();
                        l.opacity = darken;
                    }
                    return d;
                };
                var fontOk = {};
                var pickFont = function (name) {
                    if (fontOk[name] !== undefined) return fontOk[name] ? name : P.font_fallback;
                    var ok = false;
                    for (var i = 0; i < app.fonts.length && !ok; i++) ok = app.fonts[i].postScriptName === name;
                    fontOk[name] = ok;
                    return ok ? name : P.font_fallback;
                };

                // 1) Titelkachel: verschwommener Front-Slice + 16x9 mittig in voller Breite
                var bg = background(0);
                if (P.original_file) {
                    var o = openFile(P.original_file);
                    var s = Math.min(TW / o.width.as('px'), TH / o.height.as('px'));
                    resizeTo(o, o.width.as('px') * s, o.height.as('px') * s);
                    var lay = moveLayerTo(o.activeLayer, bg);
                    o.close(SaveOptions.DONOTSAVECHANGES);
                    app.activeDocument = bg;
                    centerLayer(lay, TW / 2, TH / 2);
                }
                saveJpg(bg, pad(idx++));
                bg.close(SaveOptions.DONOTSAVECHANGES);

                // 2) Panorama nahtlos auf n Kacheln
                var pano = openFile(P.full_file);
                resizeTo(pano, TW * n, TH);
                for (var i = 0; i < n; i++) {
                    var tile = pano.duplicate('kachel', true);
                    app.activeDocument = tile;
                    tile.crop([i * TW, 0, (i + 1) * TW, TH]);
                    saveJpg(tile, pad(idx++));
                    tile.close(SaveOptions.DONOTSAVECHANGES);
                }
                pano.close(SaveOptions.DONOTSAVECHANGES);

                // 3) Infokachel: Aufnahmedaten, Kamera, Objektiv, Copyright, Instagram
                var e = background(P.darken);
                var addIcon = function (name, cx, cy, size) {
                    var f = new File(P.icon_dir + '/' + name + '.png');
                    if (!f.exists) return;
                    var d = app.open(f);
                    if (d.mode !== DocumentMode.RGB) d.changeMode(ChangeMode.RGB);
                    resizeTo(d, size, size);
                    var l = moveLayerTo(d.activeLayer, e);
                    d.close(SaveOptions.DONOTSAVECHANGES);
                    app.activeDocument = e;
                    centerLayer(l, cx, cy);
                };
                var addText = function (str, x, cy, size, font) {
                    app.activeDocument = e;
                    var l = e.artLayers.add();
                    l.kind = LayerKind.TEXT;
                    var ti = l.textItem;
                    ti.contents = str;
                    ti.font = pickFont(font);
                    ti.size = size;
                    ti.color = white;
                    ti.justification = Justification.LEFT;
                    ti.position = [x, cy + size * 0.36];
                };
                var big = [['blende', P.t_fnum], ['zeit', P.t_exposure], ['iso', P.t_iso], ['brennweite', P.t_focal]];
                var row = 0;
                for (var b = 0; b < big.length; b++) {
                    if (!big[b][1]) continue;
                    var cy = (455 + row * 160) * sc;
                    addIcon(big[b][0], 218 * sc, cy, 108 * sc);
                    addText(big[b][1], 330 * sc, cy, 122 * sc, P.font);
                    row++;
                }
                // Trennlinie: Linie mit Doppelstrich (Grafik), sonst schlichte Linie
                var loopFile = new File(P.icon_dir + '/trennlinie.png');
                if (P.divider !== 'linie' && loopFile.exists) {
                    var ld = app.open(loopFile);
                    if (ld.mode !== DocumentMode.RGB) ld.changeMode(ChangeMode.RGB);
                    resizeTo(ld, ld.width.as('px') * sc, ld.height.as('px') * sc);
                    var ll = moveLayerTo(ld.activeLayer, e);
                    ld.close(SaveOptions.DONOTSAVECHANGES);
                    app.activeDocument = e;
                    var lb = ll.bounds;   // linke Kante = Linienanfang, Oberkante = Leitwerkspitze
                    ll.translate(162 * sc - lb[0].as('px'), (1105 - 26) * sc - lb[1].as('px'));
                } else {
                    var dl = e.artLayers.add();
                    e.selection.select([[162 * sc, 1149 * sc], [1458 * sc, 1149 * sc], [1458 * sc, 1152 * sc], [162 * sc, 1152 * sc]]);
                    e.selection.fill(white); e.selection.deselect();
                    dl.opacity = 45;
                }
                var small = [['kamera', P.t_camera], ['objektiv', P.t_lens], ['copyright', P.t_copyright], ['handle', P.t_handle]];
                row = 0;
                for (var k = 0; k < small.length; k++) {
                    if (!small[k][1]) continue;
                    var cy2 = (1248 + row * 106) * sc;
                    addIcon(small[k][0], 218 * sc, cy2, 72 * sc);
                    addText(small[k][1], 330 * sc, cy2, 70 * sc, P.font);
                    row++;
                }
                saveJpg(e, pad(idx++));
                e.close(SaveOptions.DONOTSAVECHANGES);
                return toJSON({ ok: true, count: idx - 1 });
            } finally {
                app.preferences.typeUnits = oldType;
            }
        }

        if (app.documents.length === 0) return toJSON({ ok: false, error: 'No document open in Photoshop.' });
        var doc = app.activeDocument;

        if (P.phase === 'info') {
            var ex = exifInfo(doc);
            return toJSON({ ok: true, path: doc.fullName.fsName,
                            width: Math.round(doc.width.as('px')), height: Math.round(doc.height.as('px')),
                            date: captureDate(doc), ex_fnum: ex.fnum, ex_exposure: ex.exposure, ex_iso: ex.iso,
                            ex_focal: ex.focal, ex_camera: ex.camera, ex_lens: ex.lens });
        }

        if (P.phase === 'export') {
            var full = doc.duplicate('fa_full', true);
            prepare(full);

            // 1) nur der Front-Slice
            var front = full.duplicate('fa_front', true);
            app.activeDocument = front;
            front.crop([P.slice_left, 0, P.slice_right, P.height]);
            saveWeb(front, P.front_file, P.quality);
            front.close(SaveOptions.DONOTSAVECHANGES);

            // 2) Gesamtbild (ohne Slices)
            app.activeDocument = full;
            saveWeb(full, P.full_file, P.quality);
            full.close(SaveOptions.DONOTSAVECHANGES);

            // 3) Lightroom-Dokument ohne Speichern schließen
            app.activeDocument = doc;
            doc.close(SaveOptions.DONOTSAVECHANGES);
            return toJSON({ ok: true });
        }
        return toJSON({ ok: false, error: 'Unknown phase' });
    } catch (e) {
        return toJSON({ ok: false, error: e.message + ' (line ' + e.line + ')' });
    } finally {
        app.preferences.rulerUnits = oldUnits;
        app.displayDialogs = oldDialogs;
    }
})();

// Ergebnis zusätzlich als Datei ablegen – Photoshop liefert den Rückgabewert nicht immer zuverlässig
try {
    if (typeof P !== 'undefined' && P.result_file) {
        var __f = new File(P.result_file);
        __f.encoding = 'UTF8';
        __f.open('w');
        __f.write(__FA_RESULT);
        __f.close();
    }
} catch (e) {}
__FA_RESULT;
