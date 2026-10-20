#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Spotting Export (läuft komplett lokal, keine Internetverbindung)
---------------------------------------------------------------------------------
Per Hotkey starten, sobald das Bild aus Lightroom in Photoshop offen ist:
 1. Format aus dem Bild lesen (8x5 -> 2, 12x5 -> 3, 16x5 -> 4, 20x5 -> 5 Slices)
 2. Eingabefenster: Kennzeichen, Airline, Typfamilie, Flughafen, Runway, Richtung, Format, Zusatz
 3. Ordner  <Speicherort>/<Typfamilie>/<Kennzeichen>-<Airline>-<Flughafen>-<Runway>-<Zusatz>
 4. Photoshop: Front-Slice + Panorama "Für Web speichern", ohne Speichern schließen
 5. Lightroom: Plugin exportiert das Original in denselben Ordner (mit deiner Exportvorgabe)

Idee & Workflow: @shutterview.aviation · gebaut mit Claude
"""
import json
import math
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

APP_DIR = Path.home() / "Library/Application Support/SpottingExport"
CONFIG_PATH = APP_DIR / "config.json"
JSX_PATH = APP_DIR / "ps_slice_export.jsx"
DIALOG_JS = APP_DIR / "dialog.js"
PARAMS_PATH = APP_DIR / "ps_run.jsx"
LR_JOB = APP_DIR / "lr_job.txt"
LR_DONE = APP_DIR / "lr_done.txt"
LR_ALIVE = APP_DIR / "lr_alive.txt"
LR_LOG = APP_DIR / "lightroom.log"
LR_MENU_JS = APP_DIR / "lr_menu.js"
MSG_MANUAL = "Bitte Lightroom einmal komplett neu starten (⌘Q). Notweg: Bibliothek → Zusatzmoduloptionen → Spotting Export jetzt ausführen"
LR_MENU_TITLE = "Spotting Export jetzt ausführen"
HISTORY = APP_DIR / "verlauf.json"
LOG = APP_DIR / "spotting_export.log"

FORMATS = {"8x5": 2, "12x5": 3, "16x5": 4, "20x5": 5}
FIELDS = ["kennzeichen", "airline", "familie", "flughafen", "runway", "richtung", "format", "freitext"]
LABELS = {"kennzeichen": "Kennzeichen", "airline": "Airline", "familie": "Typfamilie",
          "flughafen": "Flughafen", "runway": "Runway"}

os.environ["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + os.environ.get("PATH", "")


# ---------------------------------------------------------------- Hilfsfunktionen
def log(msg):
    line = time.strftime("%Y-%m-%d %H:%M:%S ") + msg
    try:
        APP_DIR.mkdir(parents=True, exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


class UserCancelled(Exception):
    pass


def as_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def osa(script, timeout=600):
    r = subprocess.run(["/usr/bin/osascript", "-"], input=script, capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        if "-128" in r.stderr:
            raise UserCancelled()
        raise RuntimeError(r.stderr.strip())
    return r.stdout.strip()


def notify(msg):
    try:
        osa(f'display notification {as_str(msg)} with title "Spotting Export"')
    except Exception:
        pass


def alert(msg, critical=False):
    try:
        osa(f'display alert "Spotting Export" message {as_str(msg)}' + (" as critical" if critical else " as warning"))
    except Exception:
        pass


def fail(msg):
    log("FEHLER: " + msg)
    alert(msg, critical=True)
    sys.exit(1)


def load_config():
    if not CONFIG_PATH.exists():
        fail(f"config.json fehlt in {APP_DIR}. Bitte install.sh ausführen.")
    cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    cfg["export_root"] = os.path.expanduser(cfg.get("export_root") or "")
    return cfg


def save_config_value(key, value):
    raw = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    raw[key] = value
    CONFIG_PATH.write_text(json.dumps(raw, ensure_ascii=False, indent=2), encoding="utf-8")


def choose_export_root(cfg):
    default = cfg["export_root"] if cfg["export_root"] and os.path.isdir(cfg["export_root"]) else str(Path.home() / "Pictures")
    path = osa(f'''set f to choose folder with prompt "Wohin sollen die Flugzeug-Ordner gespeichert werden?" ¬
        default location (POSIX file {as_str(default)})
return POSIX path of f''', timeout=3600).rstrip("/")
    save_config_value("export_root", path)
    cfg["export_root"] = path
    log(f"Speicherort geändert: {path}")


def safe(s):
    s = re.sub(r"\s+", "_", str(s).strip())
    s = re.sub(r"[^\w\-]+", "", s)
    return s.strip("_-")


def capture_date_fallback(path):
    """Aufnahmedatum über Spotlight, falls Photoshop keins geliefert hat (Ortszeit, YYYYMMDD)."""
    import datetime
    try:
        out = subprocess.run(["/usr/bin/mdls", "-raw", "-name", "kMDItemContentCreationDate", path],
                             capture_output=True, text=True).stdout.strip()
        return datetime.datetime.strptime(out, "%Y-%m-%d %H:%M:%S %z").astimezone().strftime("%Y%m%d")
    except Exception:
        return ""


def name_prefix(cfg, src, ps_date):
    """z.B. 20260927 + _Y9A6479 -> 20260927_Y9A6479 (Datum vor den Originalnamen)."""
    stem = original_stem(src)
    if not cfg.get("datum_voranstellen", True):
        return stem
    date = ps_date or capture_date_fallback(src)
    if not date:
        log("Kein Aufnahmedatum gefunden – Dateiname ohne Datum")
        return stem
    return date + ("" if stem.startswith(("_", "-")) else "_") + stem


# ---------------------------------------------------------------- Aufnahmedaten für die Infokachel
def _num(v):
    try:
        v = str(v).strip()
        if "/" in v:
            a, b = v.split("/", 1)
            return float(a) / float(b)
        return float(v)
    except Exception:
        return None


def _mdls(path, key):
    try:
        out = subprocess.run(["/usr/bin/mdls", "-raw", "-name", key, path], capture_output=True, text=True).stdout.strip()
        return "" if out in ("", "(null)") else out.strip('"')
    except Exception:
        return ""


def exif_texts(info, src):
    """Formatiert Blende, Zeit, ISO, Brennweite, Kamera, Objektiv wie auf der bisherigen Infokachel."""
    fnum = _num(info.get("ex_fnum") or _mdls(src, "kMDItemFNumber"))
    exp = _num(info.get("ex_exposure") or _mdls(src, "kMDItemExposureTimeSeconds"))
    iso = str(info.get("ex_iso") or _mdls(src, "kMDItemISOSpeed")).split(".")[0]
    focal = _num(info.get("ex_focal") or _mdls(src, "kMDItemFocalLength"))
    t = {"t_fnum": f"\u0192 {fnum:.1f}" if fnum else "",
         "t_exposure": "", "t_iso": f"ISO {iso}" if iso and iso != "0" else "",
         "t_focal": f"{round(focal)}mm" if focal else "",
         "t_camera": (info.get("ex_camera") or _mdls(src, "kMDItemAcquisitionModel")).strip(),
         "t_lens": (info.get("ex_lens") or _mdls(src, "kMDItemLensModel")).strip()}
    if exp:
        t["t_exposure"] = f"1/{round(1 / exp)}s" if exp < 1 else f"{exp:g}s"
    return t


def original_stem(edited_path):
    return re.sub(r"-(Bearbeitet|Edit)(-\d+)?$", "", Path(edited_path).stem)


def unique_dir(path):
    p, i = Path(path), 2
    while p.exists():
        p = Path(f"{path}_{i}")
        i += 1
    return p


# ---------------------------------------------------------------- Typfamilien
FAMILY_PATTERNS = [
    (r"\bA\s?-?(220|3\d{2})", "A{}"),
    (r"\b(?:B|BOEING)?\s?-?(7[0-8]7)", "B{}"),
    (r"\b(?:EMB|ERJ|EMBRAER|E)\s?-?(1[4-9]\d)", "E{}"),
    (r"\bATR\s?-?(42|72)", "ATR{}"),
    (r"\bCRJ", "CRJ"),
    (r"\b(?:DASH\s?8|DHC\s?-?8|Q[234]00)", "DHC8"),
    (r"\bMD\s?-?(1[01]|8\d|90)", "MD{}"),
]


def family_of(cfg, text):
    u = str(text).upper().replace("AIRBUS", "A").strip()
    fam = ""
    for pat, fmt in FAMILY_PATTERNS:
        m = re.search(pat, u)
        if m:
            fam = fmt.format(*m.groups())
            break
    if not fam:
        fam = re.split(r"[-\s/]", u)[0] if u else ""
    mapping = {k.upper(): v for k, v in cfg.get("familien_zuordnung", {}).items()}
    return mapping.get(fam, fam)


def _norm(name):
    n = re.sub(r"\b(AIRBUS|BOEING|EMBRAER|BOMBARDIER)\b", "", name.upper())
    return re.sub(r"[^A-Z0-9]", "", n)


def family_folder(root, fam):
    key = _norm(fam) or "UNBEKANNT"
    keys = {key}
    if re.fullmatch(r"B7\d7", key):
        keys.add(key[1:])
    root = Path(root)
    root.mkdir(parents=True, exist_ok=True)
    for d in sorted(root.iterdir()):
        if d.is_dir() and not d.name.startswith(".") and _norm(d.name) in keys:
            return d
    new = root / (safe(fam) or "Unbekannt")
    new.mkdir()
    log(f"Neuer Familien-Ordner angelegt: {new}")
    return new


def existing_families(root):
    try:
        return sorted(d.name for d in Path(root).iterdir() if d.is_dir() and not d.name.startswith("."))
    except Exception:
        return []


# ---------------------------------------------------------------- Photoshop
def run_jsx(cfg, params):
    """Übergibt den Skripttext direkt an Photoshop (robuster als ein Dateiverweis).
    Parameter werden vorangestellt, alles ASCII-sicher kodiert."""
    result_file = APP_DIR / "ps_result.json"
    if result_file.exists():
        result_file.unlink()
    params = dict(params, result_file=str(result_file))
    code = "var P = " + json.dumps(params, ensure_ascii=True) + ";\n" + JSX_PATH.read_text(encoding="utf-8")
    code = code.encode("ascii", "backslashreplace").decode("ascii")
    PARAMS_PATH.write_text(code, encoding="ascii")
    script = f'''
set jsCode to read (POSIX file {as_str(str(PARAMS_PATH))})
tell application id {as_str(cfg["photoshop_bundle_id"])}
    activate
    with timeout of 900 seconds
        set res to do javascript jsCode
    end timeout
end tell
return res'''
    out = osa(script, timeout=960)
    if not out.strip() and result_file.exists():
        out = result_file.read_text(encoding="utf-8")
        log("Photoshop-Rückmeldung aus Datei gelesen")
    if not out.strip() and params.get("phase") == "export":
        # Keine Rückmeldung – Erfolg anhand der erzeugten Dateien prüfen
        made = [f for f in (params["front_file"], params["full_file"]) if Path(f).is_file() and Path(f).stat().st_size > 0]
        if len(made) == 2:
            log("Photoshop ohne Rückmeldung, beide Dateien vorhanden – fahre fort")
            return {"ok": True}
        raise RuntimeError("Photoshop hat nicht geantwortet und nicht alle Dateien erzeugt.")
    try:
        res = json.loads(out)
    except Exception:
        raise RuntimeError("Unerwartete Antwort von Photoshop: " + (out[:300] or "(leer)"))
    if not res.get("ok"):
        raise RuntimeError("Photoshop: " + res.get("error", "unbekannter Fehler"))
    return res


def detect_format(w, h, tol):
    r = w / h
    label = min(FORMATS, key=lambda k: abs(int(k.split("x")[0]) / 5 - r))
    ok = abs(int(label.split("x")[0]) / 5 - r) / (int(label.split("x")[0]) / 5) <= tol
    return label, ok, r


# ---------------------------------------------------------------- Verlauf (Kennzeichen-Gedächtnis)
def load_history():
    try:
        h = json.loads(HISTORY.read_text(encoding="utf-8"))
    except Exception:
        h = {}
    h.setdefault("kennzeichen", {})
    h.setdefault("airlines", [])
    h.setdefault("flughaefen", [])
    h.setdefault("familien", [])
    return h


def remember(h, v):
    h["kennzeichen"][v["kennzeichen"]] = {"airline": v["airline"], "familie": v["familie"]}
    for key, val in (("airlines", v["airline"]), ("flughaefen", v["flughafen"]), ("familien", v["familie"])):
        if val and val not in h[key]:
            h[key].append(val)
        h[key].sort(key=str.lower)
    h["letzte"] = {"flughafen": v["flughafen"], "richtung": v["richtung"]}
    HISTORY.write_text(json.dumps(h, ensure_ascii=False, indent=2), encoding="utf-8")


# ---------------------------------------------------------------- Eingabefenster
def form_native(payload):
    r = subprocess.run(["/usr/bin/osascript", "-l", "JavaScript", str(DIALOG_JS), json.dumps(payload, ensure_ascii=False)],
                       capture_output=True, text=True, timeout=3600)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip())
    return json.loads(r.stdout.strip())


def form_simple(payload):
    """Ausweich-Dialog, falls das native Fenster nicht startet."""
    v = payload["values"]
    s = " | ".join(v.get(k, "") for k in FIELDS)
    script = f'''set r to display dialog {as_str(payload["info"])} & return & return & "Kennzeichen | Airline | Typfamilie | Flughafen | Runway | Richtung | Format | Zusatz" ¬
        default answer {as_str(s)} buttons {{"Speicherort ändern …", "Abbrechen", "OK"}} default button "OK" cancel button "Abbrechen" ¬
        with title "Spotting Export"
return (button returned of r) & linefeed & (text returned of r)'''
    try:
        button, _, text = osa(script, timeout=3600).partition("\n")
    except UserCancelled:
        return {"button": "abbrechen", "values": v}
    parts = [p.strip() for p in text.split("|")]
    parts += [""] * (len(FIELDS) - len(parts))
    return {"button": "speicherort" if button.startswith("Speicherort") else "ok",
            "values": dict(zip(FIELDS, parts[:len(FIELDS)]))}


def ask(cfg, values, info, lists, placeholder):
    payload = dict(values=values, info=info, placeholder=placeholder, **lists)
    try:
        return form_native(payload)
    except Exception as e:
        log(f"Natives Eingabefenster nicht verfügbar ({e}) – nutze einfachen Dialog")
        return form_simple(payload)


# ---------------------------------------------------------------- Ablauf
def main():
    cfg = load_config()
    log("---- Start")
    if not cfg["export_root"]:
        choose_export_root(cfg)

    info = run_jsx(cfg, {"phase": "info"})
    src, W, H = info["path"], int(info["width"]), int(info["height"])
    log(f"Dokument: {src} ({W}x{H})")
    fmt, fmt_ok, ratio = detect_format(W, H, cfg.get("format_toleranz", 0.04))

    hist = load_history()
    last = hist.get("letzte", {})
    values = {k: "" for k in FIELDS}
    values.update(richtung=last.get("richtung", "rechts"), format=fmt,
                  flughafen=last.get("flughafen", ""))
    placeholder = {"airline": "leer = aus Verlauf (bekanntes Kennzeichen)",
                   "familie": "z. B. A350 – Untertypen werden gekürzt",
                   "freitext": "optional, z. B. Sunset"}

    while True:
        hinweis = [f"Speicherort: {cfg['export_root']}/<Typfamilie>/",
                   f"Format erkannt: {fmt}" if fmt_ok else f"Format nicht eindeutig ({ratio:.2f}:1) – bitte prüfen"]
        lists = {"airlines": hist["airlines"], "flughaefen": sorted(set(hist["flughaefen"])),
                 "familien": sorted(set(existing_families(cfg["export_root"])) | set(hist["familien"]))}
        res = ask(cfg, values, "\n".join(hinweis), lists, placeholder)
        values = {k: str(res["values"].get(k, "")).strip() for k in FIELDS}
        if res["button"] == "abbrechen":
            raise UserCancelled()
        if res["button"] == "speicherort":
            try:
                choose_export_root(cfg)
            except UserCancelled:
                pass
            continue

        values["kennzeichen"] = values["kennzeichen"].upper()
        values["richtung"] = "links" if values["richtung"].lower().startswith("l") else "rechts"
        values["format"] = values["format"] if values["format"] in FORMATS else fmt
        known = hist["kennzeichen"].get(values["kennzeichen"], {})
        values["airline"] = values["airline"] or known.get("airline", "")
        values["familie"] = family_of(cfg, values["familie"] or known.get("familie", ""))
        values["flughafen"] = values["flughafen"].upper()
        values["runway"] = values["runway"].upper().replace("RWY", "").strip()
        missing = [LABELS[k] for k in LABELS if not values[k]]
        if missing:
            alert("Bitte noch ausfüllen: " + ", ".join(missing))
            continue
        break

    remember(hist, values)
    log("Eingabe: " + json.dumps(values, ensure_ascii=False))

    n = FORMATS[values["format"]]
    reg = safe(values["kennzeichen"])
    parts = [reg, safe(values["airline"]), safe(values["flughafen"]), safe(values["runway"])]
    if safe(values["freitext"]):
        parts.append(safe(values["freitext"]))
    fam_dir = family_folder(cfg["export_root"], values["familie"])
    folder = unique_dir(fam_dir / "-".join(parts))
    folder.mkdir(parents=True)
    prefix = name_prefix(cfg, src, str(info.get("date") or ""))
    stem = f"{prefix}_{reg}"

    edges = [round(i * W / n) for i in range(n + 1)]
    right = values["richtung"] == "rechts"
    if cfg.get("front_slice", "flugrichtung") != "flugrichtung":
        right = not right
    idx = n - 1 if right else 0

    notify(f"Exportiere {n} Slices – Front: {'rechts' if right else 'links'}")
    run_jsx(cfg, {"phase": "export", "slice_left": edges[idx], "slice_right": edges[idx + 1], "height": H,
                  "quality": int(cfg.get("jpeg_quality", 100)),
                  "front_file": str(folder / f"{stem}-Front.jpg"),
                  "full_file": str(folder / f"{stem}-Panorama-{values['format']}.jpg")})
    log(f"Photoshop-Export fertig: {folder}")

    carousel = cfg.get("carousel_aktiv", True)
    if cfg.get("photoshop_beenden", True) and not carousel:
        try:
            try:
                run_jsx(cfg, {"phase": "closeall"})       # nichts speichern, keine Rückfrage
            except Exception:
                pass
            osa(f'tell application id {as_str(cfg["photoshop_bundle_id"])} to quit', timeout=120)
        except Exception as e:
            log(f"Photoshop konnte nicht beendet werden: {e}")

    # Dateistand VOR dem Lightroom-Auftrag merken, damit auch ein sehr schneller Export erkannt wird
    known = {p.name for p in folder.iterdir()}
    if LR_DONE.exists():
        LR_DONE.unlink()
    LR_JOB.write_text("\n".join([
        f"edited_path={src}",
        f"target_folder={folder}",
        f"preset_path={find_lr_preset(cfg.get('lightroom_exportvorgabe', ''))}",
        f"custom_pattern={cfg.get('lr_freitext_muster', '{kennzeichen}-{format}')}",
        f"suffix={safe(cfg.get('original_suffix', 'auto'))}",
        f"v_kennzeichen={reg}",
        f"v_airline={safe(values['airline'])}",
        f"v_flughafen={safe(values['flughafen'])}",
        f"v_runway={safe(values['runway'])}",
        f"v_familie={safe(values['familie'])}",
        f"v_freitext={safe(values['freitext'])}",
        f"pick={'1' if cfg.get('original_markieren', True) else '0'}",
        f"name_prefix={prefix}",
        f"v_format={values['format']}",
        f"quality={int(cfg.get('jpeg_quality', 100))}",
    ]) + "\n", encoding="utf-8")
    osa(f'tell application id {as_str(cfg["lightroom_bundle_id"])} to activate')

    # Plugin über seinen Menüpunkt starten (Datei → Zusatzmoduloptionen → … jetzt ausführen)
    # Warten, bis der Wächter des Plugins den Auftrag abholt (Auftragsdatei verschwindet)
    t_wait = time.time() + cfg.get("lr_menue_wartezeit_s", 8)
    while time.time() < t_wait and LR_JOB.exists():
        time.sleep(0.5)
    if LR_JOB.exists():
        # Notweg: Menüpunkt des Plugins anklicken – sprachunabhängig über den Anfang "Spotting Export"
        try:
            r = subprocess.run(["/usr/bin/osascript", "-l", "JavaScript", str(LR_MENU_JS),
                                cfg["lightroom_bundle_id"], "Spotting Export"], capture_output=True, text=True, timeout=60)
            res = (r.stdout or "").strip() or (r.stderr or "").strip()
            log("Lightroom menu: " + res)
            if res != "ok":
                notify(MSG_MANUAL)
        except Exception as e:
            log(f"Lightroom menu: {e}")
            notify(MSG_MANUAL)

    # Fertig ist es, wenn das Plugin Rückmeldung gibt ODER das exportierte Original im Ordner liegt

    def lr_file():
        for f in folder.iterdir():
            if f.name not in known and f.suffix.lower() in (".jpg", ".jpeg", ".tif", ".tiff", ".png") \
                    and not f.name.startswith("."):
                return f
        return None

    t0 = time.time()
    deadline = t0 + cfg.get("lightroom_timeout_s", 180)
    while time.time() < deadline and not LR_DONE.exists():
        f = lr_file()
        if f:
            time.sleep(2)                       # Lightroom zu Ende schreiben lassen
            LR_DONE.write_text(f"OK {f} (erkannt im Ordner)", encoding="utf-8")
            break
        time.sleep(1)
    if not LR_DONE.exists():
        tail = ""
        try:
            tail = "\n\nLetzte Plugin-Meldungen:\n" + "".join(LR_LOG.read_text(encoding="utf-8").splitlines(True)[-5:])
        except Exception:
            pass
        fail("Lightroom hat das Original nicht exportiert. Bitte in Lightroom nach einer Fehlermeldung schauen. "
             "Der Auftrag ist noch offen: Bibliothek → Zusatzmoduloptionen → 'Spotting Export jetzt ausführen'." + tail)
    msg = LR_DONE.read_text(encoding="utf-8").strip()
    if msg.startswith("FEHLER"):
        fail("Lightroom: " + msg)
    log("Lightroom: " + msg)

    # ---------------- Carousel-Kacheln in Photoshop bauen
    if carousel:
        orig = lr_file()
        notify("Baue Carousel …")
        try:
            out_dir = folder / cfg.get("carousel_ordner", "Carousel")
            res = run_jsx(cfg, dict(
                phase="carousel", slices=n, out_dir=str(out_dir),
                front_file=str(folder / f"{stem}-Front.jpg"),
                full_file=str(folder / f"{stem}-Panorama-{values['format']}.jpg"),
                original_file=str(orig) if orig else "",
                tile_w=int(cfg.get("carousel_breite", 1620)), tile_h=int(cfg.get("carousel_hoehe", 2025)),
                blur=float(cfg.get("carousel_unschaerfe", 60)), darken=int(cfg.get("carousel_abdunkeln", 10)),
                jpg_quality=12, icon_dir=str(APP_DIR / "carousel_icons"),
                font=cfg.get("carousel_schrift", "HelveticaNeue-Light"),
                divider=cfg.get("carousel_trennlinie", "flugzeug"),
                font_fallback=cfg.get("carousel_schrift_ersatz", "HelveticaNeue"),
                t_copyright=cfg.get("copyright", ""), t_handle=cfg.get("instagram", ""),
                **exif_texts(info, src)))
            log(f"Carousel fertig: {res.get('count')} Kacheln in {out_dir}")
        except Exception as e:
            log(f"Carousel fehlgeschlagen: {e}")
            alert(f"Die Bilder sind exportiert, aber das Carousel konnte nicht erstellt werden:\n{e}")
        if cfg.get("photoshop_beenden", True):
            try:
                try:
                    run_jsx(cfg, {"phase": "closeall"})       # nichts speichern, keine Rückfrage
                except Exception:
                    pass
                osa(f'tell application id {as_str(cfg["photoshop_bundle_id"])} to quit', timeout=120)
            except Exception as e:
                log(f"Photoshop konnte nicht beendet werden: {e}")

    notify(f"Fertig: {fam_dir.name}/{folder.name}")
    if cfg.get("ordner_oeffnen", False):
        subprocess.run(["/usr/bin/open", str(folder)])


def find_lr_preset(name):
    if not name:
        return ""
    full = Path(os.path.expanduser(name))
    if full.suffix == ".lrtemplate" and full.is_file():
        return str(full)
    base = Path.home() / "Library/Application Support/Adobe/Lightroom/Export Presets"
    hits = sorted(base.rglob(f"{name}.lrtemplate")) if base.exists() else []
    if not hits:
        fail(f"Lightroom-Exportvorgabe '{name}' nicht gefunden. Bitte den Namen in config.json prüfen "
             f"oder den vollständigen Pfad zur .lrtemplate-Datei eintragen.")
    return str(hits[0])


if __name__ == "__main__":
    try:
        main()
    except UserCancelled:
        log("Abgebrochen")
    except Exception as e:
        fail(str(e))
