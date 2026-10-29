import 'package:drift/drift.dart';

import '../../../core/db/database.dart';

/// Welche Sender gerade gezeigt werden.
sealed class LiveFilter {
  const LiveFilter();
}

class AllChannels extends LiveFilter {
  const AllChannels();
  @override
  bool operator ==(Object other) => other is AllChannels;
  @override
  int get hashCode => 1;
}

class FavoriteChannels extends LiveFilter {
  const FavoriteChannels();
  @override
  bool operator ==(Object other) => other is FavoriteChannels;
  @override
  int get hashCode => 2;
}

class RecentChannels extends LiveFilter {
  const RecentChannels();
  @override
  bool operator ==(Object other) => other is RecentChannels;
  @override
  int get hashCode => 3;
}

class CategoryChannels extends LiveFilter {
  const CategoryChannels(this.categoryId);
  final String categoryId;
  @override
  bool operator ==(Object other) => other is CategoryChannels && other.categoryId == categoryId;
  @override
  int get hashCode => categoryId.hashCode;
}

/// Lesen und Schreiben rund um Live-TV.
class LiveRepository {
  LiveRepository(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final LumenDatabase _db;
  final DateTime Function() _now;

  static const recentLimit = 50;

  Stream<List<CategoryRow>> watchCategories(String profileId) =>
      (_db.select(_db.categories)
            ..where((c) => c.profileId.equals(profileId) & c.kind.equalsValue(ContentKind.live))
            ..orderBy([(c) => OrderingTerm.asc(c.sortIndex)]))
          .watch();

  Stream<int> watchChannelCount(String profileId) {
    final c = _db.channels.id.count();
    return (_db.selectOnly(_db.channels)
          ..addColumns([c])
          ..where(_db.channels.profileId.equals(profileId)))
        .map((r) => r.read(c) ?? 0)
        .watchSingle();
  }

  /// Sender für einen Filter. Favoriten in eigener Reihenfolge, „Zuletzt“
  /// nach Zeitpunkt, sonst in der Reihenfolge der Quelle.
  Stream<List<ChannelRow>> watchChannels(String profileId, LiveFilter filter) {
    final ch = _db.channels;
    switch (filter) {
      case AllChannels():
        return (_db.select(ch)
              ..where((c) => c.profileId.equals(profileId))
              ..orderBy([(c) => OrderingTerm.asc(c.sortIndex)]))
            .watch();
      case CategoryChannels(:final categoryId):
        return (_db.select(ch)
              ..where((c) => c.profileId.equals(profileId) & c.categoryId.equals(categoryId))
              ..orderBy([(c) => OrderingTerm.asc(c.sortIndex)]))
            .watch();
      case FavoriteChannels():
        final f = _db.favorites;
        final q = _db.select(ch).join([
          innerJoin(f, f.itemKey.equalsExp(ch.itemKey) & f.profileId.equalsExp(ch.profileId)),
        ])
          ..where(ch.profileId.equals(profileId) & f.kind.equalsValue(ContentKind.live))
          ..orderBy([OrderingTerm.asc(f.sortIndex)]);
        return q.watch().map((rows) => _distinct(rows.map((r) => r.readTable(ch))));
      case RecentChannels():
        final h = _db.watchHistory;
        final q = _db.select(ch).join([
          innerJoin(h, h.itemKey.equalsExp(ch.itemKey) & h.profileId.equalsExp(ch.profileId)),
        ])
          ..where(ch.profileId.equals(profileId) & h.kind.equalsValue(ContentKind.live))
          ..orderBy([OrderingTerm.desc(h.watchedAt)])
          ..limit(recentLimit);
        return q.watch().map((rows) => _distinct(rows.map((r) => r.readTable(ch))));
    }
  }

  /// M3U-Listen können denselben Schlüssel mehrfach enthalten; in Favoriten
  /// und Verlauf soll jeder Sender nur einmal erscheinen.
  static List<ChannelRow> _distinct(Iterable<ChannelRow> rows) {
    final seen = <String>{};
    return [for (final r in rows) if (seen.add(r.itemKey)) r];
  }

  Future<ChannelRow?> channelById(int id) =>
      (_db.select(_db.channels)..where((c) => c.id.equals(id))).getSingleOrNull();

  Stream<Set<String>> watchFavoriteKeys(String profileId, ContentKind kind) =>
      (_db.select(_db.favorites)
            ..where((f) => f.profileId.equals(profileId) & f.kind.equalsValue(kind)))
          .watch()
          .map((rows) => {for (final r in rows) r.itemKey});

  /// Schaltet einen Favoriten um. Neue Favoriten kommen ans Ende.
  /// Gibt zurück, ob es danach ein Favorit ist.
  Future<bool> toggleFavorite(String profileId, ContentKind kind, String itemKey) =>
      _db.transaction(() async {
        final f = _db.favorites;
        final deleted = await (_db.delete(f)
              ..where((x) =>
                  x.profileId.equals(profileId) & x.kind.equalsValue(kind) & x.itemKey.equals(itemKey)))
            .go();
        if (deleted > 0) return false;
        final maxSort = f.sortIndex.max();
        final row = await (_db.selectOnly(f)
              ..addColumns([maxSort])
              ..where(f.profileId.equals(profileId) & f.kind.equalsValue(kind)))
            .getSingle();
        await _db.into(f).insert(FavoritesCompanion.insert(
              profileId: profileId,
              kind: kind,
              itemKey: itemKey,
              sortIndex: (row.read(maxSort) ?? -1) + 1,
              addedAt: _now(),
            ));
        return true;
      });

  /// Neue Reihenfolge der Favoriten (Liste der Schlüssel von oben nach unten).
  Future<void> reorderFavorites(String profileId, ContentKind kind, List<String> keys) =>
      _db.batch((b) {
        for (final (i, k) in keys.indexed) {
          b.update(
            _db.favorites,
            FavoritesCompanion(sortIndex: Value(i)),
            where: (x) => x.profileId.equals(profileId) & x.kind.equalsValue(kind) & x.itemKey.equals(k),
          );
        }
      });

  Future<void> recordWatched(String profileId, ContentKind kind, String itemKey) async {
    await _db.into(_db.watchHistory).insertOnConflictUpdate(WatchHistoryCompanion.insert(
          profileId: profileId,
          kind: kind,
          itemKey: itemKey,
          watchedAt: _now(),
        ));
    // Verlauf begrenzen, damit er nicht endlos wächst.
    await _db.customStatement(
      'DELETE FROM watch_history WHERE profile_id = ?1 AND kind = ?2 AND item_key NOT IN '
      '(SELECT item_key FROM watch_history WHERE profile_id = ?1 AND kind = ?2 '
      'ORDER BY watched_at DESC LIMIT 200)',
      [profileId, kind.name],
    );
  }
}
