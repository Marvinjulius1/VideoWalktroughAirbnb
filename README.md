# Lumen

Ein neutraler, ruhig gestalteter Player für **eigene** IPTV-Quellen
(Xtream Codes, M3U-Link, M3U-Datei) – für iPhone, Android, Android TV und Fire TV.

> **Lumen enthält keine Inhalte.** Keine Sender, keine Playlists, keine
> Zugangsdaten. Du bist selbst dafür verantwortlich, nur Quellen zu
> verwenden, zu deren Nutzung du berechtigt bist.

Plan, Architektur und Design-Tokens: [`PLAN.md`](PLAN.md).

## Stand

| Phase | Status |
|-------|--------|
| 0 – Plan | ✅ |
| 1 – Fundament (Design-System, Navigation, Onboarding, Quellen sicher speichern) | ✅ |
| 2 – Daten (Xtream-Client, M3U-Parser, Datenbank, Sync, Suche) | ✅ |
| 3a – Live-TV und Player | ✅ |
| 3b – EPG (Programmführer) | als Nächstes |
| 3c – Filme und Serien | danach |

## Auf dem Mac starten

Einmalig:

1. Flutter installieren: <https://docs.flutter.dev/get-started/install/macos>
2. Xcode aus dem App Store installieren, danach `sudo xcodebuild -license accept`.
3. Für Android/TV-Emulatoren: Android Studio installieren.

Im Projektordner:

```bash
flutter pub get
```

```bash
flutter test
```

**iPhone (echtes Gerät):** iPhone per Kabel verbinden, `ios/Runner.xcworkspace`
in Xcode öffnen → *Signing & Capabilities* → dein Apple-ID-Team wählen (ein
kostenloses Konto reicht für dein eigenes iPhone). Dann:

```bash
flutter run
```

**Android-Handy-Emulator:** in Android Studio → *Device Manager* → „Pixel“ anlegen und starten, dann `flutter run`.

**Android TV / Fire TV (Emulator):** im Device Manager ein Gerät der Kategorie
*TV* („Android TV 1080p“, API 28 ≈ Fire OS 7) anlegen. Die App erkennt den
Fernseher automatisch und zeigt die Seitenleiste. Bedienung mit den
Pfeiltasten und Enter.

TV-Layout auf jedem Gerät erzwingen (zum Ausprobieren):

```bash
flutter run --dart-define=LUMEN_FORCE_TV=true
```

## Entwicklung

Nach Änderungen an Datenbanktabellen (`lib/core/db/database.dart`):

```bash
dart run build_runner build
```

Nach Änderungen an Texten (`lib/core/l10n/*.arb`):

```bash
flutter gen-l10n
```

## Ausprobieren ohne eigenen Anbieter

Die Tests bringen einen lokalen Mock-Server mit erfundenen Daten mit
(`test/mock_server/mock_server.dart`). Echte Anbieter-Daten gibt es im Repo
nicht und wird es nicht geben.

Messwerte aus den Tests (Linux-Rechner, nicht Handy):
100.000 M3U-Einträge parsen ≈ 1 s; 50.000 Sender komplett laden
(Parsen, Speichern, Suchindex) ≈ 1,7 s.

## Player ohne eigenen Anbieter testen

In `docs/testing/legal-test-streams.m3u` liegen drei öffentliche Teststreams
(Apple-Beispielstreams, Mux). Datei aufs iPhone bringen (AirDrop → „In Dateien
sichern“), dann in Lumen *Quelle hinzufügen → M3U-Datei*. Die Datei gehört
nicht zur App.

Bedienung im Player:

| | Handy | TV-Fernbedienung |
|---|---|---|
| Overlay ein/aus | Tippen | OK |
| Sender wechseln | nach oben/unten wischen | Hoch/Runter, CH+/CH− |
| Sender per Nummer | – | Zifferntasten |
| Pause | Play-Knopf | Play/Pause |
| Ton/Untertitel/Bild | Regler-Knopf oben rechts | Menü-Taste |

## Datenschutz

Zugangsdaten liegen verschlüsselt im iOS-Schlüsselbund bzw. Android Keystore.
Keine Analyse, kein Tracking, keine Werbung, keine Server des Entwicklers.

## Lizenzen

Schrift: Inter (SIL Open Font License). Icons: Lucide (ISC) über
`lucide_icons_flutter` (MIT). Alle Lizenzen sind in der App unter
*Einstellungen → Open-Source-Lizenzen* einsehbar.
