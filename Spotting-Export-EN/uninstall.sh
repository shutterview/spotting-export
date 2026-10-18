#!/bin/bash
# Spotting Export – uninstaller. Quit Lightroom Classic and Photoshop before running.
APP="$HOME/Library/Application Support/SpottingExport"
PLUGIN="$HOME/Library/Application Support/Adobe/Lightroom/Modules/SpottingExport.lrplugin"
echo "This removes Spotting Export from this Mac (please quit Lightroom and Photoshop first)."
read -p "Keep a backup of your settings on the Desktop? [Y/n] " A
if [[ ! "$A" =~ ^[Nn]$ ]] && [ -d "$APP" ]; then
  mkdir -p "$HOME/Desktop/SpottingExport-settings-backup"
  cp "$APP"/config.json "$APP"/history.json "$APP"/shortcut_name.txt "$HOME/Desktop/SpottingExport-settings-backup/" 2>/dev/null || true
  echo "Settings backed up to ~/Desktop/SpottingExport-settings-backup"
fi
rm -rf "$APP" "$PLUGIN"
for F in /Applications/Adobe\ Photoshop*/Presets/Scripts/Spotting-Export.jsx; do
  [ -f "$F" ] && { echo "Removing Photoshop menu item (asks for your Mac password):"; sudo rm -f "$F"; }
done
echo
echo "Done. Two manual steps left:"
echo "  1. Shortcuts app: delete the shortcut “Spotting Export” (right-click → Delete)."
echo "  2. Restart Lightroom and Photoshop."
