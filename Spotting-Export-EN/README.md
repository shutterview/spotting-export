# Spotting Export

From Lightroom Classic to a ready-to-post Instagram carousel – with one shortcut.
Runs 100 % locally on your Mac: no AI, no internet connection, no subscription.

🇩🇪 German version: separate package (Spotting-Export-DE)

*Idea & workflow: [@shutterview.aviation](https://www.instagram.com/shutterview.aviation/) · built with Claude*

## What it does
1. In Lightroom Classic: right-click → **Edit In → Adobe Photoshop**.
2. In Photoshop: press your **shortcut** (e.g. ⌃⌘E).
3. An input window opens. The format (8x5, 12x5, 16x5, 20x5) is already detected from the image.
   Enter registration, airline, aircraft type, airport, runway, direction and an optional extra.
4. The script finds (or creates) the aircraft type folder and creates
   `<registration>-<airline>-<airport>-<runway>-<extra>`, e.g. `B747/D-ABYN-Lufthansa-FRA-25L-ShortFinal`.
5. Photoshop saves the front slice (in flight direction) and the panorama via “Save for Web”.
6. Lightroom flags the original and exports it into the same folder.
7. Photoshop builds the complete carousel in the subfolder `Carousel` (01.jpg …):
   blurred title tile with the 16:9 original, the panorama split seamlessly across the tiles
   (8x5 → 2, 12x5 → 3, 16x5 → 4, 20x5 → 5) and an info tile with your EXIF data.

## Requirements
- Mac with macOS, Adobe Lightroom Classic and Adobe Photoshop (tested with Photoshop 2026)
- Python 3 (macOS offers to install it automatically – see step 1)
- About 20 minutes for the one-time setup. No coding skills needed.

## Setup
The complete step-by-step guide is in **Spotting-Export-Setup-Guide.pdf**. Short version:
1. Terminal: `python3 --version` – if macOS offers the developer tools, install them.
2. Shortcuts app → Settings → Advanced → enable **Allow Running Scripts**. Create a shortcut
   named **Spotting Export** with the action **Run Shell Script** and paste:
   ```
   /usr/bin/python3 ~/Library/Application\ Support/SpottingExport/spotting_export.py
   ```
3. Terminal, in the unzipped folder: `bash install.sh` – it asks for your export folder, name, Instagram handle and
   shortcut name and copies the Photoshop menu item to `/Applications/Adobe Photoshop 2026/Presets/Scripts/`
   (asks for your Mac password).
4. Only if that failed, copy it manually: `sudo cp Spotting-Export.jsx "/Applications/Adobe Photoshop 2026/Presets/Scripts/"`
5. Restart Photoshop → **Edit → Keyboard Shortcuts → Application Menus → File → Scripts → Spotting-Export**
   and assign a shortcut (e.g. ⌃⌘E).
6. Restart Lightroom (⌘Q). After a few seconds “Spotting Export ready” appears.
7. First run: edit a panorama → Edit In → Photoshop → press your shortcut.

## Settings (`~/Library/Application Support/SpottingExport/config.json`)
| Setting | Meaning |
|---|---|
| `export_root` | Main export folder (empty = you are asked on first run) |
| `lightroom_export_preset` | Name of your Lightroom export preset (empty = built-in settings) |
| `lr_custom_text_pattern` | Text for “Custom Text” in your preset: `{registration}`, `{airline}`, `{airport}`, `{runway}`, `{type}`, `{extra}`, `{format}` |
| `original_suffix` | `auto` = aspect ratio of the Lightroom crop (e.g. 16x9) |
| `prefix_capture_date` | `true` = capture date (YYYYMMDD) in front of the file name |
| `quit_photoshop` | `true` = quit Photoshop at the end |
| `front_slice` | `flight_direction` or `against_flight_direction` |
| `flag_original` | `true` = flag the original as Pick in Lightroom |
| `type_mapping` | Group types, e.g. `{"A319": "A320"}` |
| `carousel_enabled` | `true` = build the carousel tiles |
| `carousel_width` / `carousel_height` | Tile size, default 1620 × 2025 |
| `carousel_blur` / `carousel_darken` | Background blur / darkening of the info tile |
| `carousel_divider` | `graphic` = divider with double bar, `line` = simple line |
| `carousel_font` | Font of the info tile (PostScript name), e.g. `HelveticaNeue-Light`, `AvenirNext-Regular` |
| `copyright` / `instagram` | Shown on the info tile |
| `spots` | Your spotting locations: with GPS data, airport and runway are filled in automatically |

Tip: copy a folder path in Finder with ⌥⌘C and remove all backslashes (`\`) before pasting it into config.json.

## Troubleshooting
- **Photoshop error 8800** → an old version is installed: delete old folders, unzip again, run `bash install.sh`.
- **Stops after switching to Lightroom** → did “Spotting Export ready” appear? Check File → Plug-in Manager,
  restart Lightroom. Fallback: Library → Plug-in Extras → Spotting Export – run now.
- **“Invalid \escape”** → remove backslashes from the path in config.json.
- **Shortcut does nothing** → assign it in Photoshop (step 5), not in the Shortcuts app.
- Log file: `~/Library/Application Support/SpottingExport/spotting_export.log`

## Uninstall
Quit Lightroom and Photoshop, then in Terminal inside the unzipped folder: `bash uninstall.sh`.
Afterwards delete the shortcut in the Shortcuts app and restart both apps.

## License / note
Free for personal, non-commercial use (CC BY-NC 4.0, see LICENSE.txt), shared as-is without warranty. Adobe Lightroom Classic and Photoshop are not included.

## Switching versions
Before installing another version (e.g. German), always run `bash uninstall.sh` first and restart Lightroom with ⌘Q.
