# Animationen für Finanz-Reels

HTML-Vorlagen im Apple-Stil, die Bild für Bild als 1080x1920-MP4 (9:16, 30 fps) gerendert werden.

## Vorlagen (`templates/`)

| Vorlage | Inhalt | Wichtige Parameter |
| --- | --- | --- |
| `counter` | hochlaufende Zahl | `to`, `from`, `decimals`, `prefix`, `suffix`, `label`, `sub`, `dur` |
| `chart` | Aktien-Chart (steigend/fallend) | `name`, `desc`, `start`, `end`, `seed`, `dur` |
| `bars` | Zinseszins-Balken | `monthly`, `rate`, `years`, `title` |
| `notification` | iPhone-Benachrichtigungen | `preset` (payment, dividend, crypto, sales) oder `n1`–`n3` als `Titel\|Text\|Icon\|Farbe` |
| `island` | Dynamic Island mit Betrag | `title`, `subtitle`, `amount`, `prefix`, `icon`, `color` |
| `typing` | Tippfeld mit Senden | `text`, `placeholder`, `cps`, `send` |
| `message` | eine Nachricht (WhatsApp/iMessage) fällt von oben rein, mehrzeilig | `app`, `sender`, `text`, `time`, `top`, `hold`, `out` (0 = bleibt stehen) |

Alle Vorlagen kennen `bg=green` für eine Greenscreen-Variante und `bg=transparent` für einen echten durchsichtigen Hintergrund (Ausgabe als `.mov` in ProRes 4444 oder als `.webm`).

## Rendern

```bash
pip install playwright        # Chromium muss installiert sein (playwright install chromium)
python3 render.py counter ausgabe/test.mp4 to=1000000 label="Net worth"
python3 starter_paket.py      # rendert das komplette Starter-Paket nach ausgabe/
```
