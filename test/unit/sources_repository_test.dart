import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/db/database.dart';
import 'package:lumen/core/security/secret_store.dart';
import 'package:lumen/features/sources/data/sources_repository.dart';
import 'package:lumen/features/sources/domain/source_profile.dart';

import '../helpers/test_app.dart';

void main() {
  late LumenDatabase db;
  late InMemorySecretStore secrets;
  late SourcesRepository repo;

  setUp(() {
    db = memoryDb();
    secrets = InMemorySecretStore();
    repo = SourcesRepository(db, secrets);
  });
  tearDown(() => db.close());

  Future<SourceProfile> addXtream(String name) => repo.add(
        name: name,
        type: SourceType.xtream,
        serverUrl: 'http://server.example:8080',
        credentials: const SourceCredentials(username: 'nutzer', password: 'geheim'),
      );

  test('erste Quelle wird Standard, weitere nicht', () async {
    final a = await addXtream('A');
    final b = await addXtream('B');
    expect(a.isDefault, isTrue);
    expect(b.isDefault, isFalse);
    expect((await repo.all()).map((p) => p.name), ['A', 'B']);
  });

  test('Passwort liegt nur im SecretStore, nicht in der Datenbank', () async {
    final a = await addXtream('A');

    final stored = jsonDecode(secrets.values[SourcesRepository.secretKey(a.id)]!);
    expect(stored['p'], 'geheim');

    final dump = (await db.select(db.profiles).get()).map((r) => r.toJson()).toString();
    expect(dump, isNot(contains('geheim')));
    expect(dump, isNot(contains('nutzer')));

    expect(await repo.credentials(a.id),
        const SourceCredentials(username: 'nutzer', password: 'geheim'));
  });

  test('toString verrät keine Zugangsdaten', () {
    const c = SourceCredentials(username: 'nutzer', password: 'geheim');
    expect(c.toString(), isNot(contains('geheim')));
  });

  test('setDefault lässt genau eine Standardquelle übrig', () async {
    await addXtream('A');
    final b = await addXtream('B');
    await repo.setDefault(b.id);
    final all = await repo.all();
    expect(all.where((p) => p.isDefault).map((p) => p.name), ['B']);
  });

  test('löschen der Standardquelle macht die nächste zum Standard', () async {
    final a = await addXtream('A');
    await addXtream('B');
    await repo.delete(a.id);
    final all = await repo.all();
    expect(all.single.name, 'B');
    expect(all.single.isDefault, isTrue);
    expect(secrets.values.containsKey(SourcesRepository.secretKey(a.id)), isFalse);
  });

  test('update ändert Name und Zugangsdaten', () async {
    final a = await addXtream('A');
    await repo.update(a.copyWith(name: '  Neu  '),
        const SourceCredentials(username: 'x', password: 'y'));
    expect((await repo.byId(a.id))!.name, 'Neu');
    expect((await repo.credentials(a.id)).password, 'y');
  });

  test('rename kürzt Leerzeichen', () async {
    final a = await addXtream('A');
    await repo.rename(a.id, ' Küche ');
    expect((await repo.byId(a.id))!.name, 'Küche');
  });

  test('löschen entfernt eine importierte Playlist-Datei', () async {
    final dir = await Directory.systemTemp.createTemp('lumen');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/x.m3u')..writeAsStringSync('#EXTM3U\n');
    final p = await repo.add(
      name: 'Datei',
      type: SourceType.m3uFile,
      localPath: file.path,
      localFileName: 'x.m3u',
      credentials: const SourceCredentials(),
    );
    await repo.delete(p.id);
    expect(file.existsSync(), isFalse);
  });

  test('schlägt der Datenbank-Insert fehl, bleiben keine Geheimnisse übrig', () async {
    await expectLater(
      repo.add(
        name: '', // verletzt die Längenprüfung der Spalte
        type: SourceType.xtream,
        credentials: const SourceCredentials(password: 'geheim'),
      ),
      throwsA(anything),
    );
    expect(secrets.values, isEmpty);
    expect(await repo.all(), isEmpty);
  });
}
