# Spotting Export

*Idee & Workflow: [@shutterview.aviation](https://www.instagram.com/shutterview.aviation/) · gebaut mit Claude* · 🇬🇧 English version: separate package

Läuft komplett lokal auf deinem Mac: keine KI, keine Internetverbindung, keine laufenden Kosten.
Du gibst die Flugzeugdaten selbst ein, den Rest erledigt der Assistent.

## Ablauf
1. In Lightroom: Rechtsklick → **Bearbeiten in → Adobe Photoshop**.
2. In Photoshop: **Hotkey drücken**.
3. Das Eingabefenster öffnet sich. Das Format (8x5, 12x5, 16x5, 20x5) ist bereits aus dem Bild gelesen
   und vorausgewählt, du kannst es aber ändern. Du füllst aus:
   Kennzeichen, Airline, Typfamilie, Flughafen, Runway, Flugrichtung und optional einen Zusatz.
   Mit Tab springst du zum nächsten Feld, Enter = OK, Esc = Abbrechen.
4. Der Assistent sucht im Speicherort den Ordner der Typfamilie (oder legt ihn an) und erstellt darin
   `Kennzeichen-Airline-Flughafen-Runway-Zusatz`, z. B. `A350/D-AIXP-Lufthansa-FRA-25C-Sunset`.
5. Photoshop speichert per „Für Web speichern“ (Originalgröße, Qualität 100):
   `IMG_1234_D-AIXP-Front.jpg` (Slice in Flugrichtung) und `IMG_1234_D-AIXP-Panorama-16x5.jpg`,
   dann schließt Photoshop ohne zu speichern.
6. Lightroom markiert das Original und exportiert es in denselben Ordner, z. B.
   `IMG_1234_D-AIXP-16x9.jpg` – oder mit deiner eigenen Exportvorgabe (siehe unten).

## Carousel für Instagram
Am Ende baut Photoshop zusätzlich die fertigen 4:5-Kacheln (1620×2025) in den Unterordner `Carousel`:
- `01.jpg` – verschwommener Front-Slice, darüber mittig das Lightroom-Original (16x9) in voller Breite
- `02.jpg` … – das Panorama nahtlos verteilt: 8x5 → 2, 12x5 → 3, 16x5 → 4, 20x5 → 5 Kacheln
- letzte Kachel – verschwommener Front-Slice mit Blende, Zeit, ISO, Brennweite, Kamera, Objektiv,
  © und Instagram-Name (aus den Metadaten bzw. der config)
Photoshop bleibt dafür bis zum Schluss geöffnet. Einstellungen: `carousel_aktiv`, `carousel_breite`,
`carousel_hoehe`, `carousel_unschaerfe`, `carousel_abdunkeln`, `carousel_trennlinie` (`grafik` oder `linie`), `carousel_schrift` (PostScript-Name, z. B.
`HelveticaNeue-Light`, `SFProDisplay-Light`, `AvenirNext-Regular`), `copyright`, `instagram`.
**Schriftvorschau:** In Photoshop Datei → Skripten → Durchsuchen … → `Schriftvorschau.jsx` aus dem Paket.
SF Pro ist für Photoshop nur nutzbar, wenn sie von developer.apple.com/fonts installiert wurde.

## Erleichterungen im Eingabefenster
- **Kennzeichen-Gedächtnis:** Hast du ein Kennzeichen schon einmal eingegeben, kannst du Airline
  und Typfamilie leer lassen – sie werden aus dem Verlauf ergänzt.
- **Auswahllisten:** Airline, Flughafen und Typfamilie bieten bisherige Eingaben und deine
  vorhandenen Familien-Ordner an (Tippen ergänzt automatisch).
- **Typfamilie:** Untertypen werden gekürzt: A340-600 → `A340`, 777-300ER → `B777`.
  Vorhandene Ordner wie `B777`, `777` oder `Boeing 777` werden erkannt.
- **Spots:** Hat das Foto GPS-Daten und liegt an einem deiner Spots, sind Flughafen und Runway
  vorbelegt. Runway leer lassen = Wert des Spots für die gewählte Flugrichtung.
- Flughafen und Flugrichtung vom letzten Bild werden vorgeschlagen.
- Fehlt ein Pflichtfeld, erscheint ein Hinweis und das Fenster öffnet sich mit deinen Eingaben erneut.
- **„Speicherort ändern …“** öffnet eine Ordnerauswahl; die Wahl wird dauerhaft gespeichert.

## Installation (einmalig)
1. **Python prüfen:** Terminal öffnen, `python3 --version` eingeben. Bietet macOS die Installation der
   Entwicklerwerkzeuge an, bestätigen und abwarten.
2. **Kurzbefehl anlegen (zuerst, der Installer fragt nach dem Namen):** App „Kurzbefehle“ → Einstellungen → Erweitert →
   „Ausführen von Skripts erlauben“. Neuer Kurzbefehl **Spotting Export** mit der Aktion „Shell-Skript ausführen“:
   ```
   /usr/bin/python3 ~/Library/Application\ Support/SpottingExport/spotting_export.py
   ```
   Zeile einfügen, nicht abtippen. Kein Tastaturkurzbefehl in der Kurzbefehle-App – das Kürzel kommt in Schritt 5.
3. **Installieren:** ZIP entpacken, im Terminal:
   ```
   cd ~/Downloads/Spotting-Export-DE
   bash install.sh
   ```
   Der Installer fragt den Speicherort (Ordnerauswahl), Name für das ©, Instagram-Name und Kurzbefehl-Name ab und kopiert
   den Photoshop-Menüpunkt nach `/Applications/Adobe Photoshop 2026/Presets/Scripts/` (fragt nach dem Mac-Passwort).
   Nur falls das scheitert, von Hand: `sudo cp Spotting-Export.jsx "/Applications/Adobe Photoshop 2026/Presets/Scripts/"`
4. **Lightroom:** Voreinstellungen → Externe Bearbeitung → Photoshop: TIFF, 8 Bit, sRGB empfohlen.
   Lightroom mit ⌘Q beenden und neu starten – es erscheint „Spotting Export bereit“.
5. **Tastenkürzel in Photoshop:** Photoshop neu starten → Bearbeiten → Tastaturbefehle → Anwendungsmenüs →
   Datei → Skripten → **Spotting-Export** → Kürzel drücken (z. B. ⌃⌘E) → OK.
6. **Testlauf:** Bild über „Bearbeiten in Photoshop“ öffnen, Kürzel drücken, Berechtigungsabfragen von macOS bestätigen.

Einstellungen später ändern: `open -e "$HOME/Library/Application Support/SpottingExport/config.json"`

## Tastenkürzel direkt in Photoshop (empfohlen)
install.sh legt in Photoshop den Menüpunkt **Datei → Skripten → Spotting-Export** an. Er startet
deinen Kurzbefehl. So vergibst du ein Tastenkürzel, das Photoshop selbst verwaltet:
1. Photoshop neu starten.
2. **Bearbeiten → Tastaturbefehle …**, oben „Tastaturbefehle für: Anwendungsmenüs“.
3. **Datei** aufklappen, ganz unten bei **Skripten → Spotting-Export** in das Feld klicken und die
   Kombination drücken. Ist sie belegt, zeigt Photoshop das sofort an.
4. Mit **OK** bestätigen.
Der Name deines Kurzbefehls steht in `kurzbefehl_name.txt` (wird bei der Installation abgefragt).

## Benötigte Zugriffe
| Berechtigung | Wofür |
|---|---|
| Kurzbefehle: „Ausführen von Skripts erlauben“ | Hotkey darf das Skript starten |
| Automation: Kurzbefehle → Adobe Photoshop | Bildgröße lesen, exportieren, schließen |
| Automation: Kurzbefehle → Lightroom Classic | Lightroom in den Vordergrund holen |
| Dateien und Ordner | Bearbeitungskopie lesen, in den Cloud-Ordner schreiben |
| Bedienungshilfen: Kurzbefehle | in Lightroom den Menüpunkt des Plugins anklicken (Datei → Zusatzmoduloptionen) |

Nicht nötig: Internetzugang, API-Key, Bildschirmaufnahme, Administratorrechte.
Freigaben lassen sich unter Systemeinstellungen → Datenschutz & Sicherheit verwalten.

## Lightroom-Dateiname (deine Exportvorgabe)
Nutzt dein Lightroom-Export einen eigenen Dateinamen mit festen Teilen und dem Feld
„Benutzerdefinierter Text“:
1. Im Exportdialog die Einstellungen als Vorgabe speichern (links „Hinzufügen“), z. B. „Spotting“.
2. In `config.json`: `"lightroom_exportvorgabe": "Spotting"` (oder voller Pfad zur .lrtemplate).
3. Übernommen wird alles aus der Vorgabe; geändert werden nur Zielordner und der Inhalt des
   Freitext-Felds. Diesen bestimmt `lr_freitext_muster` (Standard `{kennzeichen}-{format}`).
   Platzhalter: `{kennzeichen}`, `{airline}`, `{flughafen}`, `{runway}`, `{familie}`,
   `{freitext}`, `{format}` (Seitenverhältnis des Lightroom-Zuschnitts, z. B. 16x9).

## Weitere Einstellungen (`config.json`)
- `front_slice`: `"flugrichtung"` = fliegt nach rechts → rechter Slice. `"gegen_flugrichtung"` dreht es um.
- `photoshop_beenden`: `false` schließt nur das Bild statt Photoshop komplett (schneller).
- `original_suffix`: `"auto"` (Seitenverhältnis aus dem Zuschnitt), fester Wert oder leer.
- `familien_zuordnung`: Familien zusammenfassen, z. B. `{"A319": "A320", "A321": "A320"}`.
- `ordner_oeffnen`: `true` öffnet den fertigen Ordner im Finder.

## Hinweise
- Das Eingabefenster ist ein natives macOS-Fenster. Sollte es auf deinem System nicht starten,
  erscheint automatisch ein einfacher Dialog mit einer Zeile (Felder durch `|` getrennt).
- „Für Web speichern“ kann max. 8192 px pro Seite; größere Bilder werden als JPEG Qualität 12 gespeichert.
- Protokoll: `~/Library/Application Support/SpottingExport/spotting_export.log`
- Verlauf (Kennzeichen, Airlines, Flughäfen): `verlauf.json` im selben Ordner.
- Falls Lightroom nicht reagiert: Bibliothek → Zusatzmoduloptionen →
  „Spotting Export jetzt ausführen“.

## Deinstallieren
Lightroom und Photoshop beenden, im entpackten Ordner: `bash uninstall.sh`. Danach den Kurzbefehl löschen und beide Programme neu starten.

## Lizenz
Kostenlos für die private, nicht-kommerzielle Nutzung (CC BY-NC 4.0, siehe LICENSE.txt), ohne Gewähr.

## Wechsel zwischen Versionen
Vor dem Installieren einer anderen Version (z. B. Englisch) immer erst `bash uninstall.sh` ausführen und Lightroom mit ⌘Q neu starten.
