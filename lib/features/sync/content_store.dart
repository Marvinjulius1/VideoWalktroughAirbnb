import 'package:drift/drift.dart';

import '../../core/db/database.dart';
import '../sources/data/xtream/xtream_models.dart';

/// Anzahl Einträge je Inhaltsart.
class ContentCounts {
  const ContentCounts({this.live = 0, this.vod = 0, this.series = 0});

  final int live;
  final int vod;
  final int series;

  int get total => live + vod + series;
}

/// Ein Treffer der globalen Suche.
class SearchHit {
  const SearchHit({required this.kind, required this.itemId, required this.name, this.image});

  final ContentKind kind;
  final int itemId;
  final String name;
  final String? image;
}

/// Alles zum Schreiben und Lesen der geladenen Inhalte einer Quelle.
class ContentStore {
  ContentStore(this._db);

  final LumenDatabase _db;

  /// Einträge pro Schreibpaket. Kleine Pakete halten die App reaktionsfähig,
  /// weil zwischen den Paketen andere Arbeit (z. B. Animationen) drankommt.
  static const batchSize = 2000;

  /// Ersetzt alle Inhalte eines Profils atomar: entweder ist danach alles
  /// neu, oder (bei einem Fehler) alles wie vorher.
  Future<void> replaceAll({
    required String profileId,
    required List<CategoriesCompanion> categories,
    required List<ChannelsCompanion> channels,
    required List<VodItemsCompanion> vod,
    required List<SeriesItemsCompanion> series,
    void Function(int written, int total)? onProgress,
  }) async {
    final total = categories.length + channels.length + vod.length + series.length;
    var written = 0;
    Future<void> insertChunks<T extends Table, D>(TableInfo<T, D> table, List<Insertable<D>> rows) async {
      for (var i = 0; i < rows.length; i += batchSize) {
        final chunk = rows.sublist(i, i + batchSize > rows.length ? rows.length : i + batchSize);
        await _db.batch((b) => b.insertAll(table, chunk));
        written += chunk.length;
        onProgress?.call(written, total);
      }
    }

    await _db.transaction(() async {
      await (_db.delete(_db.categories)..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(_db.channels)..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(_db.vodItems)..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(_db.seriesItems)..where((t) => t.profileId.equals(profileId))).go();
      await insertChunks(_db.categories, categories);
      await insertChunks(_db.channels, channels);
      await insertChunks(_db.vodItems, vod);
      await insertChunks(_db.seriesItems, series);
      await _rebuildSearchIndex(profileId);
      await (_db.update(_db.profiles)..where((p) => p.id.equals(profileId)))
          .write(ProfilesCompanion(lastSyncAt: Value(DateTime.now())));
    });
  }

  /// Füllt den Suchindex mit drei schnellen INSERT…SELECT direkt in SQLite.
  Future<void> _rebuildSearchIndex(String profileId) async {
    await _db.customStatement('DELETE FROM search_index WHERE profile_id = ?', [profileId]);
    for (final (kind, table, image) in const [
      ('live', 'channels', 'logo'),
      ('vod', 'vod_items', 'poster'),
      ('series', 'series_items', 'cover'),
    ]) {
      await _db.customStatement(
        'INSERT INTO search_index (name, kind, item_id, profile_id, image) '
        "SELECT name, '$kind', id, profile_id, $image FROM $table WHERE profile_id = ?",
        [profileId],
      );
    }
  }

  Future<void> removeProfileIndex(String profileId) =>
      _db.customStatement('DELETE FROM search_index WHERE profile_id = ?', [profileId]);

  Future<void> saveAccount(String profileId, XtreamAccount a) =>
      _db.into(_db.accountInfos).insertOnConflictUpdate(AccountInfosCompanion.insert(
            profileId: profileId,
            status: Value(a.status),
            expiresAt: Value(a.expiresAt),
            createdAt: Value(a.createdAt),
            isTrial: Value(a.isTrial),
            activeConnections: Value(a.activeConnections),
            maxConnections: Value(a.maxConnections),
            serverTimezone: Value(a.serverTimezone),
            allowedFormats: Value(a.allowedFormats.join(',')),
            fetchedAt: DateTime.now(),
          ));

  Stream<AccountInfoRow?> watchAccount(String profileId) =>
      (_db.select(_db.accountInfos)..where((a) => a.profileId.equals(profileId)))
          .watchSingleOrNull();

  Stream<ContentCounts> watchCounts(String profileId) {
    final q = _db.customSelect(
      'SELECT '
      '(SELECT COUNT(*) FROM channels WHERE profile_id = ?1) AS live, '
      '(SELECT COUNT(*) FROM vod_items WHERE profile_id = ?1) AS vod, '
      '(SELECT COUNT(*) FROM series_items WHERE profile_id = ?1) AS series',
      variables: [Variable.withString(profileId)],
      readsFrom: {_db.channels, _db.vodItems, _db.seriesItems},
    );
    return q.watchSingle().map((r) => ContentCounts(
          live: r.read<int>('live'),
          vod: r.read<int>('vod'),
          series: r.read<int>('series'),
        ));
  }

  /// Globale Suche. Jedes Wort wird als Präfix gesucht: „tages sch“ findet
  /// „Tagesschau“. Sonderzeichen werden entfernt, damit Eingaben die
  /// FTS-Syntax nicht kaputt machen können.
  Future<List<SearchHit>> search(String profileId, String query, {int limit = 60}) async {
    final match = ftsQuery(query);
    if (match == null) return const [];
    final rows = await _db.customSelect(
      'SELECT kind, item_id, name, image FROM search_index '
      'WHERE search_index MATCH ? AND profile_id = ? '
      'ORDER BY rank LIMIT ?',
      variables: [Variable.withString(match), Variable.withString(profileId), Variable.withInt(limit)],
    ).get();
    return [
      for (final r in rows)
        SearchHit(
          kind: ContentKind.values.byName(r.read<String>('kind')),
          itemId: r.read<int>('item_id'),
          name: r.read<String>('name'),
          image: r.readNullable<String>('image'),
        ),
    ];
  }

  /// Baut aus einer Nutzereingabe eine sichere FTS5-Abfrage.
  static String? ftsQuery(String input) {
    final words = input
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.isNotEmpty)
        .take(8)
        .toList();
    if (words.isEmpty) return null;
    return words.map((w) => '"$w"*').join(' ');
  }
}
