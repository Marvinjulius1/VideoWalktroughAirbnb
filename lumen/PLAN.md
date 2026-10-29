# Lumen – Projektplan (Phase 0)

> Arbeitstitel: **Lumen**. Ein neutraler IPTV-Player für Android, Android TV, Fire TV und iOS.
> Lumen liefert **keine Inhalte**. Nutzer tragen ihre eigenen Quellen ein (Xtream Codes, M3U-URL, M3U-Datei).

Stand: Phase 0 (Planung, noch kein Code). Offene Rückfragen stehen am Ende (Abschnitt 13).

---

## 1. Leitplanken (verbindlich, gelten für jeden Schritt)

| # | Regel | Wie wir sie technisch absichern |
|---|-------|--------------------------------|
| 1 | Keine vorinstallierten Inhalte, Playlists, Demo-Zugänge, Anbieter-Links | Erster Start = leerer Zustand „Quelle hinzufügen“. Ein CI-Test sucht im Code nach `http(s)://`-Literalen außerhalb einer Allowlist (Testserver `localhost`, Lizenz-/Doku-Links). |
| 2 | Kein Smarters-Branding, keine kopierten Assets/Texte/Screens/Code | Eigener Name, eigenes Logo, eigene Icons (Phosphor-Set, MIT). Navigation bewusst anders (siehe Abschnitt 7). Kein Fremdcode, nur eigene Implementierung gegen die öffentlich dokumentierte Xtream-API. |
| 3 | Inhaltshinweis | Auf dem letzten Onboarding-Screen (Pflicht-Bestätigung) und unter Einstellungen → Info: *„Diese App enthält keine Inhalte. Du bist selbst dafür verantwortlich, nur Quellen zu verwenden, zu deren Nutzung du berechtigt bist.“* |
| 4 | Keine Werbung für illegale Nutzung | Store-Texte und Screenshots nur mit eigenen, legalen Testinhalten (z. B. öffentliche HLS-Testvideos, selbst gebaute Mock-Kanäle mit Fantasienamen). Keine Wörter wie „kostenlos Sky/DAZN“, „10.000 Sender“ usw. |
| 5 | Datenschutz | Zugangsdaten nur lokal, verschlüsselt (`flutter_secure_storage` → iOS Keychain / Android Keystore). Keine Analytics, kein Crash-Reporting-Dienst, keine eigenen Server in v1. Datenschutzerklärung als Entwurf in `docs/legal/PRIVACY_de.md` + `_en.md`. |
| 6 | Store-Vorbereitung | `docs/store/` mit Data-Safety (Google), App Privacy (Apple), Altersfreigabe-Fragebögen, Review-Notizen. **Hinweis:** Apple und Google prüfen IPTV-Player streng (Apple Guideline 5.2.3 „Audio/Video Downloading“ und 5.2 „Intellectual Property“, Google Policy „Intellectual Property“). **Vor der Einreichung lässt du einen Anwalt draufschauen** – steht so auch in `RELEASE.md`. |

---

## 2. Tech-Stack und Begründung

| Bereich | Wahl | Warum |
|--------|------|-------|
| Framework | **Flutter (Dart, stable)** | Eine Codebasis für Phone, Tablet, Android TV, Fire TV, iOS. Eigene Rendering-Engine → unser Apple/Trade-Republic-Look sieht überall gleich aus. tvOS ist mit Flutter nicht offiziell möglich → nicht Teil von v1. |
| Player | **`media_kit`** (libmpv) hinter einer eigenen Schnittstelle `PlayerEngine` | libmpv spielt praktisch alles, was IPTV-Server ausliefern (MPEG-TS, HLS, MKV, AC3/EAC3, mehrere Audiospuren, eingebettete Untertitel). **Die Abstraktion ist der wichtige Teil:** Falls media_kit auf schwachen Fire-TV-Sticks ruckelt, kann ein zweiter Motor (ExoPlayer/Media3 via `video_player`) dahinter gesteckt werden, ohne dass sich UI-Code ändert. |
| State | **Riverpod** (mit `riverpod_generator`) | Testbar ohne Widgets, klare Abhängigkeiten (Provider überschreiben im Test = Mock-Server). |
| Navigation | **go_router** | Deklarative Routen, Deep-Links, `StatefulShellRoute` für Tabs, die ihren Zustand behalten. |
| Datenbank | **Drift** (SQLite) + **FTS5** | Typsichere Abfragen, Migrationen, reaktive Streams (`watch()`) für die UI. FTS5 = Volltextsuche über 100.000+ Einträge in Millisekunden. |
| Netzwerk | **dio** + eigener Retry-Interceptor + `dio_cache_interceptor` | Timeouts, exponentielles Backoff, Caching für Poster/Infos. |
| Bilder | `cached_network_image` mit Größenlimit | Tausende Logos/Poster ohne Speicherexplosion (Cache-Breite = tatsächliche Anzeigegröße). |
| Sichere Speicherung | `flutter_secure_storage` | Keychain / Keystore. |
| Einstellungen | Drift-Tabelle `settings` (statt shared_preferences) | Eine Quelle der Wahrheit, migrierbar, testbar. |
| Parsing großer Daten | **Isolates** (`Isolate.run` / eigener Worker) + Streaming-Parser | Hauptthread bleibt flüssig (60/120 fps), auch bei 50 MB-M3U oder 200 MB-XMLTV. |
| JSON | `json_serializable` / `freezed` | Unveränderliche Modelle, robuste Deserialisierung (Xtream liefert Zahlen mal als String, mal als Int → tolerante Converter). |
| Icons | **`phosphor_flutter`** (MIT, Stil „regular/fill“) | Ruhig, SF-Symbols-ähnlich, einheitlich. |
| Schrift | **Inter** (OFL, als Asset gebündelt) mit `FontFeature.tabularFigures()` für Zahlen | SF Pro darf außerhalb von Apple-Plattformen nicht verteilt werden. Inter ist sehr nah dran. |
| Lokalisierung | `flutter_localizations` + ARB (`de`, `en`) | Standard, unterstützt von Stores. |
| Benachrichtigungen | `flutter_local_notifications` + `timezone` | Lokale Erinnerungen für Sendungen, kein Push-Server. |
| Dateiimport | `file_picker` | M3U-Datei auswählen. |
| PiP | Android: eigener Platform-Channel (`enterPictureInPictureMode`); iOS: siehe Risiko R2 | |
| Cast | Chromecast: `flutter_chrome_cast` (oder eigener Channel zum Google Cast SDK); AirPlay: `AVRoutePickerView` als Platform-View | Siehe Risiko R3. |
| Externer Player | `android_intent_plus` (VLC, MX Player, „Andere App wählen“) | |
| Tests | `flutter_test`, `mocktail`, eigener **In-Process-Mock-Server** (`shelf`) für Xtream + M3U + XMLTV, `integration_test` | Keine echten Anbieter, nur selbst erzeugte Fixtures. |
| CI | GitHub Actions: `flutter analyze`, `flutter test`, Format-Check, Android-Build | |

**Abweichungen von deinem Vorschlag:** keine grundsätzlichen. Zwei Ergänzungen:
1. Der Player läuft hinter `PlayerEngine` (Austauschbarkeit, siehe oben).
2. Auf **iOS** wird für HLS/MP4 zusätzlich ein **AVPlayer-Motor** eingeplant, weil nur AVPlayer System-PiP und AirPlay sauber unterstützt. MPEG-TS-Streams (die AVPlayer nicht abspielt) laufen weiter über media_kit. Entscheidung wird in Phase 3 per Prototyp verifiziert.

---

## 3. Architektur

Schichten (von außen nach innen), „Feature-first“ organisiert:

```
UI (Widgets, Screens)          ← nur Darstellung + Interaktion
   │ liest/ruft
Controller (Riverpod Notifier) ← Bildschirmzustand, Use-Cases
   │
Repository                     ← EINE API für die UI: „gib mir Kanäle der Kategorie X“
   │            │
Datenquellen:  Lokal (Drift)   Remote (XtreamClient, M3uSource, XmltvSource)
```

**Warum so?** Die UI liest **immer aus der lokalen Datenbank** (offline-fähig, sofort da). Netzwerk wird nur beim „Aktualisieren“ benutzt, das die DB befüllt. Dadurch ist es egal, ob die Quelle Xtream oder M3U ist – beide werden in dasselbe Datenmodell normalisiert.

### Quellen-Abstraktion

```dart
abstract interface class SourceProvider {
  Future<AccountInfo?> testConnection();          // Verbindungstest mit typisierten Fehlern
  Stream<SyncProgress> sync(SyncScope scope);     // füllt die DB in Batches
  Future<VodDetail> vodDetail(String id);         // on demand (Xtream), sonst aus M3U-Daten
  Future<SeriesDetail> seriesDetail(String id);
  Uri liveUrl(Channel c, StreamFormat f);
  Uri? catchupUrl(Channel c, DateTime start, Duration d);
}
// Implementierungen: XtreamProvider, M3uUrlProvider, M3uFileProvider
```

### Fehlerklassen (für verständliche Meldungen)

`InvalidCredentials`, `AccountExpired`, `AccountDisabled`, `ServerUnreachable`, `Timeout`, `TlsError`, `InvalidPlaylist`, `TooManyConnections`, `Unknown`. Jede Klasse hat einen freundlichen Text in `de`/`en` und – wo möglich – einen Lösungsvorschlag („Prüfe, ob die Adresse mit http:// beginnt“).

### Synchronisierung großer Listen

1. Download als **Stream** (dio `ResponseType.stream`) in eine temporäre Datei – kein 50-MB-String im Speicher.
2. Parsen **im Isolate**, zeilenweise (M3U) bzw. SAX-artig (XMLTV via `xml`-Paket `XmlEventDecoder`) bzw. JSON-Array-Streaming (Xtream `get_live_streams` kann > 30 MB sein).
3. Ergebnisse in **Batches à 2.000 Zeilen** an den Hauptisolate → Drift `batch()` Insert in einer Transaktion.
4. Synchronisation **ersetzt** Daten pro Profil atomar (Staging-Tabellen → Swap), damit Favoriten/Verlauf über stabile Schlüssel (`stream_id` bzw. Hash aus `tvg-id`+URL) erhalten bleiben.
5. Fortschritt (`SyncProgress`) wird in der UI dezent angezeigt.
6. UI-Listen sind **lazy** (`ListView.builder`/`SliverGrid` + paginierte Drift-Abfragen mit `LIMIT/OFFSET` bzw. Keyset-Pagination).

---

## 4. Ordnerstruktur

```
lumen/
├── PLAN.md  RELEASE.md  README.md  analysis_options.yaml  pubspec.yaml
├── assets/
│   ├── fonts/Inter/…            (OFL-Lizenz liegt bei)
│   ├── brand/                   (Logo, App-Icon-Quellen, TV-Banner – eigene Assets)
│   └── illustrations/           (leere Zustände, eigene SVGs)
├── docs/
│   ├── legal/PRIVACY_de.md, PRIVACY_en.md, CONTENT_NOTICE.md
│   ├── store/google_data_safety.md, apple_app_privacy.md, age_rating.md,
│   │         review_notes.md, listing_de.md, listing_en.md, amazon.md
│   └── design/tokens.md, screens.md
├── lib/
│   ├── main.dart
│   ├── app/                     (App-Widget, Router, Bootstrap, Plattform-Erkennung)
│   ├── core/
│   │   ├── design/              (Tokens, Theme, Typografie, Motion, Haptik)
│   │   ├── widgets/             (LumenButton, LumenCard, PosterCard, FocusScale,
│   │   │                         GlassBar, EmptyState, ProgressBar, LiveBadge …)
│   │   ├── tv/                  (Fokus-Helfer, D-Pad-Shortcuts, Overscan-Padding)
│   │   ├── network/             (Dio-Factory, Retry, Fehler-Mapping)
│   │   ├── db/                  (Drift-Datenbank, Tabellen, DAOs, Migrationen)
│   │   ├── security/            (SecureStore, PIN-Hashing)
│   │   ├── l10n/                (ARB-Dateien)
│   │   └── utils/
│   ├── features/
│   │   ├── onboarding/
│   │   ├── sources/             (Profile, Formulare, Verbindungstest, Kontoinfo, Sync)
│   │   │   ├── data/xtream/     (XtreamClient, DTOs, URL-Builder)
│   │   │   ├── data/m3u/        (M3uParser, Isolate-Worker)
│   │   │   └── …
│   │   ├── home/
│   │   ├── live/
│   │   ├── epg/                 (XMLTV-Parser, Programmführer-Raster)
│   │   ├── movies/
│   │   ├── series/
│   │   ├── player/              (PlayerEngine, MediaKitEngine, Overlay, Gesten,
│   │   │                         Multi-Screen, Sleep-Timer, PiP, Cast)
│   │   ├── search/
│   │   ├── library/             (Favoriten, Verlauf, Weiterschauen)
│   │   ├── parental/            (PIN, gesperrte Kategorien)
│   │   ├── reminders/
│   │   └── settings/
│   └── platform/                (Method-Channels: PiP, externer Player, Fire-TV-Tasten)
├── test/
│   ├── fixtures/                (selbst erzeugte Xtream-JSON, M3U, XMLTV – Fantasiedaten)
│   ├── mock_server/             (shelf-Server für Xtream/M3U/XMLTV)
│   ├── unit/ …  widget/ …
├── integration_test/
├── android/  (Leanback-Manifest, TV-Banner, network_security_config)
└── ios/      (Info.plist mit eng begrenzten ATS-Ausnahmen, Background-Modes, PiP)
```

---

## 5. Datenmodell (Drift)

Alle inhaltsbezogenen Tabellen haben `profile_id` (Fremdschlüssel, `ON DELETE CASCADE`).

| Tabelle | Wichtige Spalten | Bemerkung |
|---------|------------------|-----------|
| `profiles` | `id`, `name`, `type` (xtream/m3u_url/m3u_file), `server_url`, `epg_url`, `is_default`, `sort`, `last_sync_at`, `auto_refresh`, `epg_offset_minutes`, `preferred_format` (ts/m3u8), `created_at` | **Keine Passwörter hier.** Benutzername/Passwort/M3U-URL (die oft Zugangsdaten enthält) liegen in Secure Storage unter `profile.<id>.secret`. |
| `account_info` | `profile_id`, `status`, `exp_date`, `active_cons`, `max_cons`, `created_at`, `is_trial`, `server_timezone`, `fetched_at` | Nur Xtream. |
| `categories` | `profile_id`, `kind` (live/vod/series), `remote_id`, `name`, `remote_order` | |
| `category_prefs` | `profile_id`, `kind`, `remote_id`, `hidden`, `locked`, `custom_order` | Getrennt von `categories`, damit Sync die Nutzer-Einstellungen nicht überschreibt. |
| `channels` | `profile_id`, `key` (stabil), `stream_id`, `num`, `name`, `logo`, `category_id`, `epg_channel_id`, `tv_archive`, `archive_days`, `direct_url` (M3U), `added_at` | Index auf (`profile_id`, `category_id`, `num`). |
| `vod_items` | `profile_id`, `stream_id`, `name`, `poster`, `category_id`, `rating`, `added_at`, `container_ext`, `year` | Details (Handlung, Besetzung …) werden on demand geladen und in `vod_details` gecacht. |
| `vod_details` | `profile_id`, `stream_id`, `json`, `fetched_at` | |
| `series` | `profile_id`, `series_id`, `name`, `cover`, `category_id`, `rating`, `last_modified`, `year` | |
| `episodes` | `profile_id`, `series_id`, `episode_id`, `season`, `episode_num`, `title`, `image`, `plot`, `duration_s`, `container_ext` | On demand pro Serie gecacht. |
| `epg_programs` | `profile_id`, `epg_channel_id`, `start_utc`, `end_utc`, `title`, `description`, `has_archive` | Index (`epg_channel_id`, `start_utc`). Nur Fenster −1 Tag … +7 Tage, alte Einträge werden beim Sync gelöscht. |
| `favorites` | `profile_id`, `kind`, `item_key`, `sort`, `added_at` | Eigene Reihenfolge per `sort`. |
| `watch_progress` | `profile_id`, `kind` (vod/episode), `item_key`, `position_ms`, `duration_ms`, `watched`, `updated_at` | „Weiterschauen“ = Position > 2 % und < 92 %. |
| `history` | `profile_id`, `kind`, `item_key`, `watched_at` | Zuletzt gesehen, Limit z. B. 200 pro Profil. |
| `reminders` | `id`, `profile_id`, `channel_key`, `program_start_utc`, `title`, `notification_id` | |
| `search_index` (FTS5, virtuell) | `profile_id`, `kind`, `item_key`, `name` | Wird beim Sync mitbefüllt, mit `unicode61 remove_diacritics 2` (findet „Tagesschau“ auch bei „tagesschau“, „é“=„e“). |
| `settings` | `key`, `value` (JSON) | Sprache, Theme, Akzent, Startseite, Player-Optionen, PIN-Hash (Argon2id/PBKDF2 + Salt), … |

---

## 6. Screen-Liste

**Mobil (Phone/Tablet)** – Tab-Leiste unten: **Start · Live · Filme & Serien · Suche · Profil**

| # | Screen | Inhalt |
|---|--------|--------|
| S1 | Splash | Logo, Bootstrap (DB öffnen, Profil laden). |
| S2–S4 | Onboarding (3 Screens) | 1) „Dein Fernsehen. Schön.“ 2) „Alles an einem Ort – Live, Filme, Serien.“ 3) „Deine Daten bleiben bei dir“ + Inhaltshinweis mit Bestätigung. |
| S5 | Quelle hinzufügen – Auswahl | Drei große Karten: Xtream Codes · M3U-Link · M3U-Datei. |
| S6 | Formular Xtream | Name, Server-URL, Benutzer, Passwort (ein-/ausblendbar), Inline-Validierung, „Verbindung testen & speichern“. |
| S7 | Formular M3U-URL | Name, Playlist-URL, optional EPG-URL. |
| S8 | M3U-Datei | Dateiauswahl, Vorschau (Anzahl Kanäle/Gruppen), optional EPG-URL. |
| S9 | Sync-Fortschritt | Ruhige Animation, Schritte („Kategorien … Kanäle … Programm“). |
| S10 | **Start** | Begrüßung („Guten Abend“), Reihen: Weiterschauen · Jetzt live (mit Fortschrittsbalken) · Favoriten · Neu bei Filmen · Neu bei Serien. Leerer Zustand ohne Quelle. |
| S11 | **Live** | Links Kategorien-Chips (horizontal scrollbar) bzw. Liste auf Tablet, rechts/unten Kanalliste mit Logo, Nummer, „Jetzt“ + Fortschritt + „Danach“. Mini-Vorschau beim Antippen auf Tablet. |
| S12 | Programmführer (EPG-Raster) | Zeitleiste horizontal, Kanäle vertikal, „Jetzt“-Linie, Sprung zu Uhrzeit/Tag. |
| S13 | Sendungsdetail (Sheet) | Titel, Zeit, Beschreibung, Fortschritt, Buttons: Ansehen · Von vorn (Catch-up) · Erinnern. |
| S14 | **Filme & Serien** | Segment-Umschalter oben (Filme / Serien), Kategorien, Poster-Raster, Sortierung. |
| S15 | Filmdetail | Großes Backdrop, Hero-Poster, Metadaten, Handlung, Besetzung, Trailer, Play/Weiterschauen, Favorit, Gesehen. |
| S16 | Seriendetail | Backdrop, Staffel-Auswahl, Episodenliste mit Bildern, Gesehen-Status, „Weiterschauen S2 E5“. |
| S17 | **Player** | Vollbild, Overlay (Glas), Spuren/Untertitel-Sheet, Seitenverhältnis, Geschwindigkeit, Sleep-Timer, PiP, Cast. |
| S18 | Multi-Screen | 2 (mobil) bzw. 4 (TV/Tablet) Kacheln, Kanal pro Kachel wählen, Audio-Fokus. |
| S19 | **Suche** | Ein Feld, Ergebnisse gruppiert (Live / Filme / Serien), zuletzt gesucht. |
| S20 | **Profil** (Bibliothek) | Aktive Quelle wechseln, Favoriten, Verlauf, Weiterschauen, Quellen verwalten, Einstellungen. |
| S21 | Quellen verwalten | Liste, Standard setzen, bearbeiten, umbenennen, löschen, aktualisieren, Kontoinfo. |
| S22 | Kontoinfo | Status, Ablauf, Verbindungen aktiv/max, erstellt am. |
| S23 | Kategorien verwalten | Ausblenden, Sortieren (Drag & Drop), Sperren. |
| S24 | Einstellungen | Allgemein · Aussehen · Player · EPG · Jugendschutz · Info. |
| S25 | PIN-Eingabe / PIN festlegen | Großes Ziffernfeld (auch per D-Pad). |
| S26 | Info / Rechtliches | Version, Lizenzen (`showLicensePage`), Datenschutz, Inhaltshinweis. |

**TV (Android TV / Fire TV):** gleiche Screens, aber
- **linke Seitenleiste** (Icons, klappt bei Fokus mit Beschriftung aus): Suche · Start · Live · Filme · Serien · Programm · Profil · Einstellungen
- Live-Screen als Dreispalter: Kategorien | Kanäle | Vorschau + EPG
- Text ≥ 24 sp, Fokus = Skalierung 1,06 + Akzentrand 3 px + leichter Schatten
- Overscan-sichere Ränder (5 % ≈ 48 dp horizontal, 27 dp vertikal)

---

## 7. Abgrenzung zu IPTV Smarters (bewusst anders)

| Smarters | Lumen |
|----------|-------|
| Kachel-Dashboard mit 3 großen bunten Buttons (Live/Movies/Series) | Ruhiger, inhaltsgetriebener Start mit Reihen (Weiterschauen, Jetzt live …) |
| Farbverläufe, viele bunte Icons | Fast schwarz, ein Akzent, monochrome Linien-Icons |
| Navigation über Zurück zum Dashboard | Dauerhafte Tab-Leiste (mobil) bzw. Seitenleiste (TV), Suche immer erreichbar |
| Filme und Serien getrennte Bereiche | Ein Bereich „Filme & Serien“ mit Segment-Umschalter |
| EPG als eigene Liste | „Jetzt/Danach“ direkt am Kanal + Raster als Zusatz |

---

## 8. Design-Tokens

Zentral in `lib/core/design/tokens.dart` (+ Dokumentation in `docs/design/tokens.md`). Widgets verwenden **nie** Rohwerte.

### Farben

| Token | Dunkel (Standard) | Hell |
|-------|-------------------|------|
| `bg` | `#000000` | `#FFFFFF` |
| `bgElevated` | `#0A0A0A` | `#F5F5F7` |
| `surface1` | `#141414` | `#FFFFFF` |
| `surface2` | `#1C1C1E` | `#F2F2F7` |
| `surface3` (gedrückt/Fokus-Fläche) | `#2C2C2E` | `#E5E5EA` |
| `separator` | `#FFFFFF` 8 % | `#000000` 8 % |
| `textPrimary` | `#FFFFFF` | `#000000` |
| `textSecondary` | `#FFFFFF` 64 % (≈ `#A3A3A3`) | `#3C3C43` 64 % |
| `textTertiary` | `#FFFFFF` 40 % | `#3C3C43` 40 % (nur für Deko, nicht für Pflichttext → WCAG) |
| `accent` (Standard) | `#0A84FF` Blau | `#007AFF` |
| Akzent-Alternativen | Grün `#30D158` · Mint `#63E6BE` · Orange `#FF9F0A` · Lila `#BF5AF2` · Graphit `#8E8E93` | jeweils helle Variante |
| `live` / `error` | `#FF453A` | `#FF3B30` |
| `success` | `#30D158` | `#34C759` |
| `scrim` (Overlay) | `#000000` 55 % | – |
| `glass` | `#1C1C1E` 72 % + Blur σ 24 | `#F5F5F7` 72 % + Blur σ 24 |

Alle Kombinationen Text/Fläche werden per Unit-Test auf **Kontrast ≥ 4,5 : 1** (WCAG AA) geprüft.

### Typografie (Inter, tabellarische Ziffern für Zeiten/Nummern)

| Token | Mobil | TV | Gewicht |
|-------|-------|----|---------|
| `largeTitle` | 34 / 40 | 48 / 56 | 700 |
| `title1` | 28 / 34 | 40 / 48 | 700 |
| `title2` | 22 / 28 | 32 / 40 | 600 |
| `headline` | 17 / 22 | 28 / 34 | 600 |
| `body` | 17 / 24 | 26 / 34 | 400 |
| `callout` | 16 / 21 | 24 / 30 | 400 |
| `subhead` | 15 / 20 | 24 / 30 | 500 |
| `footnote` | 13 / 18 | 24 / 28 | 400 |
| `caption` | 12 / 16 | 22 / 26 (nur Deko) | 500 |
| `numeric` | wie Kontext + `tnum` | | 500 |

Letter-Spacing: Titel −0,4 bis −0,8 %, Body 0. Zeilenlänge für Fließtext max. ~65 Zeichen. Respektiert System-Textgröße (`MediaQuery.textScaler`, gedeckelt bei 1,6× wo Layout es erfordert).

### Abstände, Radien, Schatten

- **Spacing-Skala (4er-Raster):** 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 56 · 72
- **Seitenrand:** mobil 20, Tablet 32, TV 48 (Overscan)
- **Radien:** `sm 10` (Chips) · `md 16` (Karten, Felder) · `lg 20` (Poster) · `xl 24` (Sheets) · `pill 999`
- **Schatten:** keiner im Dunkelmodus (Tiefe über Flächenhelligkeit); hell: sehr weich `0 8 24 rgba(0,0,0,0.06)`
- **Poster:** 2:3, Kanal-Logo-Kachel 16:9 bzw. 1:1, Backdrop 16:9

### Bewegung

| Token | Dauer | Kurve |
|-------|-------|-------|
| `fast` | 200 ms | `Curves.easeOutCubic` |
| `normal` | 280 ms | Feder (`SpringDescription` Masse 1, Steifigkeit 380, Dämpfung 30) |
| `slow` | 350 ms | `Curves.easeInOutCubic` |
| Fokus-Skalierung TV | 150 ms | `easeOut`, Faktor 1,06 |
| Overlay-Ausblenden | nach 4 s Inaktivität, 250 ms Fade |

„Bewegung reduzieren“ (`MediaQuery.disableAnimations` / Android „Animationen entfernen“): Dauern → 0, Hero → Überblendung, keine Skalierung.

**Haptik:** `HapticFeedback.selectionClick()` bei Auswahl, `lightImpact` bei Favorit, abschaltbar.

### Kernkomponenten (Phase 1)

`LumenScaffold`, `GlassTabBar`, `TvSideRail`, `LumenButton` (primär/sekundär/Text), `LumenTextField` (groß, Inline-Fehler, Passwort-Toggle), `LumenCard`, `PosterCard` (Hero), `ChannelTile`, `ContentRow` (horizontale Reihe mit Titel), `LiveBadge`, `ThinProgressBar`, `SegmentedControl`, `EmptyState`, `LumenSheet`, `FocusScale` (TV), `PinPad`, `Skeleton` (Lade-Platzhalter statt Spinner).

---

## 9. Plattform-Details

### Android / Android TV / Fire TV (eine APK/AAB)
- `minSdk 23` (Fire OS 6+ basiert auf Android 7.1; Fire OS 5 = Android 5.1 wird bewusst **nicht** unterstützt – Leistung zu schwach für libmpv), `targetSdk` = aktuelles Play-Pflichtniveau.
- Manifest: `android.software.leanback required=false`, `android.hardware.touchscreen required=false`, `LEANBACK_LAUNCHER`-Intent, `android:banner` (320×180, eigenes Design).
- Cleartext-HTTP: über `network_security_config.xml` erlaubt, **weil Nutzer eigene Server oft per http betreiben**. Begründung kommt in die Review-Notes.
- PiP: `supportsPictureInPicture`, `resizeableActivity`.
- Fire-TV-Tasten: `KEYCODE_MENU`, `MEDIA_PLAY_PAUSE`, `MEDIA_REWIND`, `MEDIA_FAST_FORWARD`, Ziffern (falls Fernbedienung sie hat), `DPAD_*`, `BACK`.
- Signing: Upload-Key lokal, nie im Repo; Play App Signing.

### iOS
- Mindestversion iOS 15 (PiP mit `AVPictureInPictureController.ContentSource` ab 15).
- Background Modes: `audio` (für PiP / Hintergrund-Audio).
- **ATS:** kein pauschales `NSAllowsArbitraryLoads`. Geplant: `NSAllowsArbitraryLoadsForMedia = YES` (betrifft nur AVFoundation-Medien) + `NSAllowsLocalNetworking = YES`. libmpv/dart:io-Sockets laufen nicht über das ATS-geprüfte URLSession – das wird in Phase 3 verifiziert und dokumentiert. Falls trotzdem `NSAllowsArbitraryLoads` nötig wird, mit schriftlicher Begründung für Apple („Nutzer verbinden sich mit eigenen, selbst eingetragenen Medienservern, deren Protokoll die App nicht kontrolliert“).
- Kein Apple-TV-Target in v1.

---

## 10. Teststrategie

| Ebene | Was | Werkzeug |
|-------|-----|----------|
| Unit | M3U-Parser (Attribute, Anführungszeichen, `#EXTVLCOPT`, kaputte Zeilen, BOM, CRLF, 100k Zeilen Performance), XMLTV-Parser (Zeitzonen `+0100`, fehlende Felder), Xtream-DTOs (String/Int-Chaos, `null`, leere Arrays), URL-Builder (Port, Slash, https), Fehler-Mapping, PIN-Hashing, Kontrast-Tokens | `flutter_test`, `mocktail` |
| Integration (ohne Gerät) | XtreamClient gegen lokalen **shelf-Mock-Server** mit Fixture-JSON; Sync füllt In-Memory-Drift korrekt | `shelf`, `drift` NativeDatabase.memory |
| Widget | Onboarding, Formular-Validierung, Leerer Zustand, Kanalliste, EPG-Zeile, Player-Overlay (mit Fake-Engine), D-Pad-Fokus-Reihenfolge | `flutter_test` + `golden`-Screenshots für Design-Regressionen |
| Gerät | Playback, PiP, Cast, TV-Fokus, Performance | Emulator / echte Geräte (siehe unten) |

**Teststreams:** nur frei verfügbare, legale Quellen (z. B. die öffentlichen HLS-Beispielstreams von Apple Developer, Mux-Testvideo „Big Buck Bunny“/Blender-Open-Movies). Diese URLs stehen **nur** in `test/` bzw. in einem Debug-only-Konfigurationspfad, **nie** in der Release-App.

**Ehrlicher Hinweis zur Umgebung:** Ich arbeite in einem Linux-Cloud-Container. Hier kann ich `flutter analyze`, `flutter test` und Android-Builds ausführen (sofern das SDK installierbar ist). **Nicht möglich hier:** iOS-Builds (benötigen macOS + Xcode), Android-/TV-Emulatoren mit Hardwarebeschleunigung (kein KVM), echte Fire-TV-Geräte, Chromecast, AirPlay. Diese Tests musst du auf deinen Geräten machen – ich liefere dafür pro Meilenstein eine kurze Testcheckliste.

---

## 11. Meilensteine

| Phase | Inhalt | „Fertig“, wenn … |
|-------|--------|------------------|
| **0 – Plan** | Dieses Dokument, Rückfragen | Du hast die Fragen beantwortet und den Plan freigegeben. |
| **1 – Fundament** | Flutter-Projekt, Lints, CI, Design-System (Tokens, Theme hell/dunkel, Akzentwahl, Inter, Komponenten + Galerie-Screen), Router mit Tab-Leiste/TV-Seitenleiste, Onboarding, Inhaltshinweis, Profile-CRUD, Secure Storage, Leere Zustände, l10n de/en | App startet, Onboarding → „Quelle hinzufügen“ → Profil gespeichert (noch ohne Sync). `analyze` + `test` grün. |
| **2 – Daten** | Drift-Schema + Migrationen, XtreamClient (alle Actions), Fehler-Mapping, Verbindungstest + Kontoinfo, M3U-Parser (Isolate, Streaming), Sync mit Batches + Fortschritt, FTS-Index, Auto-Refresh, Mock-Server + Fixtures | 100k-Kanal-Fixture wird ohne UI-Ruckler importiert (Messwert dokumentiert), Tests ≥ 80 % Abdeckung für `data/`. |
| **3a – Live + Player** | Live-Screen, Kategorien, Favoriten, Verlauf, PlayerEngine + MediaKit, Overlay, Gesten, D-Pad, Kanalwechsel (Hoch/Runter, Ziffern, letzter Kanal), Spuren/Untertitel, Seitenverhältnis, Reconnect, Fehlerhinweise, Puffer/HW-Decoding | Teststream läuft auf Phone + Android-TV-Emulator; Kanalwechsel < 1 s bis Overlay. |
| **3b – EPG** | Xtream short EPG + xmltv.php, XMLTV-URL (Streaming-Parser), Jetzt/Danach, Raster, Details, Zeitzonen-Offset, Erinnerungen | 7-Tage-EPG für 1.000 Kanäle in < 30 s importiert; Raster scrollt flüssig. |
| **3c – Filme & Serien** | Raster, Sortierung, Details, Hero, Weiterschauen, Gesehen, Staffeln/Episoden, Auto-Next, Geschwindigkeit, Trailer | Weiterschauen überlebt App-Neustart. |
| **4 – Extras** | Multi-Screen, Catch-up/Timeshift, Jugendschutz (PIN, Sperren), Chromecast, AirPlay, PiP, externer Player, Sleep-Timer, globale Suche-Feinschliff | Checkliste Phase 4 auf deinen Geräten bestanden. |
| **5 – Feinschliff & Store** | TV-Fokus-Polish, Performance (Startzeit, Speicher), Barrierefreiheit (Screenreader, Kontrast, Schriftgröße), App-Icon/Banner, Store-Texte/Screenshots (legal), Data-Safety/App-Privacy, Altersfreigabe, Review-Notes, Datenschutzerklärung, `RELEASE.md` | Release-Kandidat; Anwalt hat Store-Texte + Datenschutz geprüft. |

Jede Phase wird in kleinen Commits umgesetzt, nach jedem Schritt `flutter analyze` + `flutter test`.

---

## 12. Risiken und wie wir damit umgehen

| # | Risiko | Gegenmaßnahme |
|---|--------|---------------|
| R1 | **Store-Ablehnung** (IPTV-Apps stehen unter Generalverdacht) | Strikt leere App, klarer Inhaltshinweis, Review-Notes mit eigenem legalen Test-Setup (z. B. selbst gehostete M3U mit Open-Source-Filmen, die wir dem Reviewer nennen), neutrale Texte, Anwalt vor Einreichung. Apple lehnt dennoch manchmal ab – dafür planen wir Zeit für Rückfragen ein. |
| R2 | **iOS-PiP mit media_kit** ist nicht ohne Weiteres möglich (PiP braucht AVPlayerLayer bzw. Sample-Buffer-Layer) | Zweiter Motor AVPlayer für HLS/MP4 auf iOS; TS-Streams ohne PiP oder via `.m3u8`-Variante des Servers (Xtream liefert meist beides). Prototyp früh in Phase 3a. |
| R3 | **Chromecast kann kein MPEG-TS** | Beim Casten automatisch `.m3u8`-URL verwenden; wenn Server kein HLS anbietet, verständlicher Hinweis. Achtung: Beim Casten bekommt der Chromecast die Stream-URL (inkl. Zugangsdaten im Pfad) – Hinweis im UI/Datenschutz. |
| R4 | **Leistung auf Fire TV Stick (Lite/2. Gen)** | `PlayerEngine`-Abstraktion → ExoPlayer-Fallback; Bild-Caches klein halten; Profiling auf echtem Gerät durch dich. |
| R5 | **Riesige Listen** (100k+ VOD, 200 MB XMLTV) | Streaming + Isolate + Batches + FTS + Lazy-Listen (Abschnitt 3). |
| R6 | **Uneinheitliche Server** (Xtream-Klone liefern Felder unterschiedlich) | Tolerante DTO-Converter, viele Fixture-Varianten, Fehler nie als Absturz. |
| R7 | **Zugangsdaten in URLs** (Xtream-Stream-URLs enthalten Passwort) | URLs werden nie geloggt (Log-Filter), nie in Crash-Texten angezeigt, „Fehlerdetails kopieren“ maskiert Zugangsdaten. |
| R8 | **Lizenzen** (libmpv/FFmpeg = LGPL) | media_kit-Binaries dynamisch gelinkt (LGPL-konform), Lizenzseite in der App, Hinweis in `RELEASE.md`. Rechtlich durch den Anwalt mitprüfen lassen. |

---

## 13. Rückfragen an dich (max. 5)

1. **Repository:** Dieses Repo enthält aktuell dein Walkthrough-Video-Projekt. Soll Lumen hier im Unterordner `lumen/` bleiben (so angelegt), oder legst du ein eigenes Repo an (empfohlen – sauberere Store-Builds und CI)?
2. **Identität & Konten:** Welche Bundle-/Package-ID sollen wir nutzen (z. B. `de.deinname.lumen`)? Hast du bereits Entwicklerkonten (Apple Developer 99 $/Jahr, Google Play 25 $ einmalig, Amazon kostenlos) und Zugriff auf einen **Mac** für iOS-Builds?
3. **Testgeräte:** Welche echten Geräte hast du (Android-Handy, iPhone, welcher Fire-TV-Stick, Android-TV-Gerät, Chromecast)? Danach richte ich die Mindestanforderungen und Test-Checklisten aus.
4. **Standard-Akzentfarbe:** Apple-Blau `#0A84FF` oder ein Trade-Republic-artiges Grün `#30D158`? (Der Nutzer kann es später ändern.)
5. **Release-Strategie & Geschäftsmodell:** Erst ein schlankes v1 (Quellen, Live, EPG, Filme, Serien, Player) veröffentlichen und Extras (Multi-Screen, Cast, Catch-up) als v1.1 nachliefern – oder alles in v1? Und soll die App kostenlos, Einmalkauf oder Abo sein (beeinflusst Store-Setup und In-App-Kauf-Integration)?
