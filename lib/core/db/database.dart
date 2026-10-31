import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/sources/domain/source_profile.dart';
import 'content_kind.dart';

export 'content_kind.dart';

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

@DataClassName('CategoryRow')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Wird das Profil gelöscht, verschwinden auch alle zugehörigen Inhalte.
  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => textEnum<ContentKind>()();
  TextColumn get remoteId => text()();
  TextColumn get name => text()();
  IntColumn get sortIndex => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {profileId, kind, remoteId},
      ];
}

/// Live-Sender.
@DataClassName('ChannelRow')
class Channels extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Wird das Profil gelöscht, verschwinden auch alle zugehörigen Inhalte.
  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();

  /// Stabiler Schlüssel: Xtream `stream_id` bzw. M3U-Schlüssel.
  TextColumn get itemKey => text()();
  IntColumn get num => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get logo => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get epgChannelId => text().nullable()();
  BoolColumn get tvArchive => boolean().withDefault(const Constant(false))();
  IntColumn get archiveDays => integer().withDefault(const Constant(0))();

  /// Nur M3U: direkte Stream-Adresse. Kann Zugangsdaten enthalten – die
  /// Datenbank liegt im privaten App-Ordner und wird nie exportiert.
  TextColumn get url => text().nullable()();
  TextColumn get userAgent => text().nullable()();
  DateTimeColumn get addedAt => dateTime().nullable()();
  IntColumn get sortIndex => integer()();
}

@DataClassName('VodRow')
class VodItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Wird das Profil gelöscht, verschwinden auch alle zugehörigen Inhalte.
  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemKey => text()();
  TextColumn get name => text()();
  TextColumn get poster => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  RealColumn get rating => real().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get containerExt => text().nullable()();
  TextColumn get url => text().nullable()();
  DateTimeColumn get addedAt => dateTime().nullable()();
  IntColumn get sortIndex => integer()();
}

@DataClassName('SeriesRow')
class SeriesItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Wird das Profil gelöscht, verschwinden auch alle zugehörigen Inhalte.
  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemKey => text()();
  TextColumn get name => text()();
  TextColumn get cover => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  RealColumn get rating => real().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get plot => text().nullable()();
  TextColumn get genre => text().nullable()();
  TextColumn get url => text().nullable()();
  DateTimeColumn get lastModified => dateTime().nullable()();
  IntColumn get sortIndex => integer()();
}

/// Kontoinfo (nur Xtream), beim Verbindungstest/Aktualisieren gespeichert.
@DataClassName('AccountInfoRow')
class AccountInfos extends Table {
  // Wird das Profil gelöscht, verschwinden auch alle zugehörigen Inhalte.
  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get status => text().nullable()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  BoolColumn get isTrial => boolean().withDefault(const Constant(false))();
  IntColumn get activeConnections => integer().nullable()();
  IntColumn get maxConnections => integer().nullable()();
  TextColumn get serverTimezone => text().nullable()();
  TextColumn get allowedFormats => text().withDefault(const Constant(''))();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {profileId};
}

/// Favoriten. Verweisen über den stabilen `itemKey`, damit sie ein
/// Aktualisieren der Quelle überleben.
@DataClassName('FavoriteRow')
class Favorites extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => textEnum<ContentKind>()();
  TextColumn get itemKey => text()();

  /// Eigene Reihenfolge (kleiner = weiter oben).
  IntColumn get sortIndex => integer()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {profileId, kind, itemKey},
      ];
}

/// Zuletzt gesehen. Ein Eintrag je Inhalt, mit dem letzten Zeitpunkt.
@DataClassName('HistoryRow')
class WatchHistory extends Table {
  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => textEnum<ContentKind>()();
  TextColumn get itemKey => text()();
  DateTimeColumn get watchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {profileId, kind, itemKey};
}

/// Programmdaten (EPG). Zeiten in UTC. Es wird nur ein Fenster von
/// gestern bis in 7 Tagen gespeichert.
@DataClassName('EpgRow')
class EpgPrograms extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get channelId => text()();
  DateTimeColumn get startUtc => dateTime()();
  DateTimeColumn get endUtc => dateTime()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text().nullable()();
}

/// Erinnerungen an Sendungen (lokale Benachrichtigungen).
@DataClassName('ReminderRow')
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get channelKey => text()();
  TextColumn get channelName => text()();
  TextColumn get epgChannelId => text()();
  TextColumn get title => text()();
  DateTimeColumn get startUtc => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {profileId, epgChannelId, startUtc},
      ];
}

/// Volltext-Suchindex (SQLite FTS5) über Sender, Filme und Serien.
///
/// `remove_diacritics 2`: „Café“ findet auch „cafe“. Spalten mit UNINDEXED
/// werden nur mitgespeichert, nicht durchsucht.
const _epgIndex =
    'CREATE INDEX IF NOT EXISTS idx_epg_channel ON epg_programs (profile_id, channel_id, start_utc)';

const ftsCreateStatement = '''
CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
  name,
  kind UNINDEXED,
  item_id UNINDEXED,
  profile_id UNINDEXED,
  image UNINDEXED,
  tokenize = 'unicode61 remove_diacritics 2'
)''';

@DriftDatabase(tables: [Profiles, Settings, Categories, Channels, VodItems, SeriesItems, AccountInfos, Favorites, WatchHistory, EpgPrograms, Reminders])
class LumenDatabase extends _$LumenDatabase {
  LumenDatabase(super.e);

  /// Datenbank im App-Verzeichnis des Geräts.
  factory LumenDatabase.open() =>
      LumenDatabase(driftDatabase(name: 'lumen'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(categories);
            await m.createTable(channels);
            await m.createTable(vodItems);
            await m.createTable(seriesItems);
            await m.createTable(accountInfos);
            await _createIndexes();
          }
          if (from < 3) {
            await m.createTable(favorites);
            await m.createTable(watchHistory);
          }
          if (from < 4) {
            await m.createTable(epgPrograms);
            await m.createTable(reminders);
            await customStatement(_epgIndex);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _createIndexes() async {
    await customStatement(ftsCreateStatement);
    for (final stmt in const [
      'CREATE INDEX IF NOT EXISTS idx_channels_cat ON channels (profile_id, category_id, sort_index)',
      'CREATE INDEX IF NOT EXISTS idx_channels_key ON channels (profile_id, item_key)',
      'CREATE INDEX IF NOT EXISTS idx_vod_cat ON vod_items (profile_id, category_id, sort_index)',
      'CREATE INDEX IF NOT EXISTS idx_vod_added ON vod_items (profile_id, added_at)',
      'CREATE INDEX IF NOT EXISTS idx_series_cat ON series_items (profile_id, category_id, sort_index)',
      _epgIndex,
    ]) {
      await customStatement(stmt);
    }
  }
}
