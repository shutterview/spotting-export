#!/bin/bash
# Spotting Export – installer
# Idea & workflow: @shutterview.aviation · built with Claude
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Library/Application Support/SpottingExport"
LRMOD="$HOME/Library/Application Support/Adobe/Lightroom/Modules"

echo "Installing Spotting Export …"
mkdir -p "$APP" "$LRMOD"
cp "$DIR/spotting_export.py" "$DIR/ps_slice_export.jsx" "$DIR/dialog.js" "$DIR/lr_menu.js" "$APP/"
chmod +x "$APP/spotting_export.py"
rm -rf "$APP/carousel_icons"; cp -R "$DIR/carousel_icons" "$APP/"

if [ -f "$APP/config.json" ]; then
  echo "config.json already exists – your settings are kept, new settings are added."
  /usr/bin/python3 - "$DIR/config.json" "$APP/config.json" <<'PYEOF'
import json, sys
new, old = json.load(open(sys.argv[1], encoding="utf-8")), json.load(open(sys.argv[2], encoding="utf-8"))
added = [k for k in new if k not in old]
for k in added: old[k] = new[k]
json.dump(old, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
if added: print("  added:", ", ".join(added))
PYEOF
else
  cp "$DIR/config.json" "$APP/"
fi

# Ask for the export folder
CUR=$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("export_root",""))' "$APP/config.json")
CHOOSE=1
if [ -n "$CUR" ]; then
  echo "Current export folder: $CUR"
  read -p "Change export folder? [y/N] " CH; [[ "$CH" =~ ^[Yy]$ ]] || CHOOSE=0
fi
if [ $CHOOSE = 1 ]; then
  echo "Choose the folder for your aircraft folders in the window that opens …"
  P=$(osascript -e 'POSIX path of (choose folder with prompt "Where should your aircraft folders be saved?")' 2>/dev/null || true)
  if [ -n "$P" ]; then
    /usr/bin/python3 -c 'import json,sys; p=sys.argv[1]; c=json.load(open(p, encoding="utf-8")); c["export_root"]=sys.argv[2].rstrip("/"); json.dump(c, open(p,"w",encoding="utf-8"), ensure_ascii=False, indent=2)' "$APP/config.json" "$P"
    echo "Export folder: $P"
  else
    echo "No folder chosen – you will be asked on the first run."
  fi
fi

# Details for the carousel info tile (asked once)
NEED=$(/usr/bin/python3 -c 'import json,sys; c=json.load(open(sys.argv[1], encoding="utf-8")); print(("c" if not c.get("copyright") else "") + ("i" if not c.get("instagram") else ""))' "$APP/config.json")
CR=""; IG=""
if [[ "$NEED" == *c* ]]; then read -p "Name for the © on the info tile (e.g. your name): " CR; fi
if [[ "$NEED" == *i* ]]; then read -p "Instagram handle for the info tile (e.g. shutterview.aviation): " IG; fi
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

# Launcher for the Photoshop keyboard shortcut
if [ ! -f "$APP/shortcut_name.txt" ]; then
  read -p "What is your shortcut called in the Shortcuts app? [Spotting Export]: " SC
  printf "%s" "${SC:-Spotting Export}" > "$APP/shortcut_name.txt"
fi
rm -rf "$APP/Spotting Export Launcher.app"
osacompile -o "$APP/Spotting Export Launcher.app" "$DIR/starter.applescript"

PSOK=0
for PS in /Applications/Adobe\ Photoshop*/Presets/Scripts; do
  [ -d "$PS" ] || continue
  if cp "$DIR/Spotting-Export.jsx" "$PS/" 2>/dev/null || { echo "Copying the Photoshop menu item to: $PS – please enter your Mac password (nothing is shown while typing):"; sudo cp "$DIR/Spotting-Export.jsx" "$PS/"; }; then
    echo "Photoshop menu item installed: $PS/Spotting-Export.jsx"; PSOK=1
  else
    echo "Could not copy. Manually in Terminal:  sudo cp Spotting-Export.jsx \"$PS/\""
  fi
done
[ $PSOK = 1 ] || echo "Note: Photoshop was not found in /Applications."

echo
echo "Installed to:      $APP"
echo "Lightroom plugin:  $LRMOD/SpottingExport.lrplugin   (restart Lightroom!)"
echo "Restart Photoshop, then: File → Scripts → Spotting-Export"
echo "IMPORTANT: quit Lightroom completely with ⌘Q and start it again – then “Spotting Export ready” appears."
