#!/bin/bash
# Spotting Export – Deinstallation. Vorher Lightroom Classic und Photoshop beenden.
APP="$HOME/Library/Application Support/SpottingExport"
PLUGIN="$HOME/Library/Application Support/Adobe/Lightroom/Modules/SpottingExport.lrplugin"
echo "Entfernt Spotting Export von diesem Mac (bitte vorher Lightroom und Photoshop beenden)."
read -p "Sicherung deiner Einstellungen auf dem Schreibtisch ablegen? [J/n] " A
if [[ ! "$A" =~ ^[Nn]$ ]] && [ -d "$APP" ]; then
  mkdir -p "$HOME/Desktop/SpottingExport-Einstellungen"
  cp "$APP"/config.json "$APP"/verlauf.json "$APP"/kurzbefehl_name.txt "$HOME/Desktop/SpottingExport-Einstellungen/" 2>/dev/null || true
  echo "Einstellungen gesichert in ~/Desktop/SpottingExport-Einstellungen"
fi
rm -rf "$APP" "$PLUGIN"
for F in /Applications/Adobe\ Photoshop*/Presets/Scripts/Spotting-Export.jsx; do
  [ -f "$F" ] && { echo "Entferne Photoshop-Menüpunkt (fragt nach dem Mac-Passwort):"; sudo rm -f "$F"; }
done
echo
echo "Fertig. Noch zwei Schritte von Hand:"
echo "  1. Nur bei älteren Versionen: Kurzbefehl „Spotting Export“ in der App Kurzbefehle löschen."
echo "  2. Lightroom und Photoshop neu starten."
