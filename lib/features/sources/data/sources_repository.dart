import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/security/secret_store.dart';
import '../domain/source_profile.dart';

/// Verwaltet Quellen: unkritische Daten in der Datenbank, Zugangsdaten im
/// verschlüsselten [SecretStore].
///
/// Regel: Es gibt immer genau ein Standardprofil, sobald mindestens eine
/// Quelle existiert.
class SourcesRepository {
  SourcesRepository(this._db, this._secrets, {Uuid? uuid, DateTime Function()? now})
      : _uuid = uuid ?? const Uuid(),
        _now = now ?? DateTime.now;

  final LumenDatabase _db;
  final SecretStore _secrets;
  final Uuid _uuid;
  final DateTime Function() _now;

  static String secretKey(String profileId) => 'profile.$profileId.secret';

  Stream<List<SourceProfile>> watchAll() {
    final q = _db.select(_db.profiles)
      ..orderBy([
        (p) => OrderingTerm.asc(p.sortOrder),
        (p) => OrderingTerm.asc(p.createdAt),
      ]);
    return q.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Future<List<SourceProfile>> all() => watchAll().first;

  Future<SourceProfile?> byId(String id) async {
    final row = await (_db.select(_db.profiles)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<SourceCredentials> credentials(String profileId) async {
    final raw = await _secrets.read(secretKey(profileId));
    if (raw == null) return const SourceCredentials();
    return SourceCredentials.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Legt eine neue Quelle an. Die erste Quelle wird automatisch Standard.
  Future<SourceProfile> add({
    required String name,
    required SourceType type,
    required SourceCredentials credentials,
    String? serverUrl,
    String? localPath,
    String? localFileName,
  }) async {
    final id = _uuid.v4();
    // Erst Geheimnisse schreiben: schlägt das fehl, bleibt kein halbes
    // Profil ohne Zugangsdaten in der Datenbank zurück.
    await _secrets.write(secretKey(id), jsonEncode(credentials.toJson()));
    try {
      await _db.transaction(() async {
        final count = await _count();
        await _db.into(_db.profiles).insert(ProfilesCompanion.insert(
              id: id,
              name: name.trim(),
              type: type,
              serverUrl: Value(serverUrl),
              localPath: Value(localPath),
              localFileName: Value(localFileName),
              isDefault: Value(count == 0),
              sortOrder: Value(count),
              createdAt: _now(),
            ));
      });
    } catch (_) {
      await _secrets.delete(secretKey(id));
      rethrow;
    }
    return (await byId(id))!;
  }

  Future<void> update(SourceProfile profile, SourceCredentials credentials) async {
    await _secrets.write(secretKey(profile.id), jsonEncode(credentials.toJson()));
    await (_db.update(_db.profiles)..where((p) => p.id.equals(profile.id)))
        .write(ProfilesCompanion(
      name: Value(profile.name.trim()),
      serverUrl: Value(profile.serverUrl),
      localPath: Value(profile.localPath),
      localFileName: Value(profile.localFileName),
    ));
  }

  Future<void> rename(String id, String name) =>
      (_db.update(_db.profiles)..where((p) => p.id.equals(id)))
          .write(ProfilesCompanion(name: Value(name.trim())));

  Future<void> setDefault(String id) => _db.transaction(() async {
        await _db.update(_db.profiles).write(
            const ProfilesCompanion(isDefault: Value(false)));
        await (_db.update(_db.profiles)..where((p) => p.id.equals(id)))
            .write(const ProfilesCompanion(isDefault: Value(true)));
      });

  /// Löscht Quelle, alle geladenen Inhalte, Zugangsdaten und eine
  /// importierte Playlist-Datei.
  /// War sie Standard, wird die nächste Quelle Standard.
  Future<void> delete(String id) async {
    final profile = await byId(id);
    if (profile == null) return;
    await _db.transaction(() async {
      await (_db.delete(_db.profiles)..where((p) => p.id.equals(id))).go();
      // Inhalte verschwinden per Fremdschlüssel; der Suchindex ist eine
      // virtuelle Tabelle ohne Fremdschlüssel und wird extra geleert.
      await _db.customStatement('DELETE FROM search_index WHERE profile_id = ?', [id]);
      if (profile.isDefault) {
        final next = await (_db.select(_db.profiles)
              ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
        if (next != null) {
          await (_db.update(_db.profiles)..where((p) => p.id.equals(next.id)))
              .write(const ProfilesCompanion(isDefault: Value(true)));
        }
      }
    });
    await _secrets.delete(secretKey(id));
    final path = profile.localPath;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
  }

  Future<int> _count() async {
    final c = _db.profiles.id.count();
    final row = await (_db.selectOnly(_db.profiles)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  static SourceProfile _toDomain(ProfileRow r) => SourceProfile(
        id: r.id,
        name: r.name,
        type: r.type,
        serverUrl: r.serverUrl,
        localPath: r.localPath,
        localFileName: r.localFileName,
        isDefault: r.isDefault,
        sortOrder: r.sortOrder,
        createdAt: r.createdAt,
        lastSyncAt: r.lastSyncAt,
      );
}
