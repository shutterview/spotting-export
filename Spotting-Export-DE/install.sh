#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Library/Application Support/SpottingExport"
LRMOD="$HOME/Library/Application Support/Adobe/Lightroom/Modules"

mkdir -p "$APP" "$LRMOD"
cp "$DIR/spotting_export.py" "$DIR/ps_slice_export.jsx" "$DIR/dialog.js" "$APP/"
[ -f "$DIR/lr_menu.js" ] && cp "$DIR/lr_menu.js" "$APP/"
chmod +x "$APP/spotting_export.py"
rm -rf "$APP/carousel_icons"; cp -R "$DIR/carousel_icons" "$APP/"
if [ -f "$APP/config.json" ]; then
  echo "config.json existiert bereits – deine Einstellungen bleiben, neue Einträge werden ergänzt."
  /usr/bin/python3 - "$DIR/config.json" "$APP/config.json" <<'PYEOF'
import json, sys
neu, alt = json.load(open(sys.argv[1], encoding="utf-8")), json.load(open(sys.argv[2], encoding="utf-8"))
added = [k for k in neu if k not in alt]
for k in added: alt[k] = neu[k]
json.dump(alt, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
if added: print("  ergänzt:", ", ".join(added))
PYEOF
else
  cp "$DIR/config.json" "$APP/"
fi

# Speicherort abfragen
CUR=$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("export_root",""))' "$APP/config.json")
CHOOSE=1
if [ -n "$CUR" ]; then
  echo "Aktueller Speicherort: $CUR"
  read -p "Speicherort ändern? [j/N] " CH; [[ "$CH" =~ ^[Jj]$ ]] || CHOOSE=0
fi
if [ $CHOOSE = 1 ]; then
  echo "Wähle jetzt im Fenster den Ordner, in dem deine Flugzeug-Ordner gespeichert werden sollen …"
  P=$(osascript -e 'POSIX path of (choose folder with prompt "Wo sollen deine Flugzeug-Ordner gespeichert werden?")' 2>/dev/null || true)
  if [ -n "$P" ]; then
    /usr/bin/python3 -c 'import json,sys; p=sys.argv[1]; c=json.load(open(p, encoding="utf-8")); c["export_root"]=sys.argv[2].rstrip("/"); json.dump(c, open(p,"w",encoding="utf-8"), ensure_ascii=False, indent=2)' "$APP/config.json" "$P"
    echo "Speicherort: $P"
  else
    echo "Kein Ordner gewählt – du wirst beim ersten Start danach gefragt."
  fi
fi

# Angaben für die Infokachel des Carousels (einmalig)
NEED=$(/usr/bin/python3 -c 'import json,sys; c=json.load(open(sys.argv[1], encoding="utf-8")); print(("c" if not c.get("copyright") else "") + ("i" if not c.get("instagram") else ""))' "$APP/config.json")
CR=""; IG=""
if [[ "$NEED" == *c* ]]; then read -p "Name für das © auf der Infokachel (z. B. dein Name): " CR; fi
if [[ "$NEED" == *i* ]]; then read -p "Instagram-Name für die Infokachel (z. B. shutterview.aviation): " IG; fi
/usr/bin/python3 -c '
import json, sys
p, cr, ig = sys.argv[1], sys.argv[2].strip(), sys.argv[3].strip().lstrip("@")
c = json.load(open(p, encoding="utf-8"))
if cr: c["copyright"] = cr
if ig: c["instagram"] = ig
json.dump(c, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
' "$APP/config.json" "$CR" "$IG"
rm -rf "$LRMOD/SpottingExport.lrplugin"
cp -R "$DIR/SpottingExport.lrplugin" "$LRMOD/"

# --- Starter für das Photoshop-Tastenkürzel
if [ ! -f "$APP/kurzbefehl_name.txt" ]; then
  read -p "Wie heißt dein Kurzbefehl in der Kurzbefehle-App? [Spotting Export]: " KB
  printf "%s" "${KB:-Spotting Export}" > "$APP/kurzbefehl_name.txt"
fi
rm -rf "$APP/Spotting Export Starter.app"
osacompile -o "$APP/Spotting Export Starter.app" "$DIR/starter.applescript"

PSOK=0
for PS in /Applications/Adobe\ Photoshop*/Presets/Scripts; do
  [ -d "$PS" ] || continue
  if cp "$DIR/Spotting-Export.jsx" "$PS/" 2>/dev/null || { echo "Photoshop-Menüpunkt wird kopiert nach: $PS – bitte Mac-Passwort eingeben (beim Tippen erscheint nichts):"; sudo cp "$DIR/Spotting-Export.jsx" "$PS/"; }; then
    echo "Photoshop-Menüpunkt installiert: $PS/Spotting-Export.jsx"; PSOK=1
  else
    echo "Konnte nicht kopieren. Von Hand im Terminal:  sudo cp Spotting-Export.jsx \"$PS/\""
  fi
done
[ $PSOK = 1 ] || echo "Hinweis: Photoshop wurde in /Applications (Programme) nicht gefunden."

echo
echo "Installiert nach: $APP"
echo "Lightroom-Plugin: $LRMOD/SpottingExport.lrplugin  (Lightroom neu starten!)"
echo "Photoshop neu starten, dann: Datei → Skripten → Spotting-Export"
echo "WICHTIG: Lightroom jetzt mit ⌘Q komplett beenden und neu starten – dann erscheint „Spotting Export bereit“."
