import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/sources/domain/source_profile.dart';

part 'database.g.dart';

/// Profile/Quellen. **Enthält keine Passwörter** – Benutzername, Passwort und
/// Playlist-Adressen (die oft Zugangsdaten enthalten) liegen verschlüsselt im
/// [SecretStore].
@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get type => textEnum<SourceType>()();

  /// Xtream: Basis-Adresse des Servers (ohne Zugangsdaten).
  TextColumn get serverUrl => text().nullable()();

  /// M3U-Datei: Pfad der in die App kopierten Playlist.
  TextColumn get localPath => text().nullable()();

  /// Ursprünglicher Dateiname (nur Anzeige).
  TextColumn get localFileName => text().nullable()();

  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Einfache Schlüssel/Wert-Tabelle für App-Einstellungen.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Profiles, Settings])
class LumenDatabase extends _$LumenDatabase {
  LumenDatabase(super.e);

  /// Datenbank im App-Verzeichnis des Geräts.
  factory LumenDatabase.open() =>
      LumenDatabase(driftDatabase(name: 'lumen'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
