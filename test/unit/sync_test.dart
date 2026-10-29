import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/db/database.dart';
import 'package:lumen/core/network/http.dart';
import 'package:lumen/core/network/source_error.dart';
import 'package:lumen/core/security/secret_store.dart';
import 'package:lumen/features/sources/data/m3u/m3u_source.dart';
import 'package:lumen/features/sources/data/sources_repository.dart';
import 'package:lumen/features/sources/domain/source_profile.dart';
import 'package:lumen/features/sync/content_store.dart';
import 'package:lumen/features/sync/source_sync.dart';

import '../helpers/test_app.dart';
import '../mock_server/mock_server.dart';

void main() {
  late MockServer server;
  late LumenDatabase db;
  late SourcesRepository repo;
  late ContentStore store;
  late SourceSync sync;

  setUp(() async {
    server = await MockServer.start();
    db = memoryDb();
    repo = SourcesRepository(db, InMemorySecretStore());
    store = ContentStore(db);
    sync = SourceSync(
      dio: createSourceDio(retryBaseDelay: const Duration(milliseconds: 5)),
      store: store,
    );
  });
  tearDown(() async {
    await server.close();
    await db.close();
  });

  Future<(SourceProfile, SourceCredentials)> addXtream() async {
    const c = SourceCredentials(username: 'demo', password: 'geheim');
    final p = await repo.add(
        name: 'Test', type: SourceType.xtream, serverUrl: server.base, credentials: c);
    return (p, c);
  }

  test('Xtream: lädt alles, speichert Kontoinfo und füllt den Suchindex', () async {
    final (p, c) = await addXtream();
    final stages = <SyncStage>[];
    await for (final s in sync.run(p, c)) {
      stages.add(s.stage);
    }
    expect(stages.first, SyncStage.connecting);
    expect(stages.last, SyncStage.done);
    expect(stages, containsAll([SyncStage.live, SyncStage.vod, SyncStage.series, SyncStage.saving]));

    final counts = await store.watchCounts(p.id).first;
    expect(counts.live, 25);
    expect(counts.vod, 12);
    expect(counts.series, 5);

    final cats = await db.select(db.categories).get();
    // Doppelte Kategorie-ID wird nur einmal gespeichert.
    expect(cats.where((c) => c.kind == ContentKind.live).map((c) => c.name), ['Nachrichten', 'Sport']);

    final account = await store.watchAccount(p.id).first;
    expect(account!.maxConnections, 2);
    expect(account.allowedFormats, 'm3u8,ts');

    expect((await repo.byId(p.id))!.lastSyncAt, isNotNull);

    final hits = await store.search(p.id, 'testk 1');
    expect(hits.first.name, 'Testkanal 1');
    expect(hits.first.kind, ContentKind.live);
    expect((await store.search(p.id, 'TESTFILM')).length, 12);
    expect(await store.search(p.id, '  "*() '), isEmpty);
  });

  test('erneutes Aktualisieren ersetzt statt zu verdoppeln', () async {
    final (p, c) = await addXtream();
    await sync.run(p, c).drain<void>();
    server.liveCount = 3;
    await sync.run(p, c).drain<void>();
    final counts = await store.watchCounts(p.id).first;
    expect(counts.live, 3);
    expect((await store.search(p.id, 'Testkanal')).length, 3);
  });

  test('Fehler beim Laden lässt die alten Daten unangetastet', () async {
    final (p, c) = await addXtream();
    await sync.run(p, c).drain<void>();
    server.htmlInsteadOfJson = true;
    await expectLater(
      sync.run(p, c).drain<void>(),
      throwsA(isA<SourceException>()
          .having((e) => e.kind, 'kind', SourceErrorKind.invalidResponse)),
    );
    expect((await store.watchCounts(p.id).first).live, 25);
  });

  test('falsches Passwort → klarer Fehler', () async {
    final p = await repo.add(
      name: 'X',
      type: SourceType.xtream,
      serverUrl: server.base,
      credentials: const SourceCredentials(username: 'demo', password: 'falsch'),
    );
    await expectLater(
      sync.run(p, const SourceCredentials(username: 'demo', password: 'falsch')).drain<void>(),
      throwsA(isA<SourceException>()
          .having((e) => e.kind, 'kind', SourceErrorKind.invalidCredentials)),
    );
  });

  test('M3U-Link: Sender, Filme, Serien und Gruppen', () async {
    final c = SourceCredentials(playlistUrl: '${server.base}/playlist.m3u');
    final p = await repo.add(name: 'M3U', type: SourceType.m3uUrl, credentials: c);
    await sync.run(p, c).drain<void>();
    final counts = await store.watchCounts(p.id).first;
    expect(counts.live, 10);
    expect(counts.vod, 2);
    expect(counts.series, 1);
    final cats = await db.select(db.categories).get();
    expect(cats.map((c) => c.name).toSet(), {'Nachrichten', 'Sport', 'Filme', 'Serien'});
    final ch = await db.select(db.channels).get();
    expect(ch.first.url, 'http://127.0.0.1/live/1.ts');
    expect(ch.first.epgChannelId, 'test1.de');
  });

  test('M3U-Link: keine Playlist / nicht gefunden', () async {
    final m3u = M3uSource(createSourceDio(retries: 0));
    await expectLater(m3u.test('${server.base}/not-a-playlist'),
        throwsA(isA<SourceException>().having((e) => e.kind, 'k', SourceErrorKind.invalidPlaylist)));
    await expectLater(m3u.test('${server.base}/missing.m3u'),
        throwsA(isA<SourceException>().having((e) => e.kind, 'k', SourceErrorKind.notFound)));
    await m3u.test('${server.base}/playlist.m3u'); // gültig: kein Fehler
  });

  test('M3U-Datei, 50.000 Sender', () async {
    final dir = await Directory.systemTemp.createTemp('lumen');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/big.m3u')..writeAsStringSync(sampleM3u(50000));
    final p = await repo.add(
      name: 'Datei',
      type: SourceType.m3uFile,
      localPath: file.path,
      credentials: const SourceCredentials(),
    );
    final sw = Stopwatch()..start();
    await sync.run(p, const SourceCredentials()).drain<void>();
    sw.stop();
    // ignore: avoid_print
    print('Sync 50k M3U (Parsen + Speichern + Index): ${sw.elapsedMilliseconds} ms');
    expect((await store.watchCounts(p.id).first).live, 50000);
    expect((await store.search(p.id, 'Testkanal 49999')).first.name, 'Testkanal 49999');
  });

  test('Profil löschen entfernt alle Inhalte (Fremdschlüssel)', () async {
    final (p, c) = await addXtream();
    await sync.run(p, c).drain<void>();
    await repo.delete(p.id);
    expect(await db.select(db.channels).get(), isEmpty);
    expect(await db.select(db.accountInfos).get(), isEmpty);
    expect(await store.search(p.id, 'Testkanal'), isEmpty);
  });

  test('FTS-Abfrage ist gegen Sonderzeichen abgesichert', () {
    expect(ContentStore.ftsQuery('Café  "Bar" OR *'), '"café"* "bar"* "or"*');
    expect(ContentStore.ftsQuery('   '), isNull);
  });
}
