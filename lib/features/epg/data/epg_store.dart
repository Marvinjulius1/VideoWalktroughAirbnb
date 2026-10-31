import 'package:drift/drift.dart';

import '../../../core/db/database.dart';

/// Laufende und nächste Sendung eines Kanals.
class NowNext {
  const NowNext({this.now, this.next});

  final EpgRow? now;
  final EpgRow? next;

  /// Fortschritt der laufenden Sendung (0…1).
  double progressAt(DateTime t) {
    final n = now;
    if (n == null) return 0;
    final total = n.endUtc.difference(n.startUtc).inSeconds;
    if (total <= 0) return 0;
    return (t.difference(n.startUtc).inSeconds / total).clamp(0, 1).toDouble();
  }
}

/// Schreiben und Lesen der Programmdaten.
class EpgStore {
  EpgStore(this._db);

  final LumenDatabase _db;

  static const batchSize = 2000;

  /// Ersetzt alle Programmdaten eines Profils atomar.
  Future<void> replace(String profileId, List<EpgProgramsCompanion> rows) =>
      _db.transaction(() async {
        await (_db.delete(_db.epgPrograms)..where((e) => e.profileId.equals(profileId))).go();
        for (var i = 0; i < rows.length; i += batchSize) {
          final end = i + batchSize > rows.length ? rows.length : i + batchSize;
          await _db.batch((b) => b.insertAll(_db.epgPrograms, rows.sublist(i, end)));
        }
      });

  /// Ordnet Sendern ohne `tvg-id` eine EPG-Kennung über den Namen zu
  /// (z. B. „Testkanal 1“ ↔ display-name „Testkanal 1“).
  Future<int> matchChannelsByName(String profileId, Map<String, String> idToName) async {
    if (idToName.isEmpty) return 0;
    final byName = <String, String>{
      for (final e in idToName.entries) _norm(e.value): e.key,
    };
    final unmatched = await (_db.select(_db.channels)
          ..where((c) => c.profileId.equals(profileId) & c.epgChannelId.isNull()))
        .get();
    var n = 0;
    await _db.batch((b) {
      for (final c in unmatched) {
        final id = byName[_norm(c.name)];
        if (id == null) continue;
        n++;
        b.update(_db.channels, ChannelsCompanion(epgChannelId: Value(id)),
            where: (x) => x.id.equals(c.id));
      }
    });
    return n;
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

  Future<Set<String>> epgChannelIds(String profileId) async {
    final rows = await (_db.selectOnly(_db.channels, distinct: true)
          ..addColumns([_db.channels.epgChannelId])
          ..where(_db.channels.profileId.equals(profileId) & _db.channels.epgChannelId.isNotNull()))
        .get();
    return {for (final r in rows) r.read(_db.channels.epgChannelId)!};
  }

  Future<bool> hasChannelsWithoutEpgId(String profileId) async {
    final row = await (_db.select(_db.channels)
          ..where((c) => c.profileId.equals(profileId) & c.epgChannelId.isNull())
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Jetzt/Danach für viele Kanäle auf einmal (eine Abfrage).
  Future<Map<String, NowNext>> nowNext(String profileId, Iterable<String> channelIds, DateTime now) async {
    final ids = channelIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final e = _db.epgPrograms;
    final rows = await (_db.select(e)
          ..where((x) =>
              x.profileId.equals(profileId) &
              x.channelId.isIn(ids) &
              x.endUtc.isBiggerThanValue(now) &
              x.startUtc.isSmallerThanValue(now.add(const Duration(hours: 18))))
          ..orderBy([(x) => OrderingTerm.asc(x.channelId), (x) => OrderingTerm.asc(x.startUtc)]))
        .get();
    final out = <String, NowNext>{};
    for (final r in rows) {
      final cur = out[r.channelId];
      if (cur == null) {
        out[r.channelId] = r.startUtc.isAfter(now) ? NowNext(next: r) : NowNext(now: r);
      } else if (cur.next == null && cur.now != null) {
        out[r.channelId] = NowNext(now: cur.now, next: r);
      }
    }
    return out;
  }

  /// Alle Sendungen der Kanäle in einem Zeitfenster (für das Raster).
  Future<Map<String, List<EpgRow>>> window(
      String profileId, Iterable<String> channelIds, DateTime from, DateTime to) async {
    final ids = channelIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final e = _db.epgPrograms;
    final rows = await (_db.select(e)
          ..where((x) =>
              x.profileId.equals(profileId) &
              x.channelId.isIn(ids) &
              x.endUtc.isBiggerThanValue(from) &
              x.startUtc.isSmallerThanValue(to))
          ..orderBy([(x) => OrderingTerm.asc(x.startUtc)]))
        .get();
    final out = <String, List<EpgRow>>{};
    for (final r in rows) {
      (out[r.channelId] ??= []).add(r);
    }
    return out;
  }

  Stream<int> watchCount(String profileId) {
    final c = _db.epgPrograms.id.count();
    return (_db.selectOnly(_db.epgPrograms)
          ..addColumns([c])
          ..where(_db.epgPrograms.profileId.equals(profileId)))
        .map((r) => r.read(c) ?? 0)
        .watchSingle();
  }
}
